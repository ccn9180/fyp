import json
import re
import random
from collections import Counter

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader, Subset

from custom_model import CustomNeuralNet

SEED = 42
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)

if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)

def tokenize(sentence):
    return re.findall(r"\b\w+\b", sentence.lower())

PAD_TOKEN = "<PAD>"
UNK_TOKEN = "<UNK>"

def build_vocab(intents, min_freq=1):
    counter = Counter()
    for intent in intents["intents"]:
        for pattern in intent["patterns"]:
            tokens = tokenize(pattern)
            counter.update(tokens)
    vocab = {PAD_TOKEN: 0, UNK_TOKEN: 1}
    for word, freq in sorted(counter.items()):
        if freq >= min_freq:
            vocab[word] = len(vocab)
    return vocab

def encode_tokens(tokens, vocab):
    return [vocab.get(token, vocab[UNK_TOKEN]) for token in tokens]

class ChatDataset(Dataset):
    def __init__(self, sequences, labels):
        self.sequences = sequences
        self.labels = labels
    def __getitem__(self, index):
        return self.sequences[index], self.labels[index]
    def __len__(self):
        return len(self.sequences)

def collate_batch(batch, pad_idx=0):
    sequences, labels = zip(*batch)
    max_len = max(len(seq) for seq in sequences)
    padded_sequences = []
    for seq in sequences:
        padded = seq + [pad_idx] * (max_len - len(seq))
        padded_sequences.append(padded)
    x = torch.tensor(padded_sequences, dtype=torch.long)
    y = torch.tensor(labels, dtype=torch.long)
    return x, y

def load_and_prepare_data(intents_path="intents.json"):
    print(f"Loading {intents_path}...")
    with open(intents_path, "r", encoding="utf-8") as f:
        intents = json.load(f)
    vocab = build_vocab(intents)
    tags = sorted(set(intent["tag"] for intent in intents["intents"]))
    sequences = []
    labels = []
    for intent in intents["intents"]:
        tag = intent["tag"]
        tag_idx = tags.index(tag)
        for pattern in intent["patterns"]:
            tokens = tokenize(pattern)
            seq = encode_tokens(tokens, vocab)
            if len(seq) == 0:
                seq = [vocab[UNK_TOKEN]]
            sequences.append(seq)
            labels.append(tag_idx)
    return sequences, labels, vocab, tags

def stratified_train_val_split(labels, validation_ratio=0.2, seed=42):
    random.seed(seed)
    label_to_indices = {}
    for idx, label in enumerate(labels):
        label_to_indices.setdefault(label, []).append(idx)
    train_indices = []
    val_indices = []
    for label, indices in label_to_indices.items():
        random.shuffle(indices)
        if len(indices) <= 2:
            train_indices.extend(indices)
            continue
        val_count = max(1, int(len(indices) * validation_ratio))
        val_indices.extend(indices[:val_count])
        train_indices.extend(indices[val_count:])
    random.shuffle(train_indices)
    random.shuffle(val_indices)
    return train_indices, val_indices

def compute_class_weights(y_data, num_classes, device):
    counts = Counter(y_data)
    total_samples = len(y_data)
    weights = []
    for class_idx in range(num_classes):
        class_count = counts.get(class_idx, 1)
        weight = total_samples / (num_classes * class_count)
        weights.append(weight)
    return torch.tensor(weights, dtype=torch.float32, device=device)

def evaluate(model, dataloader, criterion, device):
    model.eval()
    total_loss = 0.0
    correct = 0
    total = 0
    with torch.no_grad():
        for x, y in dataloader:
            x = x.to(device)
            y = y.to(device)
            outputs = model(x)
            loss = criterion(outputs, y)
            total_loss += loss.item()
            _, predicted = torch.max(outputs, dim=1)
            total += y.size(0)
            correct += (predicted == y).sum().item()
    avg_loss = total_loss / len(dataloader) if len(dataloader) > 0 else 0.0
    accuracy = (correct / total) * 100 if total > 0 else 0.0
    return avg_loss, accuracy

def evaluate_per_class(model, dataloader, tags, device):
    model.eval()
    class_correct = {tag: 0 for tag in tags}
    class_total = {tag: 0 for tag in tags}
    with torch.no_grad():
        for x, y in dataloader:
            x = x.to(device)
            y = y.to(device)
            outputs = model(x)
            _, predicted = torch.max(outputs, dim=1)
            for true_label, pred_label in zip(y.tolist(), predicted.tolist()):
                tag = tags[true_label]
                class_total[tag] += 1
                if true_label == pred_label:
                    class_correct[tag] += 1
    print("\n📊 Per-Class Accuracy:")
    for tag in tags:
        total = class_total[tag]
        correct = class_correct[tag]
        acc = (correct / total * 100) if total > 0 else 0.0
        print(f"{tag:<35} {correct:>7} {total:>6} {acc:>6.1f}%")

def train_model():
    print("🚀 Initializing Eunoia FYP BiLSTM Training Pipeline...")
    sequences, labels, vocab, tags = load_and_prepare_data("intents.json")
    num_epochs = 120
    batch_size = 16
    learning_rate = 0.001
    embedding_dim = 128
    hidden_size = 128
    num_layers = 2
    dropout = 0.35
    validation_ratio = 0.2
    early_stopping_patience = 20
    min_delta = 0.005
    vocab_size = len(vocab)
    output_size = len(tags)
    max_seq_len = max(len(seq) for seq in sequences)
    dataset = ChatDataset(sequences, labels)
    train_indices, val_indices = stratified_train_val_split(labels, validation_ratio=validation_ratio, seed=SEED)
    train_dataset = Subset(dataset, train_indices)
    val_dataset = Subset(dataset, val_indices)
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, collate_fn=lambda batch: collate_batch(batch, pad_idx=vocab[PAD_TOKEN]))
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, collate_fn=lambda batch: collate_batch(batch, pad_idx=vocab[PAD_TOKEN]))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = CustomNeuralNet(vocab_size=vocab_size, embedding_dim=embedding_dim, hidden_size=hidden_size, num_classes=output_size, pad_idx=vocab[PAD_TOKEN], num_layers=num_layers, dropout=dropout).to(device)
    train_labels = [labels[i] for i in train_indices]
    class_weights = compute_class_weights(train_labels, output_size, device)
    criterion = nn.CrossEntropyLoss(weight=class_weights, label_smoothing=0.1)
    optimizer = torch.optim.AdamW(model.parameters(), lr=learning_rate, weight_decay=5e-4)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=5)
    best_val_acc = 0.0
    best_val_loss = float("inf")
    best_model_data = None
    patience_counter = 0
    history = {"train_loss": [], "train_acc": [], "val_loss": [], "val_acc": []}
    for epoch in range(num_epochs):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        for x, y in train_loader:
            x = x.to(device)
            y = y.to(device)
            outputs = model(x)
            loss = criterion(outputs, y)
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()
            running_loss += loss.item()
            _, predicted = torch.max(outputs, dim=1)
            total += y.size(0)
            correct += (predicted == y).sum().item()
        train_loss = running_loss / len(train_loader) if len(train_loader) > 0 else 0.0
        train_acc = (correct / total) * 100 if total > 0 else 0.0
        val_loss, val_acc = evaluate(model, val_loader, criterion, device)
        scheduler.step(val_acc)
        history["train_loss"].append(train_loss)
        history["train_acc"].append(train_acc)
        history["val_loss"].append(val_loss)
        history["val_acc"].append(val_acc)
        improved = False
        if val_acc > best_val_acc + min_delta:
            best_val_acc = val_acc
            best_val_loss = val_loss
            patience_counter = 0
            improved = True
        elif abs(val_acc - best_val_acc) <= min_delta and val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            improved = True
        else:
            patience_counter += 1
        if improved:
            best_model_data = {
                "model_state": {k: v.detach().cpu().clone() for k, v in model.state_dict().items()},
                "vocab": vocab, "tags": tags, "vocab_size": vocab_size, "embedding_dim": embedding_dim,
                "hidden_size": hidden_size, "output_size": output_size, "num_layers": num_layers,
                "dropout": dropout, "pad_idx": vocab[PAD_TOKEN], "unk_idx": vocab[UNK_TOKEN],
                "max_seq_len": max_seq_len, "seed": SEED, "num_epochs": num_epochs,
                "learning_rate": learning_rate, "batch_size": batch_size, "validation_ratio": validation_ratio,
                "best_val_acc": best_val_acc, "best_val_loss": best_val_loss,
                "class_weights": class_weights.detach().cpu().tolist(), "history": history
            }
        if patience_counter >= early_stopping_patience:
            break
    if best_model_data is None:
        best_model_data = {
            "model_state": {k: v.detach().cpu().clone() for k, v in model.state_dict().items()},
            "vocab": vocab, "tags": tags, "vocab_size": vocab_size, "embedding_dim": embedding_dim,
            "hidden_size": hidden_size, "output_size": output_size, "num_layers": num_layers,
            "dropout": dropout, "pad_idx": vocab[PAD_TOKEN], "unk_idx": vocab[UNK_TOKEN],
            "max_seq_len": max_seq_len, "seed": SEED, "num_epochs": num_epochs,
            "learning_rate": learning_rate, "batch_size": batch_size, "validation_ratio": validation_ratio,
            "best_val_acc": best_val_acc, "best_val_loss": best_val_loss,
            "class_weights": class_weights.detach().cpu().tolist(), "history": history
        }
    model.load_state_dict(best_model_data["model_state"])
    model.to(device)
    evaluate_per_class(model, val_loader, tags, device)
    torch.save(best_model_data, "trained_model_data.pth")
    print("Best model saved to trained_model_data.pth")

if __name__ == "__main__":
    train_model()
