import json
import hashlib
import os
import base64
from datetime import datetime

from fastapi import FastAPI, Depends, HTTPException, Query, File, UploadFile, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from database import SessionLocal, engine
from models import (
    User,
    Role,
    Incident,
    IncidentUpdate,
    IncidentStatus,
    ThreatType,
    RiskLevel,
    EvidenceFile,
)

from ai.inference import predict as ai_predict

app = FastAPI(title="NDPP Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

STATUS_CHANGE_ALLOWED_ROLES = {"ANALYST", "ADMIN"}
ANALYZE_ALLOWED_ROLES = {"ANALYST", "ADMIN"}


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_actor_context(db: Session, actor_user_id: int) -> dict:
    actor = db.query(User).filter(User.user_id == actor_user_id).first()
    if not actor:
        raise HTTPException(status_code=404, detail="actor_user_id not found")

    role = db.query(Role).filter(Role.role_id == actor.role_id).first()
    if not role:
        raise HTTPException(status_code=400, detail="actor role not found")

    return {"actor_user_id": actor.user_id, "role_key": role.role_key}


def require_roles(db: Session, actor_user_id: int, allowed_role_keys: set[str]) -> dict:
    ctx = get_actor_context(db, actor_user_id)
    if ctx["role_key"] not in allowed_role_keys:
        raise HTTPException(
            status_code=403,
            detail=f"Forbidden: role '{ctx['role_key']}' is not allowed to perform this action",
        )
    return ctx


def require_incident_visibility(incident: Incident, actor_ctx: dict):
    if actor_ctx["role_key"] == "CITIZEN":
        if incident.reporter_user_id != actor_ctx["actor_user_id"]:
            raise HTTPException(status_code=403, detail="Forbidden: you can only access your own incidents")


# ---------- Schemas ----------
class UserCreate(BaseModel):
    full_name: str
    email: str | None = None
    phone: str | None = None
    password_hash: str
    role_id: int


class IncidentCreate(BaseModel):
    reporter_user_id: int
    title: str
    description: str
    suspicious_url: str | None = None
    suspicious_message: str | None = None
    report_type_id: int
    incident_date: datetime | None = None
    platform: str | None = None
    device_type: str | None = None
    note: str | None = None


class StatusChangeRequest(BaseModel):
    actor_user_id: int
    new_status_id: int
    note: str | None = None


class AnalyzeRequest(BaseModel):
    actor_user_id: int
    note: str | None = None


class DeepfakeAnalyzeResponse(BaseModel):
    file_name: str
    result: str
    confidence: float
    raw_output: dict | None = None


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/db-test")
def db_test():
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
        return {"database": "connected"}


# ---------- Users ----------
@app.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    try:
        new_user = User(**user.model_dump())
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return {"user_id": new_user.user_id}
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e.orig))
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


# ---------- Incidents ----------
def get_actor_user_id(authorization: str = Header(...)) -> int:
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization token missing")

    # هنا لاحقًا تضع فك JWT الحقيقي
    user_id = 123
    return user_id


@app.post("/incidents/{incident_id}/evidence")
def upload_evidence(
    incident_id: int,
    file: UploadFile = File(...),
    actor_user_id: int = Depends(get_actor_user_id),
    db: Session = Depends(get_db),
):
    require_roles(db, actor_user_id, {"ANALYST", "ADMIN"})

    original_filename = file.filename
    content_type = file.content_type
    file_size = len(file.file.read())
    file.file.seek(0)

    storage_path = f"uploads/{incident_id}/{original_filename}"

    os.makedirs(os.path.dirname(storage_path), exist_ok=True)

    with open(storage_path, "wb") as f:
        f.write(file.file.read())

    sha256 = hashlib.sha256()
    with open(storage_path, "rb") as f:
        while chunk := f.read(4096):
            sha256.update(chunk)
    file_sha256 = sha256.hexdigest()

    new_evidence = EvidenceFile(
        incident_id=incident_id,
        storage_provider="local",
        storage_path=storage_path,
        original_filename=original_filename,
        content_type=content_type,
        file_size_bytes=file_size,
        sha256=file_sha256,
        uploaded_by_user_id=actor_user_id,
        created_at=datetime.utcnow(),
    )
    db.add(new_evidence)
    db.commit()
    db.refresh(new_evidence)

    return {"message": "File uploaded successfully", "evidence_id": new_evidence.evidence_id}


@app.post("/incidents")
def create_incident(payload: IncidentCreate, db: Session = Depends(get_db)):
    try:
        incident = Incident(
            reporter_user_id=payload.reporter_user_id,
            title=payload.title,
            description=payload.description,
            suspicious_url=payload.suspicious_url,
            suspicious_message=payload.suspicious_message,
            report_type_id=payload.report_type_id,
            incident_date=payload.incident_date,
            platform=payload.platform,
            device_type=payload.device_type,
            note=payload.note,
            status_id=1,
            status_key="SUBMITTED",
        )
        db.add(incident)
        db.commit()
        db.refresh(incident)
        return {"incident_id": incident.incident_id}
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e.orig))
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/incidents")
def list_incidents(
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    actor_ctx = get_actor_context(db, actor_user_id)

    q = db.query(Incident).order_by(Incident.incident_id.desc())

    if actor_ctx["role_key"] == "CITIZEN":
        q = q.filter(Incident.reporter_user_id == actor_ctx["actor_user_id"])

    rows = q.limit(50).all()

    return [
        {
            "incident_id": r.incident_id,
            "reporter_user_id": r.reporter_user_id,
            "title": r.title,
            "status_id": r.status_id,
            "status_key": r.status_key,
            "created_at": r.created_at,
        }
        for r in rows
    ]


@app.get("/incidents/{incident_id}")
def get_incident(
    incident_id: int,
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    actor_ctx = get_actor_context(db, actor_user_id)

    r = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Incident not found")

    require_incident_visibility(r, actor_ctx)

    return {
        "incident_id": r.incident_id,
        "reporter_user_id": r.reporter_user_id,
        "title": r.title,
        "description": r.description,
        "suspicious_url": r.suspicious_url,
        "suspicious_message": r.suspicious_message,
        "threat_type_id": r.threat_type_id,
        "risk_level_id": r.risk_level_id,
        "status_id": r.status_id,
        "status_key": r.status_key,
        "created_at": r.created_at,
        "updated_at": r.updated_at,
    }


@app.put("/incidents/{incident_id}/status")
def change_incident_status(incident_id: int, payload: StatusChangeRequest, db: Session = Depends(get_db)):
    actor_ctx = require_roles(db, payload.actor_user_id, STATUS_CHANGE_ALLOWED_ROLES)

    incident = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    new_status = db.query(IncidentStatus).filter(IncidentStatus.status_id == payload.new_status_id).first()
    if not new_status:
        raise HTTPException(status_code=400, detail="Invalid new_status_id")

    old_status_key = incident.status_key
    old_status_id = incident.status_id

    incident.status_id = new_status.status_id
    incident.status_key = new_status.status_key

    db.add(
        IncidentUpdate(
            incident_id=incident.incident_id,
            actor_user_id=payload.actor_user_id,
            update_type="STATUS_CHANGE",
            note=payload.note,
            old_status_key=str(old_status_key),
            new_status_key=str(new_status.status_key),
        )
    )

    db.commit()
    db.refresh(incident)

    return {
        "incident_id": incident.incident_id,
        "actor_user_id": actor_ctx["actor_user_id"],
        "actor_role_key": actor_ctx["role_key"],
        "old_status_id": old_status_id,
        "old_status_key": old_status_key,
        "new_status_id": incident.status_id,
        "new_status_key": incident.status_key,
    }


@app.get("/incidents/{incident_id}/updates")
def get_incident_updates(
    incident_id: int,
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    actor_ctx = get_actor_context(db, actor_user_id)

    inc = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")

    require_incident_visibility(inc, actor_ctx)

    rows = (
        db.query(IncidentUpdate)
        .filter(IncidentUpdate.incident_id == incident_id)
        .order_by(IncidentUpdate.created_at.asc())
        .all()
    )
    return [
        {
            "update_id": r.update_id,
            "incident_id": r.incident_id,
            "actor_user_id": r.actor_user_id,
            "update_type": r.update_type,
            "note": r.note,
            "old_status_key": r.old_status_key,
            "new_status_key": r.new_status_key,
            "created_at": r.created_at,
        }
        for r in rows
    ]


# ---------- Deepfake Analyze ----------
@app.post("/deepfake/analyze", response_model=DeepfakeAnalyzeResponse)
async def analyze_deepfake(file: UploadFile = File(...)):
    try:
        file_bytes = await file.read()
        if not file_bytes:
            raise HTTPException(status_code=400, detail="Empty file")

        encoded = base64.b64encode(file_bytes).decode("utf-8")

        # نمرر الصورة كنص ممثل Base64 للمودل الحالي
        pred = ai_predict(encoded)

        result = str(
            pred.get("label")
            or pred.get("result")
            or pred.get("prediction")
            or "Unknown"
        )

        confidence = float(
            pred.get("confidence")
            or pred.get("score")
            or pred.get("probability")
            or 0.0
        )

        return DeepfakeAnalyzeResponse(
            file_name=file.filename or "uploaded_file",
            result=result,
            confidence=confidence,
            raw_output=pred if isinstance(pred, dict) else {"value": str(pred)},
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Deepfake analyze failed: {str(e)}")


# ---------- AI Helpers ----------
def map_label_to_threat_id(db: Session, label: str) -> int:
    label = label.strip().upper()
    t = db.query(ThreatType).filter(ThreatType.threat_key == label).first()
    if not t:
        t = db.query(ThreatType).filter(ThreatType.threat_key == "OTHER").first()
        if not t:
            raise HTTPException(status_code=500, detail="ThreatType OTHER not found")
    return t.threat_type_id


def get_threat_profile(db: Session, threat_key: str) -> dict:
    row = db.execute(
        text("""
            SELECT threat_key, severity, difficulty
            FROM app.threat_profiles
            WHERE threat_key = :k
        """),
        {"k": threat_key}
    ).mappings().first()

    if not row:
        row = db.execute(
            text("""
                SELECT threat_key, severity, difficulty
                FROM app.threat_profiles
                WHERE threat_key = 'OTHER'
            """)
        ).mappings().first()

    if not row:
        return {"severity": 2, "difficulty": 2}

    return {"severity": int(row["severity"]), "difficulty": int(row["difficulty"])}


def compute_risk_score_10(confidence: float, severity: int, difficulty: int) -> float:
    sev = (severity - 1) / 4.0
    dif = (difficulty - 1) / 4.0
    conf = max(0.0, min(1.0, confidence))
    score_0_1 = (0.45 * sev) + (0.25 * dif) + (0.30 * conf)
    return round(score_0_1 * 10.0, 2)


def map_risk_score_to_level(db: Session, risk_score_10: float) -> int:
    if risk_score_10 >= 8.0:
        key = "CRITICAL"
    elif risk_score_10 >= 6.0:
        key = "HIGH"
    elif risk_score_10 >= 3.5:
        key = "MEDIUM"
    else:
        key = "LOW"

    r = db.query(RiskLevel).filter(RiskLevel.risk_key == key).first()
    if not r:
        raise HTTPException(status_code=500, detail=f"RiskLevel {key} not found")
    return r.risk_level_id


# ---------- AI Analyze ----------
@app.post("/incidents/{incident_id}/analyze")
def analyze_incident(incident_id: int, payload: AnalyzeRequest, db: Session = Depends(get_db)):
    actor_ctx = require_roles(db, payload.actor_user_id, ANALYZE_ALLOWED_ROLES)

    incident = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    parts = [incident.title or "", incident.description or ""]
    if incident.suspicious_message:
        parts.append(incident.suspicious_message)
    if incident.suspicious_url:
        parts.append(incident.suspicious_url)
    full_text = " | ".join([p for p in parts if p])

    try:
        pred = ai_predict(full_text)
        predicted_label = str(pred["label"]).upper()
        confidence = float(pred["confidence"])

        analysis_type = "TEXT_CLASSIFICATION"
        model_name = "NDPP-TextClassifier"
        model_version = "v1-logreg"
        explanation = "Text classifier prediction using trained artifacts."
        raw_output_json = json.dumps(pred, ensure_ascii=False)

        threat_type_id = map_label_to_threat_id(db, predicted_label)
        profile = get_threat_profile(db, predicted_label)

        risk_score_10 = compute_risk_score_10(confidence, profile["severity"], profile["difficulty"])
        risk_level_id = map_risk_score_to_level(db, risk_score_10)

        db.execute(
            text("""
                INSERT INTO app.ai_analysis_results
                (incident_id, analysis_type, model_name, model_version,
                 predicted_label, confidence_score, risk_score,
                 raw_output, explanation)
                VALUES
                (:incident_id, :analysis_type, :model_name, :model_version,
                 :predicted_label, :confidence_score, :risk_score,
                 (:raw_output)::jsonb, :explanation)
            """),
            {
                "incident_id": incident_id,
                "analysis_type": analysis_type,
                "model_name": model_name,
                "model_version": model_version,
                "predicted_label": predicted_label,
                "confidence_score": confidence,
                "risk_score": risk_score_10,
                "raw_output": raw_output_json,
                "explanation": explanation,
            }
        )

        incident.threat_type_id = threat_type_id
        incident.risk_level_id = risk_level_id

        db.add(
            IncidentUpdate(
                incident_id=incident_id,
                actor_user_id=payload.actor_user_id,
                update_type="AI_ANALYSIS",
                note=payload.note or "AI analysis executed",
                old_status_key=None,
                new_status_key=None,
            )
        )

        db.commit()
        db.refresh(incident)

        return {
            "incident_id": incident.incident_id,
            "actor_user_id": actor_ctx["actor_user_id"],
            "actor_role_key": actor_ctx["role_key"],
            "analysis_type": analysis_type,
            "predicted_label": predicted_label,
            "confidence_score": confidence,
            "risk_score_10": risk_score_10,
            "mapped_threat_type_id": threat_type_id,
            "mapped_risk_level_id": risk_level_id,
            "model_name": model_name,
            "model_version": model_version,
            "profile_used": profile,
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"AI analyze failed: {str(e)}")


# ---------- Read AI Analysis ----------
@app.get("/incidents/{incident_id}/analysis")
def get_latest_analysis(
    incident_id: int,
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    actor_ctx = get_actor_context(db, actor_user_id)

    inc = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")

    require_incident_visibility(inc, actor_ctx)

    row = db.execute(
        text("""
            SELECT analysis_id, incident_id, analysis_type, model_name, model_version,
                   predicted_label, confidence_score, risk_score,
                   raw_output, explanation, created_at
            FROM app.ai_analysis_results
            WHERE incident_id = :incident_id
            ORDER BY analysis_id DESC
            LIMIT 1
        """),
        {"incident_id": incident_id}
    ).mappings().first()

    if not row:
        raise HTTPException(status_code=404, detail="No AI analysis found for this incident")

    raw_out = row["raw_output"]
    try:
        if isinstance(raw_out, str):
            raw_out = json.loads(raw_out)
    except Exception:
        pass

    return {
        "analysis_id": row["analysis_id"],
        "incident_id": row["incident_id"],
        "analysis_type": row["analysis_type"],
        "model_name": row["model_name"],
        "model_version": row["model_version"],
        "predicted_label": row["predicted_label"],
        "confidence_score": float(row["confidence_score"]) if row["confidence_score"] is not None else None,
        "risk_score": float(row["risk_score"]) if row["risk_score"] is not None else None,
        "raw_output": raw_out,
        "explanation": row["explanation"],
        "created_at": str(row["created_at"]),
    }


@app.get("/incidents/{incident_id}/analyses")
def get_all_analyses(
    incident_id: int,
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    actor_ctx = get_actor_context(db, actor_user_id)

    inc = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")

    require_incident_visibility(inc, actor_ctx)

    rows = db.execute(
        text("""
            SELECT analysis_id, incident_id, analysis_type, model_name, model_version,
                   predicted_label, confidence_score, risk_score,
                   raw_output, explanation, created_at
            FROM app.ai_analysis_results
            WHERE incident_id = :incident_id
            ORDER BY analysis_id DESC
            LIMIT 50
        """),
        {"incident_id": incident_id}
    ).mappings().all()

    out = []
    for r in rows:
        raw_out = r["raw_output"]
        try:
            if isinstance(raw_out, str):
                raw_out = json.loads(raw_out)
        except Exception:
            pass

        out.append({
            "analysis_id": r["analysis_id"],
            "incident_id": r["incident_id"],
            "analysis_type": r["analysis_type"],
            "model_name": r["model_name"],
            "model_version": r["model_version"],
            "predicted_label": r["predicted_label"],
            "confidence_score": float(r["confidence_score"]) if r["confidence_score"] is not None else None,
            "risk_score": float(r["risk_score"]) if r["risk_score"] is not None else None,
            "raw_output": raw_out,
            "explanation": r["explanation"],
            "created_at": str(r["created_at"]),
        })

    return out


# ---------- Response Guidance ----------
@app.get("/response-guidance/{threat_id}")
def get_response_guidance(
    threat_id: int,
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    get_actor_context(db, actor_user_id)

    rows = db.execute(
        text("""
            SELECT response_id, threat_id, immediate_action, evidence_preservation, authority_contact
            FROM app.incident_response_guidance
            WHERE threat_id = :threat_id
            ORDER BY response_id ASC
        """),
        {"threat_id": threat_id}
    ).mappings().all()

    if not rows:
        raise HTTPException(status_code=404, detail="No response guidance found for this threat_id")

    return [
        {
            "response_id": r["response_id"],
            "threat_id": r["threat_id"],
            "immediate_action": r["immediate_action"],
            "evidence_preservation": r["evidence_preservation"],
            "authority_contact": r["authority_contact"],
        }
        for r in rows
    ]


# ---------- Legal Guidance ----------
@app.get("/legal-guidance/{threat_id}")
def get_legal_guidance(
    threat_id: int,
    actor_user_id: int = Query(..., description="Caller user_id for RBAC"),
    db: Session = Depends(get_db),
):
    get_actor_context(db, actor_user_id)

    rows = db.execute(
        text("""
            SELECT legal_id, threat_id, legal_steps, responsible_authority, reporting_priority
            FROM app.legal_guidance
            WHERE threat_id = :threat_id
            ORDER BY legal_id ASC
        """),
        {"threat_id": threat_id}
    ).mappings().all()

    if not rows:
        raise HTTPException(status_code=404, detail="No legal guidance found for this threat_id")

    return [
        {
            "legal_id": r["legal_id"],
            "threat_id": r["threat_id"],
            "legal_steps": r["legal_steps"],
            "responsible_authority": r["responsible_authority"],
            "reporting_priority": r["reporting_priority"],
        }
        for r in rows
    ]