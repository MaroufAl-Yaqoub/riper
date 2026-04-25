from sqlalchemy import Column, Integer, BigInteger, Text, Boolean, ForeignKey, SmallInteger
from sqlalchemy.sql import func
from sqlalchemy.types import TIMESTAMP
from database import Base
from datetime import datetime

class Role(Base):
    __tablename__ = "roles"
    __table_args__ = {"schema": "app"}

    role_id = Column(SmallInteger, primary_key=True, autoincrement=True)
    role_key = Column(Text, nullable=False, unique=True)
    role_name = Column(Text, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class ThreatType(Base):
    __tablename__ = "threat_types"
    __table_args__ = {"schema": "app"}

    threat_type_id = Column(SmallInteger, primary_key=True, autoincrement=True)
    threat_key = Column(Text, nullable=False, unique=True)
    threat_name = Column(Text, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class RiskLevel(Base):
    __tablename__ = "risk_levels"
    __table_args__ = {"schema": "app"}

    risk_level_id = Column(SmallInteger, primary_key=True, autoincrement=True)
    risk_key = Column(Text, nullable=False, unique=True)
    risk_name = Column(Text, nullable=False)
    severity_rank = Column(SmallInteger, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class IncidentStatus(Base):
    __tablename__ = "incident_statuses"
    __table_args__ = {"schema": "app"}

    status_id = Column(SmallInteger, primary_key=True, autoincrement=True)
    status_key = Column(Text, nullable=False, unique=True)
    status_name = Column(Text, nullable=False)
    is_final = Column(Boolean, nullable=False, default=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "app"}

    user_id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    full_name = Column(Text, nullable=False)
    email = Column(Text, unique=True)
    phone = Column(Text, unique=True)
    password_hash = Column(Text, nullable=False)

    role_id = Column(SmallInteger, ForeignKey("app.roles.role_id"), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class Incident(Base):
    __tablename__ = "incidents"
    __table_args__ = {"schema": "app"}

    incident_id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)

    reporter_user_id = Column(BigInteger, ForeignKey("app.users.user_id"), nullable=False)
    title = Column(Text, nullable=False)
    description = Column(Text, nullable=False)

    suspicious_url = Column(Text)
    suspicious_message = Column(Text)

    threat_type_id = Column(SmallInteger, ForeignKey("app.threat_types.threat_type_id"))
    risk_level_id = Column(SmallInteger, ForeignKey("app.risk_levels.risk_level_id"))

    status_key = Column(Text, nullable=False, default="SUBMITTED")
    status_id = Column(SmallInteger, ForeignKey("app.incident_statuses.status_id"), nullable=False)

    is_deleted = Column(Boolean, default=False, nullable=False)

    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    # New columns added
    report_type_id = Column(SmallInteger, ForeignKey("app.threat_types.threat_type_id"))
    incident_date = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)
    platform = Column(Text)
    device_type = Column(Text)
    note = Column(Text)

class IncidentUpdate(Base):
    __tablename__ = "incident_updates"
    __table_args__ = {"schema": "app"}

    update_id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    incident_id = Column(BigInteger, ForeignKey("app.incidents.incident_id"), nullable=False)
    actor_user_id = Column(BigInteger, ForeignKey("app.users.user_id"), nullable=False)

    update_type = Column(Text, nullable=False, default="STATUS_CHANGE")  # NOTE / STATUS_CHANGE / AI_RESULT / SYSTEM
    note = Column(Text)

    old_status_key = Column(Text)
    new_status_key = Column(Text)

    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class EvidenceFile(Base):
    __tablename__ = "evidence_files"
    __table_args__ = {"schema": "app"}

    evidence_id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    incident_id = Column(BigInteger, ForeignKey("app.incidents.incident_id"), nullable=False)
    storage_provider = Column(Text)
    storage_path = Column(Text)
    original_filename = Column(Text)
    content_type = Column(Text)
    file_size_bytes = Column(BigInteger)
    sha256 = Column(Text)
    uploaded_by_user_id = Column(BigInteger, ForeignKey("app.users.user_id"))
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())