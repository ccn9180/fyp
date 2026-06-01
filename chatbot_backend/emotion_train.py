"""
emotion_train.py
----------------
Trains a BiLSTM + Attention emotion classifier for diary entries.
Uses the same CustomNeuralNet architecture as the chatbot model.
Reads from emotion_dataset.csv and saves to emotion_model_data.pth
"""

import csv
import re
import random
from collections import Counter

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader, Subset

from custom_model import CustomNeuralNet

# ── Reproducibility ──────────────────────────────────────────
SEED = 42
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)

PAD_TOKEN = "<PAD>"
UNK_TOKEN = "<UNK>"


# ── Tokeniser ────────────────────────────────────────────────
def tokenize(sentence: str):
    return re.findall(r"\b\w+\b", sentence.lower())


# ── Load CSV dataset ─────────────────────────────────────────
def load_dataset(path="emotion_dataset.csv"):
    print(f"[DATA] Loading dataset from {path}...")
    texts, labels_raw = [], []
    with open(path, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            text = row["text"].strip()
            label = row["label"].strip()
            if text and label:
                texts.append(text)
                labels_raw.append(label)

    # Build sorted label list (ensures consistent index mapping)
    tags = sorted(set(labels_raw))
    label_to_idx = {tag: i for i, tag in enumerate(tags)}

    print(f"[OK] Loaded {len(texts)} samples across {len(tags)} classes: {tags}")
    label_counts = Counter(labels_raw)
    for tag in tags:
        print(f"   {tag:<12} : {label_counts[tag]} samples")

    return texts, labels_raw, tags, label_to_idx


# ── Vocabulary ───────────────────────────────────────────────
def build_vocab(texts, min_freq=1):
    counter = Counter()
    for text in texts:
        counter.update(tokenize(text))
    vocab = {PAD_TOKEN: 0, UNK_TOKEN: 1}
    for word, freq in sorted(counter.items()):
        if freq >= min_freq:
            vocab[word] = len(vocab)
    return vocab


def encode(tokens, vocab):
    return [vocab.get(t, vocab[UNK_TOKEN]) for t in tokens]


# ── Dataset class ─────────────────────────────────────────────
class EmotionDataset(Dataset):
    def __init__(self, sequences, labels):
        self.sequences = sequences
        self.labels = labels

    def __getitem__(self, index):
        return self.sequences[index], self.labels[index]

    def __len__(self):
        return len(self.sequences)


def collate_batch(batch, pad_idx=0, max_len=None):
    sequences, labels = zip(*batch)
    if max_len is None:
        max_len = max(len(s) for s in sequences)
    padded = [s + [pad_idx] * (max_len - len(s)) for s in sequences]
    return (
        torch.tensor(padded, dtype=torch.long),
        torch.tensor(labels, dtype=torch.long),
    )


# ── Stratified split ─────────────────────────────────────────
def stratified_split(labels, val_ratio=0.2, seed=42):
    random.seed(seed)
    label_to_indices = {}
    for idx, label in enumerate(labels):
        label_to_indices.setdefault(label, []).append(idx)

    train_idx, val_idx = [], []
    for label, indices in label_to_indices.items():
        random.shuffle(indices)
        if len(indices) <= 2:
            train_idx.extend(indices)
            continue
        n_val = max(1, int(len(indices) * val_ratio))
        val_idx.extend(indices[:n_val])
        train_idx.extend(indices[n_val:])

    random.shuffle(train_idx)
    random.shuffle(val_idx)
    return train_idx, val_idx


# ── Class weights ────────────────────────────────────────────
def compute_class_weights(labels, num_classes, device):
    counts = Counter(labels)
    total = len(labels)
    weights = [total / (num_classes * counts.get(i, 1)) for i in range(num_classes)]
    return torch.tensor(weights, dtype=torch.float32, device=device)


# ── Evaluation ───────────────────────────────────────────────
def evaluate(model, loader, criterion, device):
    model.eval()
    total_loss, correct, total = 0.0, 0, 0
    with torch.no_grad():
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            out = model(x)
            loss = criterion(out, y)
            total_loss += loss.item()
            preds = out.argmax(dim=1)
            correct += (preds == y).sum().item()
            total += y.size(0)
    return total_loss / max(len(loader), 1), correct / max(total, 1) * 100


def evaluate_per_class(model, loader, tags, device):
    model.eval()
    class_correct = {t: 0 for t in tags}
    class_total   = {t: 0 for t in tags}
    with torch.no_grad():
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            preds = model(x).argmax(dim=1)
            for true, pred in zip(y.tolist(), preds.tolist()):
                tag = tags[true]
                class_total[tag] += 1
                if true == pred:
                    class_correct[tag] += 1
    print("\n[RESULTS] Per-Class Accuracy (Validation):")
    print(f"  {'Emotion':<12} {'Correct':>8} {'Total':>8} {'Acc':>8}")
    print("  " + "-" * 42)
    for tag in tags:
        tot = class_total[tag]
        cor = class_correct[tag]
        acc = (cor / tot * 100) if tot > 0 else 0.0
        print(f"  {tag:<12} {cor:>8} {tot:>8} {acc:>7.1f}%")


# ── Main training function ───────────────────────────────────
def train_model():
    print("[START] Starting Emotion Classifier Training (BiLSTM + Attention)...")
    print("=" * 60)

    # ── Hyperparameters ──────────────────────────────────────
    NUM_EPOCHS          = 200
    BATCH_SIZE          = 16
    LEARNING_RATE       = 0.0008
    EMBEDDING_DIM       = 64
    HIDDEN_SIZE         = 64        # Reduced from 128 → less capacity → less overfitting
    NUM_LAYERS          = 2
    DROPOUT             = 0.5       # Increased from 0.35 → stronger regularisation
    VALIDATION_RATIO    = 0.2
    EARLY_STOP_PATIENCE = 30        # More patience to find better generalisation
    MIN_DELTA           = 0.005

    # ── Data ─────────────────────────────────────────────────
    texts, labels_raw, tags, label_to_idx = load_dataset("emotion_dataset.csv")
    vocab = build_vocab(texts)

    label_indices = [label_to_idx[l] for l in labels_raw]
    sequences = []
    for text in texts:
        tokens = tokenize(text)
        seq = encode(tokens, vocab)
        sequences.append(seq if seq else [vocab[UNK_TOKEN]])

    max_seq_len = max(len(s) for s in sequences)
    vocab_size  = len(vocab)
    num_classes = len(tags)

    dataset = EmotionDataset(sequences, label_indices)
    train_idx, val_idx = stratified_split(label_indices, val_ratio=VALIDATION_RATIO, seed=SEED)

    pad_idx = vocab[PAD_TOKEN]
    collate = lambda b: collate_batch(b, pad_idx=pad_idx, max_len=max_seq_len)

    train_loader = DataLoader(Subset(dataset, train_idx), batch_size=BATCH_SIZE, shuffle=True,  collate_fn=collate)
    val_loader   = DataLoader(Subset(dataset, val_idx),   batch_size=BATCH_SIZE, shuffle=False, collate_fn=collate)

    # ── Model ────────────────────────────────────────────────
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\n[DEVICE] Device: {device}")

    model = CustomNeuralNet(
        vocab_size=vocab_size,
        embedding_dim=EMBEDDING_DIM,
        hidden_size=HIDDEN_SIZE,
        num_classes=num_classes,
        pad_idx=pad_idx,
        num_layers=NUM_LAYERS,
        dropout=DROPOUT,
    ).to(device)

    train_labels_only = [label_indices[i] for i in train_idx]
    class_weights = compute_class_weights(train_labels_only, num_classes, device)
    criterion     = nn.CrossEntropyLoss(weight=class_weights, label_smoothing=0.1)
    optimizer     = torch.optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=5e-4)
    scheduler     = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=7)

    # ── Training loop ────────────────────────────────────────
    best_val_acc   = 0.0
    best_val_loss  = float("inf")
    best_model_data = None
    patience_counter = 0
    history = {"train_loss": [], "train_acc": [], "val_loss": [], "val_acc": []}

    print(f"\n[TRAIN] Training for up to {NUM_EPOCHS} epochs (early stop patience={EARLY_STOP_PATIENCE})...")
    print(f"   Train samples: {len(train_idx)} | Val samples: {len(val_idx)}")
    print()

    for epoch in range(NUM_EPOCHS):
        model.train()
        run_loss, correct, total = 0.0, 0, 0
        for x, y in train_loader:
            x, y = x.to(device), y.to(device)
            out  = model(x)
            loss = criterion(out, y)
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()

            run_loss += loss.item()
            preds     = out.argmax(dim=1)
            correct  += (preds == y).sum().item()
            total    += y.size(0)

        train_loss = run_loss / max(len(train_loader), 1)
        train_acc  = correct / max(total, 1) * 100
        val_loss, val_acc = evaluate(model, val_loader, criterion, device)
        scheduler.step(val_acc)

        history["train_loss"].append(train_loss)
        history["train_acc"].append(train_acc)
        history["val_loss"].append(val_loss)
        history["val_acc"].append(val_acc)

        # ── Log every 10 epochs ──────────────────────────────
        if (epoch + 1) % 10 == 0 or epoch == 0:
            print(f"  Epoch [{epoch+1:>3}/{NUM_EPOCHS}] "
                  f"Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.1f}% | "
                  f"Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.1f}%")

        # ── Save best ────────────────────────────────────────
        improved = False
        if val_acc > best_val_acc + MIN_DELTA:
            best_val_acc  = val_acc
            best_val_loss = val_loss
            patience_counter = 0
            improved = True
        elif abs(val_acc - best_val_acc) <= MIN_DELTA and val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            improved = True
        else:
            patience_counter += 1

        if improved:
            best_model_data = {
                "model_state":   {k: v.detach().cpu().clone() for k, v in model.state_dict().items()},
                "vocab":         vocab,
                "tags":          tags,
                "vocab_size":    vocab_size,
                "embedding_dim": EMBEDDING_DIM,
                "hidden_size":   HIDDEN_SIZE,
                "output_size":   num_classes,
                "num_layers":    NUM_LAYERS,
                "dropout":       DROPOUT,
                "pad_idx":       pad_idx,
                "unk_idx":       vocab[UNK_TOKEN],
                "max_seq_len":   max_seq_len,
                "seed":          SEED,
                "best_val_acc":  best_val_acc,
                "best_val_loss": best_val_loss,
                "history":       history,
            }

        if patience_counter >= EARLY_STOP_PATIENCE:
            print(f"[STOP] Early stopping at epoch {epoch+1} (no improvement for {EARLY_STOP_PATIENCE} epochs)")
            break

    # ── Final evaluation ─────────────────────────────────────
    if best_model_data is None:
        best_model_data = {
            "model_state":   {k: v.detach().cpu().clone() for k, v in model.state_dict().items()},
            "vocab": vocab, "tags": tags, "vocab_size": vocab_size,
            "embedding_dim": EMBEDDING_DIM, "hidden_size": HIDDEN_SIZE,
            "output_size": num_classes, "num_layers": NUM_LAYERS,
            "dropout": DROPOUT, "pad_idx": pad_idx, "unk_idx": vocab[UNK_TOKEN],
            "max_seq_len": max_seq_len, "seed": SEED,
            "best_val_acc": best_val_acc, "best_val_loss": best_val_loss,
            "history": history,
        }

    model.load_state_dict(best_model_data["model_state"])
    model.to(device)
    evaluate_per_class(model, val_loader, tags, device)

    torch.save(best_model_data, "emotion_model_data.pth")

    print("\n" + "=" * 60)
    print(f"[RESULT] Best Validation Accuracy : {best_val_acc:.2f}%")
    print(f"[RESULT] Best Validation Loss     : {best_val_loss:.4f}")
    print("[SAVED]  Model saved -> emotion_model_data.pth")
    print("=" * 60)


if __name__ == "__main__":
    train_model()
