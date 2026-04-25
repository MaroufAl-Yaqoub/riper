def predict_deepfake(image_bytes: bytes):
    return {
        "label": "REAL",
        "confidence": 0.85
    }