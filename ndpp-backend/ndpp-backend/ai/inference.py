import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

BASE_DIR = os.path.dirname(__file__)
TEXT_MODEL_DIR = os.path.join(BASE_DIR, "artifacts", "text_model")

tokenizer = AutoTokenizer.from_pretrained(TEXT_MODEL_DIR)
model = AutoModelForSequenceClassification.from_pretrained(TEXT_MODEL_DIR)
model.eval()


def predict(text: str) -> dict:
    if not text or not text.strip():
        return {
            "label": "OTHER",
            "confidence": 0.0
        }

    inputs = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=192
    )

    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.softmax(outputs.logits, dim=1)[0]

    predicted_class = int(torch.argmax(probs).item())
    confidence = float(torch.max(probs).item())

    # نفترض:
    # 0 = ham / normal
    # 1 = spam / phishing / fraud
    if predicted_class == 1:
        label = "PHISHING"
    else:
        label = "OTHER"

    return {
        "label": label,
        "confidence": confidence
    }