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
import nltk
from nltk.stem import WordNetLemmatizer

nltk.download('wordnet', quiet=True)
nltk.download('omw-1.4', quiet=True)
from collections import Counter
from tqdm import tqdm

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
_lemmatizer = WordNetLemmatizer()

def tokenize(sentence: str):
    words = re.findall(r"\b\w+\b", sentence.lower())
    return [_lemmatizer.lemmatize(w) for w in words]

# ── Emotion Grouping ─────────────────────────────────────────
EMOTION_MAP = {
    # Joy: strong positive emotions — personal achievement, warmth, happiness
    'amusement': 'Joy', 'enthusiasm': 'Joy', 'excitement': 'Joy', 'fun': 'Joy',
    'happiness': 'Joy', 'joy': 'Joy', 'pride': 'Joy',
    'admiration': 'Joy', 'gratitude': 'Joy', 'love': 'Joy',

    # Calm: peaceful, grounded, relieved
    'calm': 'Calm', 'relief': 'Calm',

    # Sadness: loss, grief, regret
    'disappointment': 'Sadness', 'empty': 'Sadness', 'grief': 'Sadness',
    'remorse': 'Sadness', 'sadness': 'Sadness',

    # Anxiety: fear, worry, nervousness
    'anxiety': 'Anxiety', 'fear': 'Anxiety', 'nervousness': 'Anxiety', 'worry': 'Anxiety',

    # Anger: hostility, frustration, moral disapproval
    'anger': 'Anger', 'annoyance': 'Anger', 'disapproval': 'Anger',
    'disgust': 'Anger', 'hate': 'Anger',

    # Hopeful: forward-looking, supportive, aspirational
    'optimism': 'Hopeful', 'approval': 'Hopeful', 'caring': 'Hopeful', 'desire': 'Hopeful',

    # Overwhelmed: internally distressing self-conscious emotions
    'confusion': 'Overwhelmed', 'embarrassment': 'Overwhelmed',
    'guilt': 'Overwhelmed', 'shame': 'Overwhelmed',

    # Neutral: observational, cognitive, everyday states
    'neutral': 'Neutral', 'boredom': 'Neutral', 'curiosity': 'Neutral',
    'realization': 'Neutral', 'surprise': 'Neutral',
}


# ── Load CSV dataset ─────────────────────────────────────────
def load_dataset(path="emotion_dataset.csv"):
    print(f"[DATA] Loading dataset from {path}...")
    texts, labels_raw = [], []
    with open(path, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            text = row["text"].strip()
            label_raw = row["label"].strip()
            if text and label_raw:
                mapped_label = EMOTION_MAP.get(label_raw, "Neutral")
                texts.append(text)
                labels_raw.append(mapped_label)

    # Build sorted label list (ensures consistent index mapping)
    tags = sorted(set(labels_raw))
    label_to_idx = {tag: i for i, tag in enumerate(tags)}

    print(f"[OK] Loaded {len(texts)} samples across {len(tags)} classes: {tags}")
    label_counts = Counter(labels_raw)
    for tag in tags:
        print(f"   {tag:<12} : {label_counts[tag]} samples")

    return texts, labels_raw, tags, label_to_idx


# ── Vocabulary ───────────────────────────────────────────────
def build_vocab(texts, min_freq=2):
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

import torch.nn.functional as F

class FocalLoss(nn.Module):
    def __init__(self, alpha=None, gamma=2.0, reduction='mean', label_smoothing=0.05):
        super(FocalLoss, self).__init__()
        self.alpha = alpha
        self.gamma = gamma
        self.reduction = reduction
        self.label_smoothing = label_smoothing

    def forward(self, inputs, targets):
        ce_loss = F.cross_entropy(inputs, targets, weight=self.alpha, reduction='none', label_smoothing=self.label_smoothing)
        pt = torch.exp(-ce_loss)
        focal_loss = ((1 - pt) ** self.gamma) * ce_loss
        
        if self.reduction == 'mean':
            return focal_loss.mean()
        elif self.reduction == 'sum':
            return focal_loss.sum()
        else:
            return focal_loss


# ── Evaluation ───────────────────────────────────────────────
def evaluate(model, loader, criterion, device, num_classes):
    model.eval()
    total_loss, correct, total = 0.0, 0, 0
    cm = np.zeros((num_classes, num_classes), dtype=int)
    
    with torch.no_grad():
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            out = model(x)
            loss = criterion(out, y)
            total_loss += loss.item()
            preds = out.argmax(dim=1)
            correct += (preds == y).sum().item()
            total += y.size(0)
            
            for true, pred in zip(y.tolist(), preds.tolist()):
                cm[true, pred] += 1
                
    class_correct = cm.diagonal()
    class_total = cm.sum(axis=1)
    
    f1s = []
    for i in range(num_classes):
        cor = class_correct[i]
        tot = class_total[i]
        pred_tot = cm[:, i].sum()
        precision = cor / pred_tot if pred_tot > 0 else 0.0
        recall = cor / tot if tot > 0 else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0
        f1s.append(f1)
        
    macro_f1 = np.mean(f1s) * 100
    
    return total_loss / max(len(loader), 1), correct / max(total, 1) * 100, macro_f1


def evaluate_per_class(model, loader, tags, device):
    model.eval()
    num_classes = len(tags)
    cm = np.zeros((num_classes, num_classes), dtype=int)
    
    with torch.no_grad():
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            preds = model(x).argmax(dim=1)
            for true, pred in zip(y.tolist(), preds.tolist()):
                cm[true, pred] += 1

    print("\n[RESULTS] Per-Class Metrics (Validation):")
    print(f"  {'Emotion':<12} {'Correct':>8} {'Total':>8} {'Acc':>7} | {'Prec':>6} {'Rec':>6} {'F1':>6}")
    print("  " + "-" * 62)
    
    class_total = cm.sum(axis=1)
    class_correct = cm.diagonal()
    
    precisions = []
    recalls = []
    f1s = []
    
    for i, tag in enumerate(tags):
        tot = class_total[i]
        cor = class_correct[i]
        acc = (cor / tot * 100) if tot > 0 else 0.0
        
        pred_tot = cm[:, i].sum()
        precision = cor / pred_tot if pred_tot > 0 else 0.0
        recall = cor / tot if tot > 0 else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0
        
        precisions.append(precision)
        recalls.append(recall)
        f1s.append(f1)
        
        print(f"  {tag:<12} {cor:>8} {tot:>8} {acc:>6.1f}% | {precision*100:>5.1f}% {recall*100:>5.1f}% {f1*100:>5.1f}%")
        
    macro_precision = np.mean(precisions)
    macro_recall = np.mean(recalls)
    macro_f1 = np.mean(f1s)
    
    print("\n[RESULTS] Overall Metrics:")
    print(f"  Macro Precision: {macro_precision * 100:.1f}%")
    print(f"  Macro Recall   : {macro_recall * 100:.1f}%")
    print(f"  Macro F1       : {macro_f1 * 100:.1f}%")
    
    print("\n[RESULTS] Confusion Matrix:")
    label_str = "True \\ Pred"
    header = f"{label_str:<15}" + "".join([f"{t[:4]:>6}" for t in tags])
    print("  " + header)
    for i, row in enumerate(cm):
        row_str = "".join([f"{val:>6}" for val in row])
        print(f"  {tags[i]:<15}{row_str}")


# ── Main training function ───────────────────────────────────
def train_model():
    print("[START] Starting Emotion Classifier Training (BiLSTM + Attention)...")
    print("=" * 60)

    # ── Hyperparameters ──────────────────────────────────────
    NUM_EPOCHS          = 200
    BATCH_SIZE          = 32
    LEARNING_RATE       = 0.0005
    EMBEDDING_DIM       = 128
    HIDDEN_SIZE         = 128
    NUM_LAYERS          = 2
    DROPOUT             = 0.5  # Increased dropout for regularization
    VALIDATION_RATIO    = 0.2
    EARLY_STOP_PATIENCE = 20
    MIN_DELTA           = 0.005

    texts, labels_raw, tags, label_to_idx = load_dataset("emotion_dataset_combined.csv")
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

    # --- Weighted Random Sampler ---
    train_labels_only = [label_indices[i] for i in train_idx]
    counts = np.bincount(train_labels_only, minlength=num_classes)
    weights = 1.0 / np.maximum(counts, 1)
    sample_weights = [weights[l] for l in train_labels_only]
    sampler = torch.utils.data.WeightedRandomSampler(
        weights=sample_weights,
        num_samples=len(train_labels_only),
        replacement=True
    )
    # -------------------------------

    pad_idx = vocab[PAD_TOKEN]
    collate = lambda b: collate_batch(b, pad_idx=pad_idx, max_len=max_seq_len)

    train_loader = DataLoader(Subset(dataset, train_idx), batch_size=BATCH_SIZE, sampler=sampler, collate_fn=collate)
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

    class_weights = compute_class_weights(train_labels_only, num_classes, device)
    criterion     = FocalLoss(alpha=class_weights, gamma=2.0, label_smoothing=0.05)
    optimizer     = torch.optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=1e-3) # Stronger weight decay
    scheduler     = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=5)

    # ── Training loop ────────────────────────────────────────
    best_macro_f1  = 0.0
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

        # Add tqdm to show progress within the epoch
        batch_iterator = tqdm(train_loader, desc=f"x {epoch+1}/{NUM_EPOCHS}", leave=False)

        for x, y in batch_iterator:
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

            # Update progress bar with running loss
            batch_iterator.set_postfix(loss=f"{loss.item():.4f}")

        train_loss = run_loss / max(len(train_loader), 1)
        train_acc  = correct / max(total, 1) * 100
        val_loss, val_acc, val_macro_f1 = evaluate(model, val_loader, criterion, device, num_classes)
        scheduler.step(val_macro_f1)

        history["train_loss"].append(train_loss)
        history["train_acc"].append(train_acc)
        history["val_loss"].append(val_loss)
        history["val_acc"].append(val_acc)

        # ── Log every 10 epochs ──────────────────────────────
        if (epoch + 1) % 10 == 0 or epoch == 0:
            print(f"  Epoch [{epoch+1:>3}/{NUM_EPOCHS}] "
                  f"Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.1f}% | "
                  f"Val Loss: {val_loss:.4f} | Val F1: {val_macro_f1:.1f}%")

        # ── Save best ────────────────────────────────────────
        improved = False
        if val_macro_f1 > best_macro_f1 + MIN_DELTA:
            best_macro_f1 = val_macro_f1
            best_val_acc  = val_acc
            best_val_loss = val_loss
            patience_counter = 0
            improved = True
        elif abs(val_macro_f1 - best_macro_f1) <= MIN_DELTA and val_loss < best_val_loss:
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
                "best_macro_f1": best_macro_f1,
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
            "best_val_acc": best_val_acc, "best_val_loss": best_val_loss, "best_macro_f1": best_macro_f1,
            "history": history,
        }

    model.load_state_dict(best_model_data["model_state"])
    model.to(device)
    evaluate_per_class(model, val_loader, tags, device)

    torch.save(best_model_data, "emotion_model_data.pth")

    print("\n" + "=" * 60)
    print(f"[RESULT] Best Validation Accuracy : {best_val_acc:.2f}%")
    print(f"[RESULT] Best Validation Macro F1 : {best_macro_f1:.2f}%")
    print(f"[RESULT] Best Validation Loss     : {best_val_loss:.4f}")
    print("[SAVED]  Model saved -> emotion_model_data.pth")
    print("=" * 60)


if __name__ == "__main__":
    train_model()
