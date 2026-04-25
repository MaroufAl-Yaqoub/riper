#!/usr/bin/env python
"""
Dual AI detector: image deepfake classification + SMS/email spam detection.

Default datasets:
- Images: https://huggingface.co/datasets/yashduhan/deepfake-detection-700
- Text: https://huggingface.co/datasets/codesignal/sms-spam-collection
"""


from __future__ import annotations

import argparse
import io
import json
import os
import random
import time
from contextlib import nullcontext
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import numpy as np
import torch
from datasets import load_dataset
from PIL import Image, ImageFile, UnidentifiedImageError
from torch.utils.data import DataLoader, Dataset
from transformers import (
    AutoImageProcessor,
    AutoModelForImageClassification,
    AutoModelForSequenceClassification,
    AutoTokenizer,
)

ImageFile.LOAD_TRUNCATED_IMAGES = True


def log(message: str) -> None:
    timestamp = time.strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}", flush=True)


def seed_everything(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    if torch.backends.cudnn.is_available():
        torch.backends.cudnn.deterministic = False
        torch.backends.cudnn.benchmark = True
    if hasattr(torch, "set_float32_matmul_precision"):
        torch.set_float32_matmul_precision("high")


def default_num_workers() -> int:
    if os.name == "nt":
        return 0
    cpu_count = os.cpu_count() or 0
    return min(2, cpu_count) if cpu_count > 0 else 0


@dataclass
class DatasetSource:
    name: str
    split: str
    label_column: str
    image_column: Optional[str] = None
    text_column: Optional[str] = None
    max_samples: Optional[int] = None
    numeric_label_map: Dict[int, int] = field(default_factory=dict)
    string_label_map: Dict[str, int] = field(
        default_factory=lambda: {
            "real": 0,
            "ham": 0,
            "not spam": 0,
            "authentic": 0,
            "genuine": 0,
            "legit": 0,
            "legitimate": 0,
            "fake": 1,
            "deepfake": 1,
            "spam": 1,
            "fraud": 1,
            "phishing": 1,
        }
    )


@dataclass
class RuntimeConfig:
    image_model_name: str = "google/vit-base-patch16-224"
    text_model_name: str = "distilbert-base-uncased"
    output_dir: str = "artifacts"
    seed: int = 42
    validation_ratio: float = 0.2
    image_epochs: int = 2
    text_epochs: int = 2
    image_batch_size: int = 8
    text_batch_size: int = 16
    image_learning_rate: float = 2e-5
    text_learning_rate: float = 2e-5
    weight_decay: float = 0.01
    max_text_length: int = 192
    use_mixed_precision: bool = True
    balance_datasets: bool = True
    num_workers: int = field(default_factory=default_num_workers)


DEFAULT_IMAGE_SOURCES: List[DatasetSource] = [
    DatasetSource(
        name="yashduhan/deepfake-detection-700",
        split="train",
        image_column="image",
        label_column="label",
        max_samples=1400,
        numeric_label_map={0: 1, 1: 0},
    ),
    DatasetSource(
        name="yashduhan/deepfake-detection-small",
        split="train",
        image_column="image",
        label_column="label",
        max_samples=1400,
        numeric_label_map={0: 1, 1: 0},
    ),
]

DEFAULT_TEXT_SOURCES: List[DatasetSource] = [
    DatasetSource(
        name="codesignal/sms-spam-collection",
        split="train",
        text_column="message",
        label_column="label",
        max_samples=2000,
    ),
    DatasetSource(
        name="DarkNeuronAI/spam-sms-collection-01",
        split="train",
        text_column="message",
        label_column="label",
        max_samples=2000,
    ),
]


def normalize_label_text(value: str) -> str:
    return " ".join(str(value).strip().lower().replace("_", " ").replace("-", " ").split())


def get_label_names(dataset: Any, label_column: str) -> Optional[List[str]]:
    try:
        feature = dataset.features[label_column]
        names = getattr(feature, "names", None)
        if names:
            return list(names)
    except Exception:
        return None
    return None


def infer_binary_label(
    raw_label: Any,
    label_names: Optional[Sequence[str]],
    source: DatasetSource,
) -> int:
    if isinstance(raw_label, (np.integer, int)):
        label_index = int(raw_label)
        if label_names and 0 <= label_index < len(label_names):
            return infer_binary_label(label_names[label_index], None, source)
        if label_index in source.numeric_label_map:
            return int(source.numeric_label_map[label_index])
        if label_index in (0, 1):
            return label_index
        raise ValueError(f"Unsupported numeric label: {raw_label}")

    normalized = normalize_label_text(str(raw_label))
    if normalized in source.string_label_map:
        return int(source.string_label_map[normalized])
    raise ValueError(f"Unsupported string label: {raw_label}")


def open_image_safely(image_value: Any) -> Image.Image:
    if image_value is None:
        raise ValueError("Image sample is None")

    if isinstance(image_value, Image.Image):
        image = image_value.convert("RGB")
        image.load()
        return image.copy()

    if isinstance(image_value, dict):
        image_bytes = image_value.get("bytes")
        image_path = image_value.get("path")
        if image_bytes:
            with Image.open(io.BytesIO(image_bytes)) as img:
                rgb = img.convert("RGB")
                rgb.load()
                return rgb.copy()
        if image_path:
            with Image.open(image_path) as img:
                rgb = img.convert("RGB")
                rgb.load()
                return rgb.copy()
        raise ValueError("Image dict does not contain bytes or path")

    if isinstance(image_value, (str, Path)):
        with Image.open(image_value) as img:
            rgb = img.convert("RGB")
            rgb.load()
            return rgb.copy()

    raise TypeError(f"Unsupported image type: {type(image_value)}")


def balance_binary_records(
    records: List[Dict[str, Any]],
    max_samples: Optional[int],
    seed: int,
) -> List[Dict[str, Any]]:
    by_label = {0: [], 1: []}
    for record in records:
        by_label[int(record["label"])].append(record)

    if not by_label[0] or not by_label[1]:
        raise ValueError(
            "Dataset must contain both classes after preprocessing. "
            f"Class counts: real={len(by_label[0])}, fake/spam={len(by_label[1])}"
        )

    rng = random.Random(seed)
    for group in by_label.values():
        rng.shuffle(group)

    per_class = min(len(by_label[0]), len(by_label[1]))
    if max_samples is not None:
        safe_cap = max(2, min(max_samples, per_class * 2))
        if safe_cap % 2 == 1:
            safe_cap -= 1
        per_class = min(per_class, safe_cap // 2)

    balanced = by_label[0][:per_class] + by_label[1][:per_class]
    rng.shuffle(balanced)
    return balanced


def stratified_split(
    records: List[Dict[str, Any]],
    validation_ratio: float,
    seed: int,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    if not 0.0 < validation_ratio < 1.0:
        raise ValueError("validation_ratio must be between 0 and 1.")

    rng = random.Random(seed)
    by_label = {0: [], 1: []}
    for record in records:
        by_label[int(record["label"])].append(record)

    train_records: List[Dict[str, Any]] = []
    validation_records: List[Dict[str, Any]] = []

    for label, group in by_label.items():
        if len(group) < 2:
            raise ValueError(
                f"Need at least 2 samples for label {label} to create train/validation splits."
            )
        rng.shuffle(group)
        validation_count = int(round(len(group) * validation_ratio))
        validation_count = max(1, validation_count)
        validation_count = min(validation_count, len(group) - 1)
        validation_records.extend(group[:validation_count])
        train_records.extend(group[validation_count:])

    rng.shuffle(train_records)
    rng.shuffle(validation_records)
    return train_records, validation_records


def load_hf_dataset(candidates: Sequence[DatasetSource]) -> Tuple[Any, DatasetSource]:
    last_error: Optional[Exception] = None
    for source in candidates:
        try:
            log(f"Loading dataset: {source.name} [{source.split}]")
            dataset = load_dataset(source.name, split=source.split)
            if len(dataset) == 0:
                raise ValueError(f"Dataset {source.name} returned zero rows.")
            return dataset, source
        except Exception as exc:
            last_error = exc
            log(f"Dataset load failed for {source.name}: {exc}")
    raise RuntimeError(f"Unable to load any dataset candidate. Last error: {last_error}")


def prepare_image_records(
    dataset: Any,
    source: DatasetSource,
    seed: int,
    balance: bool,
) -> Tuple[List[Dict[str, Any]], int]:
    if not source.image_column:
        raise ValueError("Image source must define image_column.")

    label_names = get_label_names(dataset, source.label_column)
    records: List[Dict[str, Any]] = []
    skipped = 0

    for row in dataset:
        try:
            label = infer_binary_label(row[source.label_column], label_names, source)
            image = open_image_safely(row[source.image_column])
            records.append({"image": image, "label": label})
        except (KeyError, ValueError, TypeError, OSError, UnidentifiedImageError) as exc:
            skipped += 1
            if skipped <= 5:
                log(f"Skipping bad image sample: {exc}")

    if not records:
        raise RuntimeError("No valid image samples were found.")

    if balance:
        records = balance_binary_records(records, source.max_samples, seed)
    elif source.max_samples is not None:
        rng = random.Random(seed)
        rng.shuffle(records)
        records = records[: min(source.max_samples, len(records))]

    return records, skipped


def prepare_text_records(
    dataset: Any,
    source: DatasetSource,
    seed: int,
    balance: bool,
) -> Tuple[List[Dict[str, Any]], int]:
    if not source.text_column:
        raise ValueError("Text source must define text_column.")

    label_names = get_label_names(dataset, source.label_column)
    records: List[Dict[str, Any]] = []
    skipped = 0

    for row in dataset:
        try:
            label = infer_binary_label(row[source.label_column], label_names, source)
            text = str(row[source.text_column]).strip()
            if not text:
                raise ValueError("Text sample is empty")
            records.append({"text": text, "label": label})
        except (KeyError, ValueError, TypeError) as exc:
            skipped += 1
            if skipped <= 5:
                log(f"Skipping bad text sample: {exc}")

    if not records:
        raise RuntimeError("No valid text samples were found.")

    if balance:
        records = balance_binary_records(records, source.max_samples, seed)
    elif source.max_samples is not None:
        rng = random.Random(seed)
        rng.shuffle(records)
        records = records[: min(source.max_samples, len(records))]

    return records, skipped


class SafeImageDataset(Dataset):
    def __init__(self, records: Sequence[Dict[str, Any]]) -> None:
        self.records = list(records)

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> Optional[Dict[str, Any]]:
        record = self.records[index]
        try:
            image = record["image"].copy().convert("RGB")
            return {"image": image, "labels": int(record["label"])}
        except Exception:
            return None


class TextClassificationDataset(Dataset):
    def __init__(
        self,
        records: Sequence[Dict[str, Any]],
        tokenizer: Any,
        max_length: int,
    ) -> None:
        self.records = list(records)
        self.tokenizer = tokenizer
        self.max_length = max_length

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> Optional[Dict[str, torch.Tensor]]:
        record = self.records[index]
        try:
            encoded = self.tokenizer(
                record["text"],
                truncation=True,
                padding="max_length",
                max_length=self.max_length,
                return_tensors="pt",
            )
            item = {key: value.squeeze(0) for key, value in encoded.items()}
            item["labels"] = torch.tensor(int(record["label"]), dtype=torch.long)
            return item
        except Exception:
            return None


def make_image_collate_fn(image_processor: Any):
    def collate_fn(batch: Sequence[Optional[Dict[str, Any]]]) -> Optional[Dict[str, torch.Tensor]]:
        valid_batch = [item for item in batch if item is not None]
        if not valid_batch:
            return None
        images = [item["image"] for item in valid_batch]
        labels = torch.tensor([item["labels"] for item in valid_batch], dtype=torch.long)
        encoded = image_processor(images=images, return_tensors="pt")
        encoded["labels"] = labels
        return encoded

    return collate_fn


def text_collate_fn(
    batch: Sequence[Optional[Dict[str, torch.Tensor]]]
) -> Optional[Dict[str, torch.Tensor]]:
    valid_batch = [item for item in batch if item is not None]
    if not valid_batch:
        return None
    keys = valid_batch[0].keys()
    return {key: torch.stack([item[key] for item in valid_batch]) for key in keys}


def create_dataloader(
    dataset: Dataset,
    batch_size: int,
    shuffle: bool,
    collate_fn: Any,
    num_workers: int,
    pin_memory: bool,
) -> DataLoader:
    use_persistent_workers = num_workers > 0
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=num_workers,
        pin_memory=pin_memory,
        persistent_workers=use_persistent_workers,
        collate_fn=collate_fn,
        drop_last=False,
    )


def move_batch_to_device(
    batch: Dict[str, torch.Tensor],
    device: torch.device,
) -> Dict[str, torch.Tensor]:
    return {key: value.to(device, non_blocking=True) for key, value in batch.items()}


def accuracy_from_logits(logits: torch.Tensor, labels: torch.Tensor) -> Tuple[int, int]:
    predictions = torch.argmax(logits, dim=-1)
    correct = int((predictions == labels).sum().item())
    total = int(labels.numel())
    return correct, total


@torch.no_grad()
def evaluate_classifier(
    model: torch.nn.Module,
    data_loader: DataLoader,
    device: torch.device,
    use_amp: bool,
) -> Dict[str, float]:
    model.eval()
    total_loss = 0.0
    total_correct = 0
    total_examples = 0
    total_batches = 0

    for batch in data_loader:
        if batch is None:
            continue
        batch = move_batch_to_device(batch, device)
        autocast_context = (
            torch.autocast(device_type="cuda", dtype=torch.float16)
            if use_amp and device.type == "cuda"
            else nullcontext()
        )
        with autocast_context:
            outputs = model(**batch)
        loss = outputs.loss
        correct, total = accuracy_from_logits(outputs.logits, batch["labels"])
        total_loss += float(loss.item())
        total_correct += correct
        total_examples += total
        total_batches += 1

    if total_batches == 0 or total_examples == 0:
        return {"loss": 0.0, "accuracy": 0.0, "examples": 0}

    return {
        "loss": total_loss / max(total_batches, 1),
        "accuracy": total_correct / max(total_examples, 1),
        "examples": float(total_examples),
    }


def train_classifier(
    *,
    model: torch.nn.Module,
    train_loader: DataLoader,
    validation_loader: DataLoader,
    device: torch.device,
    epochs: int,
    learning_rate: float,
    weight_decay: float,
    use_amp: bool,
    task_name: str,
) -> Dict[str, float]:
    optimizer = torch.optim.AdamW(
        params=model.parameters(),
        lr=learning_rate,
        weight_decay=weight_decay,
    )
    scaler = torch.cuda.amp.GradScaler(enabled=use_amp and device.type == "cuda")
    best_validation_accuracy = -1.0
    best_state_dict: Optional[Dict[str, torch.Tensor]] = None

    for epoch in range(1, epochs + 1):
        model.train()
        running_loss = 0.0
        running_correct = 0
        running_examples = 0
        running_batches = 0

        for step, batch in enumerate(train_loader, start=1):
            if batch is None:
                continue

            batch = move_batch_to_device(batch, device)
            optimizer.zero_grad(set_to_none=True)

            autocast_context = (
                torch.autocast(device_type="cuda", dtype=torch.float16)
                if use_amp and device.type == "cuda"
                else nullcontext()
            )
            with autocast_context:
                outputs = model(**batch)
                loss = outputs.loss

            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()

            correct, total = accuracy_from_logits(outputs.logits, batch["labels"])
            running_loss += float(loss.item())
            running_correct += correct
            running_examples += total
            running_batches += 1

            if step % 10 == 0 or step == len(train_loader):
                current_accuracy = running_correct / max(running_examples, 1)
                log(
                    f"{task_name} | epoch {epoch}/{epochs} | step {step}/{len(train_loader)} "
                    f"| loss {running_loss / max(running_batches, 1):.4f} "
                    f"| acc {current_accuracy:.4f}"
                )

        if running_batches == 0 or running_examples == 0:
            raise RuntimeError(f"{task_name} training produced zero valid batches.")

        train_loss = running_loss / max(running_batches, 1)
        train_accuracy = running_correct / max(running_examples, 1)
        validation_metrics = evaluate_classifier(
            model=model,
            data_loader=validation_loader,
            device=device,
            use_amp=use_amp,
        )
        validation_accuracy = validation_metrics["accuracy"]

        log(
            f"{task_name} | epoch {epoch}/{epochs} completed | "
            f"train_loss {train_loss:.4f} | train_acc {train_accuracy:.4f} | "
            f"val_loss {validation_metrics['loss']:.4f} | val_acc {validation_accuracy:.4f}"
        )

        if validation_accuracy >= best_validation_accuracy:
            best_validation_accuracy = validation_accuracy
            best_state_dict = {
                key: value.detach().cpu().clone()
                for key, value in model.state_dict().items()
            }

    if best_state_dict is not None:
        model.load_state_dict(best_state_dict)

    final_metrics = evaluate_classifier(
        model=model,
        data_loader=validation_loader,
        device=device,
        use_amp=use_amp,
    )
    log(
        f"{task_name} | best validation accuracy {best_validation_accuracy:.4f} | "
        f"final eval accuracy {final_metrics['accuracy']:.4f}"
    )
    return final_metrics


class DualClassifierSystem:
    def __init__(self, config: RuntimeConfig) -> None:
        self.config = config
        self.output_dir = Path(config.output_dir).resolve()
        self.image_model_dir = self.output_dir / "image_model"
        self.text_model_dir = self.output_dir / "text_model"
        self.metadata_path = self.output_dir / "metadata.json"
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.image_processor: Any = None
        self.image_model: Any = None
        self.tokenizer: Any = None
        self.text_model: Any = None
        self.metadata: Dict[str, Any] = {"runtime_config": asdict(config)}

    def build_models(self) -> None:
        log(f"Using device: {self.device}")

        self.image_processor = AutoImageProcessor.from_pretrained(self.config.image_model_name)
        self.image_model = AutoModelForImageClassification.from_pretrained(
            self.config.image_model_name,
            num_labels=2,
            ignore_mismatched_sizes=True,
            id2label={0: "Real", 1: "Fake"},
            label2id={"Real": 0, "Fake": 1},
        ).to(self.device)

        self.tokenizer = AutoTokenizer.from_pretrained(self.config.text_model_name, use_fast=True)
        self.text_model = AutoModelForSequenceClassification.from_pretrained(
            self.config.text_model_name,
            num_labels=2,
            id2label={0: "Real", 1: "Spam"},
            label2id={"Real": 0, "Spam": 1},
        ).to(self.device)

    def build_image_dataloaders(
        self,
        sources: Sequence[DatasetSource],
    ) -> Tuple[DataLoader, DataLoader, Dict[str, Any]]:
        dataset, source = load_hf_dataset(sources)
        records, skipped = prepare_image_records(
            dataset=dataset,
            source=source,
            seed=self.config.seed,
            balance=self.config.balance_datasets,
        )
        train_records, validation_records = stratified_split(
            records=records,
            validation_ratio=self.config.validation_ratio,
            seed=self.config.seed,
        )

        train_dataset = SafeImageDataset(train_records)
        validation_dataset = SafeImageDataset(validation_records)
        collate_fn = make_image_collate_fn(self.image_processor)
        pin_memory = self.device.type == "cuda"

        train_loader = create_dataloader(
            dataset=train_dataset,
            batch_size=self.config.image_batch_size,
            shuffle=True,
            collate_fn=collate_fn,
            num_workers=self.config.num_workers,
            pin_memory=pin_memory,
        )
        validation_loader = create_dataloader(
            dataset=validation_dataset,
            batch_size=self.config.image_batch_size,
            shuffle=False,
            collate_fn=collate_fn,
            num_workers=self.config.num_workers,
            pin_memory=pin_memory,
        )

        summary = {
            "dataset_name": source.name,
            "split": source.split,
            "train_size": len(train_records),
            "validation_size": len(validation_records),
            "skipped_samples": skipped,
        }
        return train_loader, validation_loader, summary

    def build_text_dataloaders(
        self,
        sources: Sequence[DatasetSource],
    ) -> Tuple[DataLoader, DataLoader, Dict[str, Any]]:
        dataset, source = load_hf_dataset(sources)
        records, skipped = prepare_text_records(
            dataset=dataset,
            source=source,
            seed=self.config.seed,
            balance=self.config.balance_datasets,
        )
        train_records, validation_records = stratified_split(
            records=records,
            validation_ratio=self.config.validation_ratio,
            seed=self.config.seed,
        )

        train_dataset = TextClassificationDataset(
            train_records,
            tokenizer=self.tokenizer,
            max_length=self.config.max_text_length,
        )
        validation_dataset = TextClassificationDataset(
            validation_records,
            tokenizer=self.tokenizer,
            max_length=self.config.max_text_length,
        )
        pin_memory = self.device.type == "cuda"

        train_loader = create_dataloader(
            dataset=train_dataset,
            batch_size=self.config.text_batch_size,
            shuffle=True,
            collate_fn=text_collate_fn,
            num_workers=self.config.num_workers,
            pin_memory=pin_memory,
        )
        validation_loader = create_dataloader(
            dataset=validation_dataset,
            batch_size=self.config.text_batch_size,
            shuffle=False,
            collate_fn=text_collate_fn,
            num_workers=self.config.num_workers,
            pin_memory=pin_memory,
        )

        summary = {
            "dataset_name": source.name,
            "split": source.split,
            "train_size": len(train_records),
            "validation_size": len(validation_records),
            "skipped_samples": skipped,
        }
        return train_loader, validation_loader, summary

    def train(
        self,
        image_sources: Sequence[DatasetSource],
        text_sources: Sequence[DatasetSource],
    ) -> Dict[str, Any]:
        self.build_models()

        log("Preparing image classification data")
        image_train_loader, image_validation_loader, image_summary = self.build_image_dataloaders(
            image_sources
        )
        log(
            "Image data ready | "
            f"train={image_summary['train_size']} | val={image_summary['validation_size']} | "
            f"skipped={image_summary['skipped_samples']}"
        )

        log("Preparing text classification data")
        text_train_loader, text_validation_loader, text_summary = self.build_text_dataloaders(
            text_sources
        )
        log(
            "Text data ready | "
            f"train={text_summary['train_size']} | val={text_summary['validation_size']} | "
            f"skipped={text_summary['skipped_samples']}"
        )

        image_metrics = train_classifier(
            model=self.image_model,
            train_loader=image_train_loader,
            validation_loader=image_validation_loader,
            device=self.device,
            epochs=self.config.image_epochs,
            learning_rate=self.config.image_learning_rate,
            weight_decay=self.config.weight_decay,
            use_amp=self.config.use_mixed_precision,
            task_name="ImageClassifier",
        )

        text_metrics = train_classifier(
            model=self.text_model,
            train_loader=text_train_loader,
            validation_loader=text_validation_loader,
            device=self.device,
            epochs=self.config.text_epochs,
            learning_rate=self.config.text_learning_rate,
            weight_decay=self.config.weight_decay,
            use_amp=self.config.use_mixed_precision,
            task_name="TextClassifier",
        )

        self.metadata.update(
            {
                "image_data": image_summary,
                "text_data": text_summary,
                "image_metrics": image_metrics,
                "text_metrics": text_metrics,
            }
        )
        return self.metadata

    def save(self) -> None:
        if any(
            component is None
            for component in [
                self.image_model,
                self.text_model,
                self.image_processor,
                self.tokenizer,
            ]
        ):
            raise RuntimeError("Cannot save before models and processors are initialized.")

        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.image_model_dir.mkdir(parents=True, exist_ok=True)
        self.text_model_dir.mkdir(parents=True, exist_ok=True)

        self.image_model.save_pretrained(self.image_model_dir)
        self.image_processor.save_pretrained(self.image_model_dir)
        self.text_model.save_pretrained(self.text_model_dir)
        self.tokenizer.save_pretrained(self.text_model_dir)

        with self.metadata_path.open("w", encoding="utf-8") as handle:
            json.dump(self.metadata, handle, indent=2)

        log(f"Saved image model to {self.image_model_dir}")
        log(f"Saved text model to {self.text_model_dir}")
        log(f"Saved metadata to {self.metadata_path}")

    @classmethod
    def load_from_disk(cls, load_dir: str) -> "DualClassifierSystem":
        load_path = Path(load_dir).resolve()
        metadata_path = load_path / "metadata.json"
        config = RuntimeConfig(output_dir=str(load_path))
        system = cls(config=config)

        if metadata_path.exists():
            with metadata_path.open("r", encoding="utf-8") as handle:
                metadata = json.load(handle)
            runtime_overrides = metadata.get("runtime_config", {})
            config = RuntimeConfig(
                **{**asdict(config), **runtime_overrides, "output_dir": str(load_path)}
            )
            system = cls(config=config)
            system.metadata = metadata

        system.image_processor = AutoImageProcessor.from_pretrained(load_path / "image_model")
        system.image_model = AutoModelForImageClassification.from_pretrained(
            load_path / "image_model"
        ).to(system.device)
        system.tokenizer = AutoTokenizer.from_pretrained(load_path / "text_model", use_fast=True)
        system.text_model = AutoModelForSequenceClassification.from_pretrained(
            load_path / "text_model"
        ).to(system.device)
        log(f"Loaded models from {load_path}")
        return system

    @torch.no_grad()
    def predict_image(self, image_path: str) -> str:
        if self.image_model is None or self.image_processor is None:
            raise RuntimeError("Image model is not loaded.")

        try:
            image = open_image_safely(image_path)
            encoded = self.image_processor(images=image, return_tensors="pt")
            encoded = move_batch_to_device(encoded, self.device)
            self.image_model.eval()
            logits = self.image_model(**encoded).logits
            label_id = int(torch.argmax(logits, dim=-1).item())
            return "Fake" if label_id == 1 else "Real"
        except Exception as exc:
            raise RuntimeError(f"Image prediction failed for {image_path}: {exc}") from exc

    @torch.no_grad()
    def predict_email(self, text: str) -> str:
        if self.text_model is None or self.tokenizer is None:
            raise RuntimeError("Text model is not loaded.")
        if not str(text).strip():
            raise ValueError("Input text is empty.")

        try:
            encoded = self.tokenizer(
                text,
                truncation=True,
                padding=True,
                max_length=self.config.max_text_length,
                return_tensors="pt",
            )
            encoded = move_batch_to_device(encoded, self.device)
            self.text_model.eval()
            logits = self.text_model(**encoded).logits
            label_id = int(torch.argmax(logits, dim=-1).item())
            return "Spam" if label_id == 1 else "Real"
        except Exception as exc:
            raise RuntimeError(f"Text prediction failed: {exc}") from exc

    def interactive_loop(self) -> None:
        log("Interactive mode started. Type 'quit' to exit.")
        log("Examples: image:/path/to/file.jpg   |   text:Free gift card waiting for you")
        while True:
            try:
                user_input = input("predict> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                break

            if not user_input:
                continue
            if user_input.lower() in {"quit", "exit"}:
                break
            if user_input.lower().startswith("image:"):
                result = self.predict_image(user_input.split(":", 1)[1].strip())
                print(f"Image prediction: {result}")
            elif user_input.lower().startswith("text:"):
                result = self.predict_email(user_input.split(":", 1)[1].strip())
                print(f"Text prediction: {result}")
            else:
                print("Use 'image:<path>' or 'text:<message>' or 'quit'.")


ACTIVE_SYSTEM: Optional[DualClassifierSystem] = None
DEFAULT_LOAD_DIR = "artifacts"


def ensure_active_system() -> DualClassifierSystem:
    global ACTIVE_SYSTEM
    if ACTIVE_SYSTEM is None:
        ACTIVE_SYSTEM = DualClassifierSystem.load_from_disk(DEFAULT_LOAD_DIR)
    return ACTIVE_SYSTEM


def predict_image(image_path: str) -> str:
    return ensure_active_system().predict_image(image_path)


def predict_email(text: str) -> str:
    return ensure_active_system().predict_email(text)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train, evaluate, save, and run image/text binary classifiers."
    )
    parser.add_argument("--output-dir", type=str, default="artifacts")
    parser.add_argument("--load-dir", type=str, default="artifacts")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--image-epochs", type=int, default=2)
    parser.add_argument("--text-epochs", type=int, default=2)
    parser.add_argument("--image-batch-size", type=int, default=8)
    parser.add_argument("--text-batch-size", type=int, default=16)
    parser.add_argument("--image-lr", type=float, default=2e-5)
    parser.add_argument("--text-lr", type=float, default=2e-5)
    parser.add_argument("--max-text-length", type=int, default=192)
    parser.add_argument("--validation-ratio", type=float, default=0.2)
    parser.add_argument("--num-workers", type=int, default=default_num_workers())
    parser.add_argument("--disable-amp", action="store_true")
    parser.add_argument("--no-balance", action="store_true")
    parser.add_argument("--skip-training", action="store_true")
    parser.add_argument("--interactive", action="store_true")
    parser.add_argument("--image-dataset", type=str, default="")
    parser.add_argument("--text-dataset", type=str, default="")
    parser.add_argument("--image-split", type=str, default="train")
    parser.add_argument("--text-split", type=str, default="train")
    parser.add_argument("--image-column", type=str, default="image")
    parser.add_argument("--text-column", type=str, default="message")
    parser.add_argument("--image-label-column", type=str, default="label")
    parser.add_argument("--text-label-column", type=str, default="label")
    parser.add_argument("--image-max-samples", type=int, default=1400)
    parser.add_argument("--text-max-samples", type=int, default=2000)
    return parser.parse_args()


def build_runtime_config(args: argparse.Namespace) -> RuntimeConfig:
    return RuntimeConfig(
        output_dir=args.output_dir,
        seed=args.seed,
        validation_ratio=args.validation_ratio,
        image_epochs=args.image_epochs,
        text_epochs=args.text_epochs,
        image_batch_size=args.image_batch_size,
        text_batch_size=args.text_batch_size,
        image_learning_rate=args.image_lr,
        text_learning_rate=args.text_lr,
        max_text_length=args.max_text_length,
        use_mixed_precision=not args.disable_amp,
        balance_datasets=not args.no_balance,
        num_workers=args.num_workers,
    )


def build_image_sources(args: argparse.Namespace) -> List[DatasetSource]:
    if args.image_dataset:
        return [
            DatasetSource(
                name=args.image_dataset,
                split=args.image_split,
                image_column=args.image_column,
                label_column=args.image_label_column,
                max_samples=args.image_max_samples,
                numeric_label_map={0: 1, 1: 0},
            )
        ]

    sources: List[DatasetSource] = []
    for source in DEFAULT_IMAGE_SOURCES:
        copy_source = DatasetSource(**asdict(source))
        copy_source.max_samples = args.image_max_samples
        sources.append(copy_source)
    return sources


def build_text_sources(args: argparse.Namespace) -> List[DatasetSource]:
    if args.text_dataset:
        return [
            DatasetSource(
                name=args.text_dataset,
                split=args.text_split,
                text_column=args.text_column,
                label_column=args.text_label_column,
                max_samples=args.text_max_samples,
            )
        ]

    sources: List[DatasetSource] = []
    for source in DEFAULT_TEXT_SOURCES:
        copy_source = DatasetSource(**asdict(source))
        copy_source.max_samples = args.text_max_samples
        sources.append(copy_source)
    return sources


def main() -> None:
    global ACTIVE_SYSTEM, DEFAULT_LOAD_DIR

    args = parse_args()
    seed_everything(args.seed)
    DEFAULT_LOAD_DIR = args.load_dir

    if args.skip_training:
        ACTIVE_SYSTEM = DualClassifierSystem.load_from_disk(args.load_dir)
        if args.interactive:
            ACTIVE_SYSTEM.interactive_loop()
        return

    config = build_runtime_config(args)
    ACTIVE_SYSTEM = DualClassifierSystem(config=config)
    metadata = ACTIVE_SYSTEM.train(
        image_sources=build_image_sources(args),
        text_sources=build_text_sources(args),
    )
    ACTIVE_SYSTEM.save()

    log(
        "Training complete | "
        f"image_val_acc={metadata['image_metrics']['accuracy']:.4f} | "
        f"text_val_acc={metadata['text_metrics']['accuracy']:.4f}"
    )

    if args.interactive:
        ACTIVE_SYSTEM.interactive_loop()


if __name__ == "__main__":
    try:
        main()
    except ImportError as exc:
        missing = getattr(exc, "name", "a dependency")
        raise SystemExit(
            f"Missing dependency: {missing}. Install requirements with:\n"
            "pip install torch torchvision transformers datasets pillow numpy"
        ) from exc
    except Exception as exc:
        log(f"Fatal error: {exc}")
        raise
