import json
import re
from pathlib import Path

import numpy as np
import pandas as pd
import joblib

from sklearn.feature_extraction.text import TfidfVectorizer, ENGLISH_STOP_WORDS
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.linear_model import LogisticRegression
from scipy.sparse import hstack, csr_matrix


# ========= Paths =========
PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATASET_PATH = PROJECT_ROOT / "data" / "dataset2.csv.xlsx"
ARTIFACTS_DIR = PROJECT_ROOT / "ai" / "artifacts"
ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)


# ========= Features =========
STOP_WORDS = set(ENGLISH_STOP_WORDS)

SUSPICIOUS_WORDS = [
    "password","bank","account","verify","urgent","transfer",
    "bitcoin","crypto","wallet","threat","click","link",
    "otp","code","login","confirm","security","update",
    "suspended","restricted","ssn","credit","card"
]
URGENT_WORDS = ["urgent","immediately","now","asap","quick","limited","deadline","expire","final notice"]
FINANCIAL_WORDS = ["bank","transfer","payment","invoice","refund","credit","debit","card","crypto","bitcoin"]
SOCIAL_ENGINEERING_PHRASES = [
    "click here","verify your account","confirm your identity",
    "reset your password","limited time","act now",
    "provide the code","share the code","one time password","otp code"
]


def clean_text(text: str) -> str:
    text = str(text).lower()
    text = re.sub(r"http\S+", "", text)
    text = re.sub(r"[^a-zA-Z ]", " ", text)
    words = text.split()
    words = [w for w in words if w not in STOP_WORDS]
    return " ".join(words)


def count_suspicious(text: str) -> int:
    return sum(w in text for w in SUSPICIOUS_WORDS)


def urgency_score(text: str) -> int:
    return sum(w in text for w in URGENT_WORDS)


def financial_score(text: str) -> int:
    return sum(w in text for w in FINANCIAL_WORDS)


def social_engineering_score(text: str) -> int:
    return sum(p in text for p in SOCIAL_ENGINEERING_PHRASES)


def contains_url(text: str) -> int:
    t = str(text).lower()
    return 1 if ("http" in t or "www" in t) else 0


def digit_letter_ratio(text: str) -> float:
    text = str(text)
    if len(text) == 0:
        return 0.0
    digits = sum(c.isdigit() for c in text)
    letters = sum(c.isalpha() for c in text)
    if letters == 0:
        return 0.0
    return digits / letters


def text_entropy(text: str) -> float:
    words = str(text).split()
    if not words:
        return 0.0
    from collections import Counter
    import math
    counts = Counter(words)
    total = len(words)
    return -sum((c/total) * math.log2(c/total) for c in counts.values())


def excessive_caps_ratio(text: str) -> float:
    text = str(text)
    if len(text) == 0:
        return 0.0
    return sum(c.isupper() for c in text) / len(text)


def special_char_ratio(text: str) -> float:
    text = str(text)
    if len(text) == 0:
        return 0.0
    return sum((not c.isalnum()) and (not c.isspace()) for c in text) / len(text)


def build_numeric_features(cleaned_text: str, raw_text: str) -> np.ndarray:
    return np.array([[
        len(cleaned_text.split()),
        count_suspicious(cleaned_text),
        urgency_score(cleaned_text),
        financial_score(cleaned_text),
        social_engineering_score(cleaned_text),
        contains_url(raw_text),
        digit_letter_ratio(raw_text),
        text_entropy(cleaned_text),
        excessive_caps_ratio(raw_text),
        special_char_ratio(raw_text),
    ]], dtype=float)


def main():
    if not DATASET_PATH.exists():
        raise FileNotFoundError(f"Dataset not found: {DATASET_PATH}")

    df = pd.read_excel(DATASET_PATH)
    df = df.drop_duplicates().dropna()
    df.columns = df.columns.str.strip().str.lower()

    # لازم يكون عندك هالعمودين على الأقل
    if "report_text" not in df.columns or "attack_type" not in df.columns:
        raise ValueError("Dataset must include columns: report_text, attack_type")

    df["clean_text"] = df["report_text"].apply(clean_text)

    # ===== TF-IDF =====
    vectorizer = TfidfVectorizer(max_features=7000, ngram_range=(1, 2))
    X_tfidf = vectorizer.fit_transform(df["clean_text"])

    # ===== Numeric features =====
    numeric_rows = []
    for raw in df["report_text"].tolist():
        c = clean_text(raw)
        numeric_rows.append(build_numeric_features(c, raw)[0])
    numeric_features = np.vstack(numeric_rows)

    scaler = StandardScaler()
    numeric_scaled = scaler.fit_transform(numeric_features)

    X_full = hstack([X_tfidf, csr_matrix(numeric_scaled)])

    # ===== Labels =====
    le = LabelEncoder()
    y = le.fit_transform(df["attack_type"].astype(str).str.strip().str.upper())

    # ===== Model =====
    model = LogisticRegression(max_iter=1500)
    model.fit(X_full, y)

    # ===== Save artifacts =====
    joblib.dump(model, ARTIFACTS_DIR / "logistic_model.joblib")
    joblib.dump(vectorizer, ARTIFACTS_DIR / "tfidf_vectorizer.joblib")
    joblib.dump(scaler, ARTIFACTS_DIR / "numeric_scaler.joblib")
    joblib.dump(le, ARTIFACTS_DIR / "label_encoder.joblib")

    with open(ARTIFACTS_DIR / "metadata.json", "w", encoding="utf-8") as f:
        json.dump({"classes": le.classes_.tolist(), "dataset_path": str(DATASET_PATH)}, f, ensure_ascii=False, indent=2)

    print("✅ Training done.")
    print("✅ Saved to:", ARTIFACTS_DIR)
    print("✅ Classes:", le.classes_.tolist())


if __name__ == "__main__":
    main()