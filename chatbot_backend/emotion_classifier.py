"""
emotion_classifier.py
---------------------
Loads emotion_model_data.pth and exposes a predict() method.
Called by app.py to serve the /predict_emotion endpoint.
"""

import os
import re
import sys
import warnings

import torch

from custom_model import CustomNeuralNet

warnings.filterwarnings("ignore")


# ── Label → display title + summary paragraph ─────────────────
EMOTION_META = {
    "joy": {
        "title":   "Joyful & Bright",
        "summary": (
            "Your writing radiates a beautiful warmth and positivity. "
            "Whatever sparked this happiness today — big or small — hold onto it. "
            "You deserve every bit of this joy."
        ),
    },
    "calm": {
        "title":   "Reflective & Calm",
        "summary": (
            "There is a steady, peaceful energy flowing through your words today. "
            "You seem grounded and at ease — a clear sign that you are taking good care of your inner world."
        ),
    },
    "sadness": {
        "title":   "Pensive & Melancholic",
        "summary": (
            "It sounds like you are carrying some weight today. "
            "Sadness is a valid and important emotion — sitting with it and expressing it here is a healthy step. "
            "Be gentle with yourself."
        ),
    },
    "anxiety": {
        "title":   "Tense & Overwhelmed",
        "summary": (
            "Your entry reflects a mind under pressure, with worries pulling you in different directions. "
            "Acknowledging this stress is important. Try to take one small step at a time."
        ),
    },
    "anger": {
        "title":   "Frustrated & Unsettled",
        "summary": (
            "Your words carry a strong sense of frustration today. "
            "It is okay to feel angry — what matters is giving yourself space to process it without letting it define you."
        ),
    },
    "neutral": {
        "title":   "Steady & Balanced",
        "summary": (
            "Your entry feels grounded and even-keeled today. "
            "Not every day needs to be extraordinary — there is real value in stable, ordinary days like this one."
        ),
    },
}

# ── Blended titles for mixed emotions ─────────────────────────
def get_mixed_title(primary: str, secondary: str) -> str:
    pair = tuple(sorted([primary, secondary]))
    blends = {
        ("calm", "joy"): "Peaceful Happiness",
        ("anxiety", "joy"): "Nervous Excitement",
        ("joy", "sadness"): "Bittersweet Reflections",
        ("anger", "joy"): "Conflicted Emotions",
        ("calm", "sadness"): "Pensive Melancholy",
        ("anxiety", "calm"): "Quiet Concern",
        ("anger", "calm"): "Controlled Frustration",
        ("anxiety", "sadness"): "Heavy & Anxious",
        ("anger", "sadness"): "Bitter & Hurt",
        ("anger", "anxiety"): "Tense & Frustrated",
    }
    return blends.get(pair, "Mixed Reflections")


# ── Crisis override ─────────────────────────────────────────────
CRISIS_KEYWORDS = [
    "suicide", "kill myself", "self harm", "end it all",
    "i want to die", "i don't want to live", "hurt myself",
    "want to end my life", "give up on life", "no reason to live",
]


class EmotionClassifier:
    def __init__(self, model_path: str = "emotion_model_data.pth"):
        print("[INFO] Loading Emotion Classifier...")

        if not os.path.exists(model_path):
            print(f"[ERROR] {model_path} not found! Run emotion_train.py first.")
            sys.exit(1)

        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        data = torch.load(model_path, map_location=self.device, weights_only=False)

        self.vocab       = data["vocab"]
        self.tags        = data["tags"]
        self.vocab_size  = data["vocab_size"]
        self.embed_dim   = data["embedding_dim"]
        self.hidden_size = data["hidden_size"]
        self.num_classes = data["output_size"]
        self.num_layers  = data["num_layers"]
        self.dropout     = data["dropout"]
        self.pad_idx     = data["pad_idx"]
        self.unk_idx     = data["unk_idx"]
        self.max_seq_len = data["max_seq_len"]

        self.model = CustomNeuralNet(
            vocab_size=self.vocab_size,
            embedding_dim=self.embed_dim,
            hidden_size=self.hidden_size,
            num_classes=self.num_classes,
            pad_idx=self.pad_idx,
            num_layers=self.num_layers,
            dropout=self.dropout,
        ).to(self.device)

        self.model.load_state_dict(data["model_state"])
        self.model.eval()
        print(f"[OK] Emotion Classifier ready | Classes: {self.tags}")

    # ── Preprocessing ─────────────────────────────────────────
    def _preprocess(self, text: str):
        clean = text.lower().strip()
        if len(clean) > 500:
            clean = clean[:500]
        return clean

    def _tokenize(self, text: str):
        return re.findall(r"\b\w+\b", self._preprocess(text))

    def _encode(self, tokens):
        seq = [self.vocab.get(t, self.unk_idx) for t in tokens]
        if not seq:
            seq = [self.unk_idx]
        if len(seq) < self.max_seq_len:
            seq = seq + [self.pad_idx] * (self.max_seq_len - len(seq))
        else:
            seq = seq[: self.max_seq_len]
        return seq

    # ── Crisis check ──────────────────────────────────────────
    def _is_crisis(self, text: str) -> bool:
        lower = text.lower()
        return any(kw in lower for kw in CRISIS_KEYWORDS)

    # ── Public predict ────────────────────────────────────────
    def predict(self, text: str) -> dict:
        """
        Returns:
            {
                "emotion":           str,   # e.g. "joy"
                "secondary_emotion": str,   # e.g. "anxiety" or None
                "title":             str,   # display mood title
                "confidence":        float, # 0.0–1.0
                "summary":           str,   # AI insight paragraph
                "is_crisis":         bool
            }
        """
        # ── Crisis override ──────────────────────────────────
        if self._is_crisis(text):
            return {
                "emotion":           "crisis",
                "secondary_emotion": None,
                "title":             "Urgent: High Distress",
                "confidence":        1.0,
                "summary":           (
                    "We noticed some very heavy words in your reflection. "
                    "Your safety is the priority. "
                    "Please consider reaching out to one of your trusted contacts or a professional right away."
                ),
                "is_crisis":         True,
            }

        # ── Model inference ──────────────────────────────────
        tokens  = self._tokenize(text)
        encoded = self._encode(tokens)
        x = torch.tensor([encoded], dtype=torch.long).to(self.device)

        with torch.no_grad():
            logits = self.model(x)               # [1, num_classes]
            probs  = torch.softmax(logits, dim=1) # [1, num_classes]

        # ── Mixed emotion keyword boost ───────────────────────
        lower_text = text.lower()
        has_joy = any(w in lower_text for w in ["happy", "glad", "excit", "relief", "reliev", "success", "reward", "proud", "great", "wonderful"])
        has_calm = any(w in lower_text for w in ["calm", "peace", "relax", "quiet", "still", "breathe", "slow", "meditat"])
        has_anx = any(w in lower_text for w in ["nervous", "stress", "anxio", "worry", "fear", "panic", "scared", "terrified", "dread"])
        has_sad = any(w in lower_text for w in ["sad", "lonely", "depress", "empty", "cry", "grief", "mourn", "hurt"])
        has_ang = any(w in lower_text for w in ["angry", "frustrat", "annoy", "mad", "furious", "irritat", "resent"])

        tag_to_idx = {tag: i for i, tag in enumerate(self.tags)}
        
        mixed_pairs = [
            ("joy", "anxiety", has_joy and has_anx),
            ("joy", "sadness", has_joy and has_sad),
            ("calm", "joy", has_calm and has_joy),
            ("calm", "sadness", has_calm and has_sad),
            ("calm", "anxiety", has_calm and has_anx),
            ("anger", "anxiety", has_ang and has_anx),
            ("anger", "sadness", has_ang and has_sad),
        ]

        boost_threshold = 0.28
        for em1, em2, cond in mixed_pairs:
            if cond:
                idx1 = tag_to_idx.get(em1)
                idx2 = tag_to_idx.get(em2)
                if idx1 is not None and idx2 is not None:
                    p1 = probs[0][idx1].item()
                    p2 = probs[0][idx2].item()
                    
                    # Force them to be the top 2 by penalising everything else
                    for i in range(len(probs[0])):
                        if i != idx1 and i != idx2:
                            probs[0][i] *= 0.1
                            
                    # Ensure both have a solid base probability
                    if probs[0][idx1] < 0.4: probs[0][idx1] = 0.4
                    if probs[0][idx2] < 0.4: probs[0][idx2] = 0.4
                        
                    # Re-normalize
                    total = probs[0].sum().item()
                    probs[0] = probs[0] / total
                    break

        # Extract top 2 predictions
        top_probs, top_indices = torch.topk(probs, k=2, dim=1)

        primary_prob = top_probs[0][0].item()
        primary_idx = top_indices[0][0].item()
        primary_emotion = self.tags[primary_idx]

        secondary_prob = top_probs[0][1].item()
        secondary_idx = top_indices[0][1].item()
        secondary_emotion = self.tags[secondary_idx]

        meta = EMOTION_META.get(primary_emotion, {
            "title":   "Reflection Captured",
            "summary": "Your thoughts have been logged securely.",
        })

        if secondary_prob >= 0.25 and secondary_emotion != primary_emotion:
            # We have a valid mixed emotion!
            title = get_mixed_title(primary_emotion, secondary_emotion)
            
            sec_display = {
                "joy": "happiness",
                "calm": "calmness",
                "sadness": "melancholy",
                "anxiety": "worry or tension",
                "anger": "frustration",
                "neutral": "neutrality"
            }.get(secondary_emotion, secondary_emotion)

            summary = (
                f"You are navigating a blend of emotions today. "
                f"{meta['summary']} "
                f"Alongside this, your reflections carry underlying tones of {sec_display}."
            )
            return {
                "emotion":           primary_emotion,
                "secondary_emotion": secondary_emotion,
                "title":             title,
                "confidence":        round(primary_prob, 4),
                "summary":           summary,
                "is_crisis":         False,
            }
        else:
            return {
                "emotion":           primary_emotion,
                "secondary_emotion": None,
                "title":             meta["title"],
                "confidence":        round(primary_prob, 4),
                "summary":           meta["summary"],
                "is_crisis":         False,
            }
