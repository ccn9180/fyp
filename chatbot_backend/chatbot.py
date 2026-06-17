import os
import re
import json
import random
import warnings
from dataclasses import dataclass, field
from typing import Optional, Tuple, Dict, List

import torch

from custom_model import CustomNeuralNet
from topic_extractor import TopicExtractor
from nlg_engine import ComponentNLGEngine
from firebase_manager import FirebaseManager
from stage_engine import ConversationStageEngine

warnings.filterwarnings("ignore")


# ============================================================
# CONTEXT TRACKER
# ============================================================
@dataclass
class Turn:
    user_text: str
    detected_emotion: str
    detected_topic: str
    applied_strategy: str
    bot_response: str

@dataclass
class UserContextTracker:
    topic: Optional[str] = None
    turn_count: int = 0
    previous_response: Optional[str] = None
    consecutive_questions: int = 0
    is_chronic: bool = False
    grounding_completed_recently: bool = False

    last_strategy: Optional[str] = None
    last_question_type: Optional[str] = None

    awaiting_grounding_items: bool = False
    awaiting_exercise_feedback: bool = False
    awaiting_choice_response: bool = False
    awaiting_binary_progress_answer: bool = False
    awaiting_open_emotion_detail: bool = False

    last_detected_mode: Optional[str] = None
    last_body_symptom: Optional[str] = None

    # ── NEW: richer session memory ──────────────────────────
    no_relief_count: int = 0          # how many times no_relief in a row
    coping_steps_tried: int = 0       # total grounding/breath steps offered
    validated_this_turn: bool = False  # prevent double-validation
    emotion_history: List[str] = field(default_factory=list)   # rolling last 5 intents
    strategy_history: List[str] = field(default_factory=list)  # rolling last 5 strategies
    last_coping_step: Optional[str] = None  # avoid repeating same step type
    current_entity: Optional[str] = None   # extracted specific topic entity (e.g. "final year project")
    history: List[Turn] = field(default_factory=list) # richer session history

    # ── conversation stage + situation/event memory ─────────
    conversation_stage: str = "validation"  # validation/reflection/exploration/encouragement/problem_solving
    stage_turns: int = 0                    # turns spent in the current stage
    current_situation: Optional[str] = None # explicit situation slot (mirrors topic/topic category)
    current_event: Optional[str] = None     # lightweight event phrase, e.g. "revise your proposal"
    current_event_category: Optional[str] = None  # technical/deadline/supervisor_feedback/relationship/family/academic
    current_progress_detail: Optional[str] = None  # e.g. "completed 30 modules, 10 left"
    technical_failure_evidence: bool = False  # bug/debug/error/crash actually mentioned (Assumption Safety Layer)
    recent_component_phrases: List[str] = field(default_factory=list)  # ComponentNLGEngine anti-repetition
    last_response_mode: Optional[str] = None  # last question-ratio mode used (avoid back-to-back repeats)
    recent_observation_categories: List[str] = field(default_factory=list)  # avoid same "flavor" twice in a row

    # ── entity-mention fade: avoid repeating the literal entity every turn ──
    entity_mention_streak: int = 0
    last_literal_entity: Optional[str] = None
    last_entity_alias: Optional[str] = None

    # ── pending action / awaiting confirmation: when the bot offers something
    # actionable ("would you be open to trying a calming step?"), this tracks
    # what was offered so a plain "yes" executes it instead of being treated
    # as small talk. ──
    pending_action: Optional[str] = None
    awaiting_confirmation: bool = False


    # New Unified Control & Emotion Fields
    stop_topic_flow: bool = False
    explicit_emotion_detected: bool = False
    topic_decay_score: int = 0
    last_bot_question: dict = field(default_factory=lambda: {"text": "", "intent_slot": "", "topic": "", "answered": False})
    recent_bot_responses: List[dict] = field(default_factory=list)

    # ── Answer Interpretation Layer: tracks the bot's previous turn (question
    # OR statement) so a short "yes"/"no"/"both" reply can be interpreted
    # relative to it, instead of being treated as a standalone message. ──
    last_bot_turn: dict = field(default_factory=lambda: {
        "text": "", "kind": "statement", "option_a": None, "option_b": None, "answered": True,
        "topic": None, "entity": None, "intent": None,
    })

    DISTRESS_WEIGHT = {
        "emergency_crisis": 10, "physical_panic": 8, "repeated_no_relief": 7,
        "chronic_distress": 6, "strong_negative_mood": 5, "sadness": 3,
        "negative_checkin": 2, "neutral_checkin": 0, "slight_relief": -1,
    }

    def is_sustained_distress(self) -> bool:
        negative = {"sadness", "emptiness", "guilt_shame", "looping_thoughts",
                    "no_relief", "repeated_no_relief", "chronic_distress", "strong_negative_mood"}
        return sum(1 for e in self.emotion_history if e in negative) >= 3

    def is_oscillating(self) -> bool:
        if len(self.emotion_history) < 4:
            return False
        return len(set(self.emotion_history[-4:])) >= 3

    @property
    def distress_level(self) -> int:
        if not self.emotion_history:
            return 0
        weights = [self.DISTRESS_WEIGHT.get(e, 1) for e in self.emotion_history]
        return sum(weights) // max(1, len(weights))

    def reset_for_new_session(self):
        """Called when a greeting is detected mid-conversation."""
        self.topic = None
        self.turn_count = 0
        self.previous_response = None
        self.consecutive_questions = 0
        self.is_chronic = False
        self.grounding_completed_recently = False
        self.last_strategy = None
        self.last_question_type = None
        self.awaiting_grounding_items = False
        self.awaiting_exercise_feedback = False
        self.awaiting_choice_response = False
        self.awaiting_binary_progress_answer = False
        self.awaiting_open_emotion_detail = False
        self.last_detected_mode = None
        self.last_body_symptom = None
        self.no_relief_count = 0
        self.coping_steps_tried = 0
        self.validated_this_turn = False
        self.emotion_history = []
        self.strategy_history = []
        self.last_coping_step = None
        self.current_entity = None
        self.history = []

        self.stop_topic_flow = False
        self.explicit_emotion_detected = False
        self.topic_decay_score = 0
        self.last_bot_question = {"text": "", "intent_slot": "", "topic": "", "answered": False}
        self.recent_bot_responses = []

        self.conversation_stage = "validation"
        self.stage_turns = 0
        self.current_situation = None
        self.current_event = None
        self.current_event_category = None
        self.current_progress_detail = None
        self.technical_failure_evidence = False
        self.last_bot_turn = {
            "text": "", "kind": "statement", "option_a": None, "option_b": None,
            "answered": True, "topic": None, "entity": None, "intent": None,
        }
        self.recent_component_phrases = []
        self.last_response_mode = None
        self.recent_observation_categories = []

        self.entity_mention_streak = 0
        self.last_literal_entity = None
        self.last_entity_alias = None

        self.pending_action = None
        self.awaiting_confirmation = False

    def update(
        self,
        user_text: str,
        intent: str,
        topic: str,
        bot_text: str,
        strategy: Optional[str],
        question_type: Optional[str],
    ):
        self.turn_count += 1
        self.last_strategy = strategy
        self.last_question_type = question_type
        self.validated_this_turn = False
        
        # Add to Turn history
        self.history.append(Turn(
            user_text=user_text,
            detected_emotion=intent,
            detected_topic=topic or "general",
            applied_strategy=strategy or "general",
            bot_response=bot_text
        ))
        
        # Keep last 10 turns
        if len(self.history) > 10:
            self.history.pop(0)

        if topic and topic != "general":
            self.topic = topic

        if intent == "chronic_distress":
            self.is_chronic = True

        # ── track no-relief streak ──────────────────────────
        if intent == "no_relief":
            self.no_relief_count += 1
        elif intent in ["slight_relief", "mixed_relief", "grounding_completed"]:
            self.no_relief_count = 0

        # ── track coping steps offered ──────────────────────
        if strategy in [
            "deliver_coping_step", "next_calming_step",
            "guided_breath_step", "body_symptom_action",
        ]:
            self.coping_steps_tried += 1
            self.last_coping_step = strategy

        # ── reset awaiting flags ────────────────────────────
        self.awaiting_grounding_items = False
        self.awaiting_exercise_feedback = False
        self.awaiting_choice_response = False
        self.awaiting_binary_progress_answer = False
        self.awaiting_open_emotion_detail = False

        if question_type == "grounding_items":
            self.awaiting_grounding_items = True
        elif question_type == "exercise_feedback":
            self.awaiting_exercise_feedback = True
        elif question_type == "choice":
            self.awaiting_choice_response = True
        elif question_type == "binary_progress":
            self.awaiting_binary_progress_answer = True
        elif question_type in ["open_emotion", "clarify"]:
            self.awaiting_open_emotion_detail = True

        if intent == "grounding_completed":
            self.grounding_completed_recently = True
        elif intent in ["session_close", "greeting", "emergency_crisis"]:
            self.grounding_completed_recently = False

        if question_type == "body":
            self.last_detected_mode = "body"
        elif question_type == "body_vs_thoughts" and self.last_detected_mode is None:
            self.last_detected_mode = "mixed"

        self.consecutive_questions = (
            self.consecutive_questions + 1 if "?" in bot_text else 0
        )
        self.previous_response = bot_text

        # ── rolling emotion / strategy history ──────────────
        self.emotion_history.append(intent)
        if len(self.emotion_history) > 5:
            self.emotion_history.pop(0)

        if strategy:
            self.strategy_history.append(strategy)
            if len(self.strategy_history) > 5:
                self.strategy_history.pop(0)


# ============================================================
# NLU PIPELINE
# ============================================================
class AdvancedNLUPipeline:
    def __init__(self):
        print("[SYS] Loading Eunoia Deep Learning Classifier...")
        import sys

        self.topic_extractor = TopicExtractor()

        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

        if not os.path.exists("trained_model_data.pth"):
            print("❌ ERROR: trained_model_data.pth not found! Run custom_train.py first.")
            sys.exit(1)

        data = torch.load("trained_model_data.pth", map_location=self.device, weights_only=False)

        self.vocab = data["vocab"]
        self.tags = data["tags"]
        self.vocab_size = data["vocab_size"]
        self.embedding_dim = data["embedding_dim"]
        self.hidden_size = data["hidden_size"]
        self.output_size = data["output_size"]
        self.num_layers = data["num_layers"]
        self.dropout = data["dropout"]
        self.pad_idx = data["pad_idx"]
        self.unk_idx = data["unk_idx"]
        self.max_seq_len = data["max_seq_len"]
        self.model_state = data["model_state"]

        self.model = CustomNeuralNet(
            vocab_size=self.vocab_size,
            embedding_dim=self.embedding_dim,
            hidden_size=self.hidden_size,
            num_classes=self.output_size,
            pad_idx=self.pad_idx,
            num_layers=self.num_layers,
            dropout=self.dropout,
        ).to(self.device)

        self.model.load_state_dict(self.model_state)
        self.model.eval()

    TOPIC_ENTITIES = {
        "fyp": "final year project",
        "final year project": "final year project",
        "thesis": "thesis",
        "internship": "internship",
        "boyfriend": "boyfriend",
        "girlfriend": "girlfriend",
        "mother": "mother",
        "father": "father",
        "mom": "mother",
        "dad": "father",
    }

    def extract_entity(self, text: str) -> Optional[str]:
        c = self.normalize_text(text)
        for kw, label in self.TOPIC_ENTITIES.items():
            if kw in c:
                return label
        return None

    # ── text normalisation ───────────────────────────────────
    def normalize_text(self, text: str) -> str:
        clean = text.lower().strip()

        # hard cap on input length to guard inference performance
        if len(clean) > 500:
            clean = clean[:500]

        # contractions / missing apostrophes
        contractions = {
            "cant": "can't", "dont": "don't", "didnt": "didn't",
            "doesnt": "doesn't", "wont": "won't", "wouldnt": "wouldn't",
            "couldnt": "couldn't", "shouldnt": "shouldn't", "isnt": "isn't",
            "arent": "aren't", "wasnt": "wasn't", "werent": "weren't",
            "havent": "haven't", "hasnt": "hasn't", "hadnt": "hadn't",
            "im": "i'm", "ive": "i've", "ill": "i'll", "id": "i'd",
        }
        for wrong, right in contractions.items():
            # only replace as whole words to avoid substring corruption
            clean = re.sub(rf'\b{wrong}\b', right, clean)

        # typo corrections
        typos = {
            "dnt": "don't", "knoe": "know", "knoew": "know",
            "waive": "go away", "relif": "relief", "slighter": "slightly lighter",
            "anixety": "anxiety", "strees": "stress", "depresed": "depressed",
            "feld": "felt", "scare ": "scared ",
        }
        for wrong, right in typos.items():
            clean = clean.replace(wrong, right)

        # slang / shorthand — all word-boundary safe
        clean = re.sub(r'\bidk\b', "i don't know", clean)
        clean = re.sub(r'\btq\b', "thank you", clean)
        clean = re.sub(r'\bthx\b', "thank you", clean)
        clean = re.sub(r'\bpls\b', "please", clean)
        clean = re.sub(r'\bu\b', "you", clean)
        clean = re.sub(r'\bur\b', "your", clean)
        clean = re.sub(r'\br\b', "are", clean)
        clean = re.sub(r'\bkinda\b', "kind of", clean)
        clean = re.sub(r'\bgonna\b', "going to", clean)
        clean = re.sub(r'\bbf\b', "boyfriend", clean)
        clean = re.sub(r'\bgf\b', "girlfriend", clean)
        clean = re.sub(r'\bbtw\b', "by the way", clean)
        clean = re.sub(r'\bomg\b', "oh my god", clean)
        clean = re.sub(r'\bngl\b', "not gonna lie", clean)

        # feelings shorthand
        clean = clean.replace("feel like shit", "feel terrible")
        clean = clean.replace("bad as fuck", "very bad")
        clean = clean.replace("fucked up", "very overwhelmed")
        clean = clean.replace("dump me", "leave me")

        # leading conversational fillers (ermm/um/uh/hmm/well/actually/maybe) --
        # only stripped if something meaningful remains, so a standalone "maybe"
        # answer (a real signal elsewhere) is left intact.
        filler_match = re.match(r'^(?:(?:erm+|umm?|uhh?|hmm+|well|actually|maybe)[\s,.]*)+', clean)
        if filler_match:
            stripped = clean[filler_match.end():].strip()
            if stripped:
                clean = stripped

        # remove repeated spaces
        clean = re.sub(r"\s+", " ", clean).strip()
        return clean

    def tokenize(self, sentence: str) -> List[str]:
        sentence = self.normalize_text(sentence)
        return re.findall(r"\b\w+\b", sentence)

    def encode_sequence(self, tokenized_sentence: List[str]) -> List[int]:
        seq = [self.vocab.get(token, self.unk_idx) for token in tokenized_sentence]
        if not seq:
            seq = [self.unk_idx]
        if len(seq) < self.max_seq_len:
            seq = seq + [self.pad_idx] * (self.max_seq_len - len(seq))
        else:
            seq = seq[: self.max_seq_len]
        return seq

    # ── rule-based fast-path ─────────────────────────────────
    def extract_direct_rules(self, text: str) -> Optional[str]:
        clean = self.normalize_text(text)

        # ── crisis (always first) ────────────────────────────
        crisis_kws = [
            "suicide", "kill myself", "self harm", "end it all",
            "i want to die", "i don't want to live", "i dont want to live",
            "hurt myself", "i want to disappear forever",
            "want to end my life", "i'm going to hurt myself",
        ]
        if any(kw in clean for kw in crisis_kws):
            return "emergency_crisis"

        # ── session close ────────────────────────────────────
        close_phrases = [
            "bye", "goodbye", "i have to go", "see you later",
            "that's enough for today", "thats enough for today",
            "i'm done", "im done", "thank you bye", "quit", "exit",
            "i want to stop now", "let's stop here", "lets stop here",
            "i need to leave", "talk later", "see you", "i'm leaving", "im leaving",
        ]
        if clean in close_phrases:
            return "session_close"

        # ── greeting ─────────────────────────────────────────
        greeting_phrases = [
            "hi", "hello", "hey", "good morning", "good afternoon",
            "good evening", "yo", "hi there", "hello there", "greetings",
            "hey there", "morning", "evening", "hii", "heloo", "helo", "helloo",
        ]
        greeting_kws = [
            "how are you", "how are you today", "what's up", "whats up",
            "how's it going", "hows it going", "how are things",
            "how have you been", "how do you do"
        ]
        
        if clean in greeting_phrases or any(kw in clean for kw in greeting_kws):
            return "greeting"
            
        # If it starts with a greeting and is relatively short, consider it a greeting
        if len(clean.split()) <= 6 and any(clean.startswith(p + " ") for p in greeting_phrases):
            return "greeting"

        # ── gratitude ────────────────────────────────────────
        gratitude_phrases = [
            "thanks", "thank you", "thanks a lot", "thankyou", "thx", "ty",
            "okay thank you", "ok thank you", "thank you so much", "really thanks",
            "appreciate it", "thank you for listening", "that helped",
        ]
        if clean in gratitude_phrases:
            return "gratitude"

        # ── positive check-in ────────────────────────────────
        positive_checkin_kws = [
            "i feel good", "i felt good", "feeling good", "i'm feeling good",
            "i feel okay", "i'm okay", "doing good", "doing okay",
            "i feel better", "i feel fine", "i'm fine",
            "today is okay", "today is good", "not bad", "quite good",
        ]
        if any(kw in clean for kw in positive_checkin_kws):
            return "neutral_checkin"

        # ── negative check-in ────────────────────────────────
        negative_checkin_kws = [
            "not really good", "not good", "not okay", "not ok", "not great",
            "not so good", "not too good", "not feeling good", "not feeling well",
            "i feel bad", "i felt bad", "feeling bad", "i'm feeling bad",
            "i feel terrible", "i feel awful", "i feel horrible",
            "i feel low", "i feel down", "feeling down",
            "today bad", "today is bad", "bad day", "rough day", "hard day", "tough day",
            "doing bad", "quite bad", "pretty bad", "could be better",
            "not the best", "not myself", "not myself today",
            "i feel off", "feeling off", "i feel weird",
            "i feel heavy", "things feel heavy",
        ]
        if any(kw in clean for kw in negative_checkin_kws):
            return "negative_checkin"

        # ── strong negative ───────────────────────────────────
        strong_negative_kws = [
            "feel like shit", "feeling like shit", "shit day",
            "fucking bad", "damn bad", "really bad", "so bad", "very bad",
            "terrible", "horrible", "awful", "not okay", "i'm not okay", "im not okay",
        ]
        if any(kw in clean for kw in strong_negative_kws):
            return "strong_negative_mood"

        # ── anger ────────────────────────────────────────────
        anger_kws = [
            "mad", "angry", "so angry", "very angry", "pissed", "pissed off",
            "annoyed", "frustrated", "irritated", "fed up",
            "i am mad", "i'm mad", "i feel mad", "i feel angry", "i feel frustrated",
            "i'm furious", "i'm so frustrated",
        ]
        if clean in anger_kws or any(kw in clean for kw in anger_kws):
            return "anger_frustration"

        # ── sadness ──────────────────────────────────────────
        sadness_kws = [
            "sad", "i feel sad", "i'm sad", "feeling down", "i feel down",
            "i feel low", "i feel hurt", "i feel like crying", "i cried today",
            "i'm heartbroken", "i feel heartbroken",
        ]
        if clean in sadness_kws or any(kw in clean for kw in sadness_kws):
            return "sadness"

        # ── guilt / shame ─────────────────────────────────────
        guilt_kws = [
            "i feel guilty", "i feel ashamed", "i blame myself", "it's my fault",
            "i hate myself for this", "i regret what i did", "i messed up",
            "i feel like i failed everyone", "i let people down",
        ]
        if any(kw in clean for kw in guilt_kws):
            return "guilt_shame"

        # ── emptiness ────────────────────────────────────────
        emptiness_kws = [
            "i feel empty", "nothing feels meaningful", "i feel numb",
            "i don't feel anything", "i feel blank", "i feel hollow",
            "i feel emotionally numb", "i feel like a shell",
        ]
        if any(kw in clean for kw in emptiness_kws):
            return "emptiness"

        # ── confusion ────────────────────────────────────────
        confusion_kws = [
            "confused", "i feel confused", "i don't know what i feel",
            "i dont know what i feel", "my mind is messy", "i feel lost",
            "i cannot explain it", "i don't understand what i feel",
        ]
        if any(kw in clean for kw in confusion_kws):
            return "confusion"

        # ── self-esteem ───────────────────────────────────────
        self_esteem_kws = [
            "i am not good enough", "i feel not good enough",
            "i hate myself", "i feel worthless",
            "i feel useless", "i feel like a failure",
            "i am a failure", "nothing good about me",
            "i'm not smart enough", "i'm not capable",
        ]
        if any(kw in clean for kw in self_esteem_kws):
            return "self_esteem"

        # ── social anxiety ────────────────────────────────────
        social_anxiety_kws = [
            "scared people judge me", "afraid people judge me",
            "i feel awkward around people", "i don't know how to talk to people",
            "social anxiety", "scared to talk to people",
            "i feel nervous around people", "i overthink what people think",
            "i'm scared of being judged",
        ]
        if any(kw in clean for kw in social_anxiety_kws):
            return "social_anxiety"

        # ── friendship ────────────────────────────────────────
        friendship_kws = [
            "friend problem", "friends problem", "my friend ignored me",
            "my friends left me out", "i feel left out",
            "friendship problem", "my friend is mad at me",
            "my friends don't care about me", "i lost my friend",
            "my friend betrayed me",
        ]
        if any(kw in clean for kw in friendship_kws):
            return "friendship_pressure"

        # ── future uncertainty ────────────────────────────────
        future_uncertainty_kws = [
            "i don't know my future", "i'm scared about my future",
            "future feels uncertain", "i don't know what to do in life",
            "i feel lost about my future", "i don't know where my life is going",
            "i have no direction", "i don't know what i want",
        ]
        if any(kw in clean for kw in future_uncertainty_kws):
            return "future_uncertainty"

        # ── looping thoughts ──────────────────────────────────
        looping_kws = [
            "can't leave my head", "cant leave my head", "cannot leave my head",
            "can't get it out of my head", "cant get it out of my head",
            "stuck in my head", "keeps repeating in my head",
            "it won't leave my head", "mind won't stop",
            "my thoughts keep repeating", "cannot stop thinking",
            "can't stop thinking", "it keeps replaying",
            "same thought again and again", "cannot go away from my head",
        ]
        if any(kw in clean for kw in looping_kws):
            return "looping_thoughts"

        # ── overthinking ──────────────────────────────────────
        overthinking_kws = [
            "overthinking", "i keep overthinking", "my mind won't stop",
            "my brain won't stop", "i keep thinking too much",
            "i cannot stop thinking", "i can't stop thinking",
            "my thoughts keep racing", "too many thoughts",
            "i keep replaying everything",
        ]
        if any(kw in clean for kw in overthinking_kws):
            return "overthinking"

        # ── sleep problems ────────────────────────────────────
        sleep_kws = [
            "can't sleep", "cant sleep", "cannot sleep", "hard to sleep",
            "i can't fall asleep", "i cant fall asleep", "i keep waking up",
            "my mind is active at night", "i overthink at night",
            "sleep problem", "my sleep is bad", "insomnia",
            "i wake up at night", "lying awake",
        ]
        if any(kw in clean for kw in sleep_kws):
            return "sleep_problem"

        # ── body better, mind still worried ──────────────────
        body_better_kws = [
            "body better but mind", "physically better but still scared",
            "calmer but still worried", "body calm but mind still",
            "less anxious but still worried", "better but still scared",
            "body feels better but mind still", "physically better but mentally",
        ]
        if any(kw in clean for kw in body_better_kws):
            return "body_better_mind_worry"

        # ── fear of unsolved problem ──────────────────────────
        future_worry_kws = [
            "i scare i can't solve", "i'm scared i can't solve my problem",
            "scared i can't solve", "can't solve my problem",
            "cannot solve my problem", "i worry i can't solve",
            "i cannot fix this", "i can't fix this",
            "i don't know how to fix this",
            "something not perfect", "things not perfect", "not so perfect",
            "something still wrong", "still not right", "still got problem",
            "still have problem", "things feel unresolved",
            "i feel unresolved", "i keep worrying about it",
        ]
        if any(kw in clean for kw in future_worry_kws):
            return "fear_unsolved_problem"

        # ── relationship loss ─────────────────────────────────
        relationship_kws = [
            "broke up", "break up", "breakup", "relationship ended",
            "heartbroken", "heart break", "i miss my ex", "my ex left me",
            "my boyfriend left me", "my girlfriend left me", "we broke up",
            "scared i'm going to break up", "scared we will break up",
            "afraid we will break up", "worried we will break up",
            "scared my boyfriend will leave", "scared my girlfriend will leave",
            "afraid my boyfriend will leave", "afraid my girlfriend will leave",
            "scared he will leave me", "scared she will leave me",
            "afraid he will leave me", "afraid she will leave me",
            "worried he will leave me", "worried she will leave me",
            "scared my boyfriend will leave", "scared my gf will leave",
            "my boyfriend is distant", "my girlfriend is distant",
            "our relationship is falling apart", "we are drifting apart",
            "he is becoming distant", "she is becoming distant",
            "things feel different between us",
            "i feel like he does not love me anymore",
            "i feel like she does not love me anymore",
            "scared he will dump me", "scared she will dump me",
            "i might lose him", "i might lose her",
            "i am scared of losing him", "i am scared of losing her",
        ]
        if any(kw in clean for kw in relationship_kws):
            return "topic_relationship_loss"

        # ── academic sub-topics (specific before generic) ─────
        coding_kws = [
            "coding", "code", "programming", "debugging", "bug", "bugs",
            "cannot code", "can't code", "my code not working",
            "coding assignment", "programming assignment",
            "fyp code", "project code", "system bug", "stuck in coding", "code error",
        ]
        if any(kw in clean for kw in coding_kws):
            return "coding_pressure"

        exam_kws = [
            "exam", "exams", "test", "quiz", "midterm", "final exam",
            "scared fail exam", "afraid fail exam", "exam stress",
            "study for exam", "fear of failing exam", "nervous for exam",
        ]
        if any(kw in clean for kw in exam_kws):
            return "exam_pressure"

        deadline_kws = [
            "deadline", "submission", "due tomorrow", "due soon",
            "late submission", "many deadlines", "assignment due",
            "rush to finish", "not enough time", "time running out", "deadline stress",
        ]
        if any(kw in clean for kw in deadline_kws):
            return "deadline_pressure"

        presentation_kws = [
            "presentation", "present tomorrow", "public speaking",
            "speak in front of class", "nervous present",
            "presentation anxiety", "oral presentation",
        ]
        if any(kw in clean for kw in presentation_kws):
            return "presentation_pressure"

        group_work_kws = [
            "group work", "group project", "teammate lazy",
            "my teammate no do work", "carry whole team",
            "team conflict", "member not helping", "teammates not helping",
        ]
        if any(kw in clean for kw in group_work_kws):
            return "group_work_pressure"

        academic_kws = [
            "assignment", "assignments", "coursework", "study stress",
            "academic pressure", "i scared i fail", "i'm scared i fail",
            "my grades are dropping", "i cannot focus study",
            "i can't focus study", "too many assignments",
        ]
        if any(kw in clean for kw in academic_kws):
            return "academic_pressure"

        # ── other stressors ───────────────────────────────────
        family_kws = [
            "my parents pressure me", "family pressure", "parents expectations",
            "family stressing me out", "my family don't understand me",
            "home pressure", "strict parents", "family conflict",
            "my family makes me tired", "house problems",
        ]
        if any(kw in clean for kw in family_kws):
            return "family_pressure"

        money_kws = [
            "no money", "money stress", "financial problem",
            "can't afford things", "cant afford things", "i'm broke",
            "debt stress", "money issue", "worry about money",
            "financial pressure", "not enough money",
        ]
        if any(kw in clean for kw in money_kws):
            return "money_stress"

        self_comparison_kws = [
            "everyone better than me", "i compare myself to others",
            "others doing better", "i feel behind in life",
            "not as good as others", "people ahead of me",
            "i feel inferior", "why everyone better than me",
            "comparison stress", "i'm behind everyone",
        ]
        if any(kw in clean for kw in self_comparison_kws):
            return "self_comparison"

        low_motivation_kws = [
            "no motivation", "i don't feel like doing anything",
            "i dont feel like doing anything", "i can't start anything",
            "i feel lazy and tired", "no energy to do work",
            "nothing motivates me", "i feel stuck and unmotivated",
            "i dont want to do anything", "hard to start tasks", "lost motivation",
        ]
        if any(kw in clean for kw in low_motivation_kws):
            return "low_motivation"

        focus_kws = [
            "cannot focus", "can't focus", "cant focus",
            "hard to focus", "i lose focus", "i cannot concentrate",
            "i can't concentrate", "my focus is bad", "distracted easily",
        ]
        if any(kw in clean for kw in focus_kws):
            return "focus_problem"

        # ── high-intensity / overwhelm ────────────────────────
        high_intensity_kws = [
            "very strong", "too much", "overwhelming", "cannot handle",
            "can't handle", "extremely anxious", "too intense",
            "i feel like i cannot take it", "i'm breaking down",
        ]
        if any(kw in clean for kw in high_intensity_kws):
            return "high_intensity_distress"

        # ── random pattern ────────────────────────────────────
        random_kws = [
            "random", "just random", "no specific time", "no fixed time",
            "comes randomly", "happens randomly", "no pattern", "its random",
            "it is random", "i cannot predict it", "i can't predict it",
        ]
        if any(kw in clean for kw in random_kws):
            return "random_pattern"

        # ── specific body symptoms (exact/ending match) ───────
        specific_body_symptoms = {
            "tightness": "tightness",
            "tight chest": "tightness",
            "chest pressure": "pressure",
            "pressure": "pressure",
            "breathing hard": "breathing",
            "short breath": "breathing",
            "shortness of breath": "breathing",
            "can't breathe": "breathing",
            "hard to breathe": "breathing",
            "shaking": "shaking",
            "hands shaking": "shaking",
            "hand shaking": "shaking",
            "dizzy": "dizziness",
            "dizziness": "dizziness",
            "restless": "restlessness",
            "sweating": "sweating",
            "nausea": "nausea",
        }
        for phrase, symptom_name in specific_body_symptoms.items():
            if clean == phrase or clean.endswith(phrase):
                return f"specific_body_symptom::{symptom_name}"

        # ── physical panic ────────────────────────────────────
        panic_kws = [
            "shaking", "shaky", "trembling",
            "heartbeat", "heart beating fast", "heartbeat fast",
            "heart racing", "heart fast",
            "chest tight", "chest feels tight", "tight chest",
            "tightness", "chest pressure",
            "short breath", "shortness of breath", "breathing hard",
            "can't breathe", "hard to breathe",
            "dizzy", "dizziness", "sweating",
            "hands shaking", "my hand shaking", "my hands are shaking",
            "my hand shake", "my hand shake a lot", "my hands shake",
            "my hand shaking badly", "tension in my", "body tight",
            "my body is shaking", "my body feel shaky",
            "i can't control my cry", "crying hard",
            "my chest damn tight", "my chest very tight",
            "my heart beating so fast", "shaking a lot",
            "heart pounding", "my heart won't slow down",
        ]
        if any(kw in clean for kw in panic_kws):
            return "physical_panic"

        # ── exercise / relief feedback ────────────────────────
        mixed_relief_kws = [
            "lighter but still", "a bit better but still",
            "a little better but still", "slightly better but still",
            "a little calmer but still", "still have that feeling",
            "still feel it but less", "still there but less", "better but not fully",
            "less intense but still there", "calmer but still anxious",
            "better but still anxious", "still feel anxious but lighter",
            "not as bad but still there",
            "slighter but i still have the feeling",
            "yes slighter but i still have the feeling",
        ]
        if any(kw in clean for kw in mixed_relief_kws):
            return "mixed_relief"

        slight_relief_kws = [
            "a bit", "a little", "a little bit", "slightly better",
            "a bit better", "little better", "somewhat better", "a little calmer",
            "slightly calmer", "bit better", "lighter", "feel lighter",
            "i feel lighter", "less tense", "more calm", "it helped a little",
            "i feel slightly better", "slighter",
            "felt relax a bit", "feel relax a bit", "felt relaxed a bit",
            "feel relaxed a bit", "i feel relaxed a bit",
            "i feel more relaxed", "more relaxed now", "relaxed a bit",
        ]
        if clean in slight_relief_kws:
            return "slight_relief"

        no_change_kws = [
            "still same", "same", "no change", "still panic", "still anxious",
            "still strong", "still bad", "not better", "didnt help",
            "didn't help", "it did not help", "same feeling",
        ]
        if any(kw in clean for kw in no_change_kws):
            return "no_relief"

        # ── single-word topic shorthands ──────────────────────
        if clean in ["not bad", "fine", "okay", "good", "alright", "ok", "nothing much", "somewhat okay"]:
            return "neutral_checkin"
        if clean in ["anxiety", "anxious", "panic", "feel panic", "panicking"]:
            return "topic_anxiety"
        if clean in ["stress", "stressed", "too stressed", "very stressed"]:
            return "topic_stress"
        if clean in ["burnout", "burnt out"]:
            return "topic_burnout"
        if clean in ["chat", "talk", "lets talk", "let's talk"]:
            return "intent_chat"

        # ── body/thought mode answers ─────────────────────────
        if clean in ["both", "all", "i think all", "both of them",
                     "both i think", "my thoughts and body",
                     "both thoughts and body", "everything"]:
            return "body_and_thoughts"

        if clean in ["body", "my body", "in my body", "physically",
                     "mostly my body", "more in my body",
                     "i think is body", "shaking in body", "in body"]:
            return "body_focus"

        # ── short responses ───────────────────────────────────
        confirm_phrases = [
            "yes", "yeah", "yep", "exactly", "sure", "okay", "ok",
            "yes please", "of course", "definitely", "yea",
            "sounds right", "that's right", "thats right", "correct",
            "please do", "alright yes", "yes that's right",
        ]
        if clean in confirm_phrases:
            return "short_confirm"

        deny_phrases = [
            "no", "nah", "nope", "not really", "i don't think so",
            "i dont think so", "not interested", "no thanks",
            "don't want to", "dont want to", "not now",
            "i'd rather not", "id rather not", "rather not", "not this",
            "i dont want that", "i don't want that", "no thank you",
        ]
        if clean in deny_phrases:
            return "short_deny"

        if clean in ["i don't know", "i dont know", "not sure", "unsure"]:
            return "short_idk"

        if clean in ["i tried it", "yes i tried it", "i did it", "okay i tried",
                     "yes i try it", "i tried", "i just did it"]:
            return "task_attempted"

        # ── choice responses ──────────────────────────────────
        breath_kws = ["breath", "breathe", "one more breath", "slow breath",
                      "let's breathe", "lets breathe", "do the breath", "breathing"]
        if clean in breath_kws:
            return "breath_choice"

        stay_kws = [
            "stay", "stay here", "just stay", "stay together", "stay with me",
            "be here", "just be here", "pause", "pause here", "pause now",
            "let's pause", "lets pause", "rest here", "stay for now", "wait here",
        ]
        if clean in stay_kws or any(kw in clean for kw in stay_kws):
            return "stay_choice"

        step_kws = [
            "one more step", "another step", "one more gentle step",
            "more step", "next step", "try one more step", "do one more step",
            "gentle step", "another one", "one more", "do another", "continue",
            "another", "more", "next", "i want another", "want another step",
            "give me another step",
        ]
        if (
            clean in step_kws
            or ("step" in clean and any(w in clean for w in ["more", "another", "next"]))
            or clean.startswith("another")
            or clean.startswith("one more")
        ):
            return "step_choice"

        # ── Manglish / colloquial distress ────────────────────
        slang_kws = [
            "cant tahan", "cannot tahan", "i can't tahan", "i cannot tahan",
            "too much already", "damn stressed", "damn anxious",
            "feel weird lah", "very panic", "panic gila", "stress gila",
            "tak boleh tahan", "penat gila",
        ]
        if any(kw in clean for kw in slang_kws):
            return "venting"

        # ── seeking solutions ─────────────────────────────────
        help_kws = [
            "how can i cope", "how to cope", "what do i do", "help me with this",
            "how to deal with it", "how can i overcome it", "how do i overcome it",
            "i don't know how to calm", "i dont know how to calm",
            "what should i do", "give me advice", "any tips",
        ]
        if any(kw in clean for kw in help_kws):
            return "seeking_solutions"

        return None

    # ── main analysis method ─────────────────────────────────
    def analyze(self, text: str, tracker: "UserContextTracker") -> Dict[str, str]:
        state = {
            "topic": tracker.topic if tracker.topic else "general",
            "intent": "venting",
        }

        clean = self.normalize_text(text)
        rule_hit = self.extract_direct_rules(text)

        state["clean_text"] = clean
        state["msg_word_count"] = len(clean.split())

        # ── Safety first: crisis detection always wins, before ANY other
        # gatekeeper layer (e.g. short-reply/question-answer resolution)
        # gets a chance to reinterpret a crisis disclosure as something else.
        if rule_hit == "emergency_crisis":
            state["intent"] = "emergency_crisis"
            return state

        # ── Meaning-shift detection: the user's latest message can carry a
        # different meaning than whatever situation/emotion was previously being
        # discussed, even on the exact same topic. Computed independently of
        # intent classification so it survives whichever branch below ultimately
        # returns, and OVERRIDES the response's framing instead of letting a
        # persisted situational observation ("timeline pressure") repeat itself
        # while the user has actually moved on to acceptance, relief, etc.
        # Checked in priority order; first match wins.
        MEANING_SHIFT_CUES = {
            # mild distress-adjacent but not crisis-level (handled separately,
            # unconditionally, above) -- checked first since it's the most
            # safety-relevant of the non-crisis shifts.
            "hopelessness": [
                "what's the point", "whats the point", "no point", "nothing works",
                "nothing helps", "i give up", "why bother", "it's useless",
                "its useless", "i can't do this anymore", "i cant do this anymore",
                "there's no use", "theres no use", "i'm done trying", "im done trying",
            ],
            "relief": [
                "that helped", "i feel better", "feeling better", "that worked",
                "feel a bit lighter", "feels a bit lighter", "that's helped",
                "thats helped", "feel a little better", "feel okay now",
            ],
            "confidence": [
                "i think i can", "i can do this", "i'll figure it out",
                "ill figure it out", "i got this", "i've got this", "ive got this",
                "i'm confident", "im confident", "i believe i can",
            ],
            "acceptance": [
                "no choice", "only way", "keep doing", "keep going", "keep trying",
                "push through", "gotta", "might as well", "guess i'll", "guess i will",
                "have to anyway", "no other way", "won't give up", "wont give up",
                "have to deal with it", "just have to", "still gonna", "still going to",
            ],
        }
        meaning_shift = next(
            (cat for cat, kws in MEANING_SHIFT_CUES.items() if any(kw in clean for kw in kws)),
            None,
        )

        # Concrete progress ("completed 30 modules", "only 10 modules left") is its
        # own meaning shift, detected separately since it's a number + cue-word
        # pattern rather than a fixed phrase -- and it carries the specific detail
        # so reflections/exploration can reference it instead of staying generic.
        PROGRESS_CUE_WORDS = ["left", "remaining", "to go", "completed", "finished", "done with", "out of"]
        if meaning_shift is None and re.search(r'\d', clean) and any(cue in clean for cue in PROGRESS_CUE_WORDS):
            meaning_shift = "progress"
            state["progress_detail"] = clean
            tracker.current_progress_detail = clean

        state["meaning_shift"] = meaning_shift

        # ── Clarification Intent Layer (runs BEFORE Answer Interpretation) ──
        # "What do you mean?" is not an answer to the previous question -- it's
        # a request to explain that question/observation differently. Detected
        # first so it can never be misread as a confirm/deny/both/partial reply
        # (e.g. "huh?" must not be treated as answering "What would feel like
        # good progress from here?"). Skips topic/entity/event extraction and
        # does not advance the conversation stage (handled by stage_engine
        # treating this strategy as a no-op).
        CLARIFICATION_SUBSTRINGS = [
            "what do you mean", "what you mean", "what does that mean",
            "what's that supposed to mean", "whats that supposed to mean",
            "can you explain", "could you explain", "could you clarify",
            "can you clarify", "i don't understand", "i dont understand",
            "not sure what you mean", "not sure what that means",
            "come again",
        ]
        CLARIFICATION_EXACT = {"what?", "huh?", "sorry?", "what", "huh", "sorry"}
        is_clarification_request = (
            any(p in clean for p in CLARIFICATION_SUBSTRINGS)
            or clean in CLARIFICATION_EXACT
        )
        if is_clarification_request and tracker.last_bot_turn.get("text"):
            state["intent"] = "request_clarification"
            return state

        # ── Answer Interpretation Layer + Context Inheritance ──
        # A short confirm/deny/both/partial reply to the bot's last turn (question
        # OR a confirmable observation/statement) carries no topical content of its
        # own -- interpret it relative to that prior turn, and skip topic/entity/
        # event reclassification entirely so a contentless reply like "I think
        # both" can never flip tracker.current_situation to something random.
        CONFIRM_TOKENS = {
            "yes", "yeah", "yep", "yup", "exactly", "sure", "definitely", "yea",
            "correct", "that's right", "thats right", "sounds right", "right",
        }
        DENY_TOKENS = {
            "no", "nah", "nope", "not really", "not at all",
            "i don't think so", "i dont think so",
        }
        BOTH_TOKENS = {
            "both", "both of them", "both of those", "all of them", "all of the above",
        }
        PARTIAL_TOKENS = {
            "maybe", "kind of", "kinda", "sort of", "somewhat", "a little", "a bit",
            "probably", "i guess", "i suppose", "guess so", "not sure", "could be",
        }
        ANSWER_HEDGE_PREFIX = re.compile(
            r'^(?:i think|i\'d say|id say|i would say|i suppose|i feel like|honestly|probably|well|so|actually)[\s,]+',
            re.IGNORECASE,
        )
        core_answer = ANSWER_HEDGE_PREFIX.sub('', clean).strip().rstrip(".!?,;:")
        core_answer = core_answer or clean.rstrip(".!?,;:")

        answer_sentiment = None
        if core_answer in CONFIRM_TOKENS:
            answer_sentiment = "confirm"
        elif core_answer in DENY_TOKENS:
            answer_sentiment = "deny"
        elif core_answer in BOTH_TOKENS:
            answer_sentiment = "both"
        elif core_answer in PARTIAL_TOKENS:
            answer_sentiment = "partial"

        # This layer is purely additive: it defers to the coping-flow-specific
        # awaiting flags (which dispatch real coping-step delivery on confirm/
        # deny, so must not be bypassed) and to the pending-action layer (which
        # needs to consume/clear awaiting_confirmation itself). It deliberately
        # does NOT defer to awaiting_open_emotion_detail -- that flag's own
        # confirm/deny handling is generic and was part of the original gap
        # this layer exists to fill.
        any_specific_awaiting_flag = (
            tracker.awaiting_confirmation
            or tracker.awaiting_choice_response
            or tracker.awaiting_exercise_feedback
            or tracker.awaiting_grounding_items
            or tracker.awaiting_binary_progress_answer
        )
        prior_turn = tracker.last_bot_turn
        if (
            answer_sentiment
            and not any_specific_awaiting_flag
            and prior_turn.get("kind") in ("choice", "question", "statement")
            and not prior_turn.get("answered")
            and len(clean.split()) <= 8
        ):
            prior_turn["answered"] = True
            if answer_sentiment == "both" and prior_turn.get("option_a") and prior_turn.get("option_b"):
                state["intent"] = "confirmed_both"
                state["choice_option_a"] = prior_turn["option_a"]
                state["choice_option_b"] = prior_turn["option_b"]
            elif answer_sentiment == "confirm":
                state["intent"] = "confirmed_observation"
            elif answer_sentiment == "deny":
                state["intent"] = "denied_observation"
            elif answer_sentiment == "partial":
                state["intent"] = "partial_confirmation"
            else:  # "both" without stored options to confirm both of
                state["intent"] = "confirmed_observation"
            return state

        # ── Extract and store topic/situation/event memory ────
        topic_info = self.topic_extractor.extract(text)
        new_info = False
        if topic_info.get("topic_entity") and topic_info["topic_entity"] != tracker.current_entity:
            tracker.current_entity = topic_info["topic_entity"]
            new_info = True
        if topic_info.get("event_phrase") and topic_info["event_phrase"] != tracker.current_event:
            tracker.current_event = topic_info["event_phrase"]
            new_info = True

        if topic_info.get("topic_category") and topic_info["topic_category"] != "general":
            state["topic"] = topic_info["topic_category"]
            tracker.current_situation = topic_info["topic_category"]

        state["new_info"] = new_info
        state["event_phrase"] = topic_info.get("event_phrase")
        state["repetition_cue"] = topic_info.get("repetition_cue", False)

        # ── Event-category detection: a more specific lens than topic_category
        # (e.g. "academic" -> "technical"/"deadline"/"supervisor_feedback"), so
        # responses can use situation-tailored phrasing instead of generic
        # academic-stress framing. Persists like current_entity/current_event
        # (non-overwrite-on-None) so it survives short answers that don't
        # re-mention the keyword.
        # Assumption Safety Layer: "technical" is detected from generic mentions
        # (backend/system/code) OR specific failure evidence (bug/error/crash).
        # The two are tracked separately so response content can avoid assuming
        # debugging specifically unless the user actually said so.
        TECHNICAL_FAILURE_KEYWORDS = [
            "bug", "bugs", "debug", "debugging", "error", "crash",
            "not working", "doesn't work", "broke", "breaking",
        ]
        if any(kw in clean for kw in TECHNICAL_FAILURE_KEYWORDS):
            tracker.technical_failure_evidence = True

        EVENT_CATEGORY_KEYWORDS = {
            "technical": [
                "backend", "frontend", "code", "coding", "system", "api",
                "database", "server", "compile", "syntax", "function",
            ] + TECHNICAL_FAILURE_KEYWORDS,
            "deadline": [
                "deadline", "due date", "due soon", "overdue", "submission",
                "running out of time", "not enough time", "time left",
            ],
            "supervisor_feedback": [
                "supervisor", "feedback", "revise", "revision", "reject",
                "rejected", "comments", "professor", "lecturer", "advisor",
            ],
            "relationship": [
                "boyfriend", "girlfriend", "partner", "breakup", "broke up",
                "relationship",
            ],
            "family": ["mother", "father", "mom", "dad", "family", "parents"],
        }
        detected_category = next(
            (cat for cat, kws in EVENT_CATEGORY_KEYWORDS.items() if any(kw in clean for kw in kws)),
            None,
        )
        if detected_category:
            # Explicit keyword match this turn -- update directly, even if it
            # overwrites a previous category (this is a direct signal, like entity).
            tracker.current_event_category = detected_category
        elif tracker.current_event_category:
            # No new keyword this turn -- keep the persisted category rather than
            # letting a generic "academic" fallback overwrite something specific
            # (e.g. "technical") just because this message didn't repeat a keyword.
            detected_category = tracker.current_event_category
        elif state.get("topic") == "academic":
            detected_category = "academic"
            tracker.current_event_category = "academic"
        state["event_category"] = detected_category

        # ── GATEKEEPER LAYER ──────────────────────────────────
        DISENGAGE_KEYWORDS = ["don't want to talk", "dont want to talk", "stop", "change topic", "not this", "overwhelmed", "let's talk about something else", "lets talk about something else"]
        LOW_ENGAGEMENT_KEYWORDS = ["nothing", "ok", "okay", "idk", "hmm", "...", "no", "nah", "yep", "yes"]
        
        ACADEMIC_KEYWORDS = ["fyp", "assignment", "project", "coding", "backend", "report", "deadline", "due date", "due soon", "overdue", "submission", "exam", "study", "work", "alot of thing", "a lot of thing", "task"]
        EMOTION_KEYWORDS = ["stressed", "overwhelmed", "anxious", "depressed", "sad", "frustrated", "hopeless", "angry", "tired", "panic", "worry"]
        EMOTION_PHRASES = ["i feel", "i'm feeling", "im feeling", "i can't cope", "icant cope", "i am not okay", "im not okay", "i'm not okay"]
        PHYSICAL_KEYWORDS = ["heart racing", "breathe", "panic", "shaking", "tense", "dizzy"]

        # Priority 1: Disengagement detection
        if any(kw in clean for kw in DISENGAGE_KEYWORDS):
            tracker.stop_topic_flow = True
            tracker.topic = None
            tracker.current_entity = None
            tracker.current_situation = None
            tracker.current_event = None
            tracker.current_event_category = None
            tracker.current_progress_detail = None
            tracker.technical_failure_evidence = False
            tracker.last_bot_turn = {
                "text": "", "kind": "statement", "option_a": None, "option_b": None,
                "answered": True, "topic": None, "entity": None, "intent": None,
            }
            tracker.conversation_stage = "validation"
            tracker.stage_turns = 0
            tracker.entity_mention_streak = 0
            tracker.last_literal_entity = None
            tracker.last_entity_alias = None
            tracker.pending_action = None
            tracker.awaiting_confirmation = False
            has_emotion = any(kw in clean for kw in EMOTION_KEYWORDS) or any(ph in clean for ph in EMOTION_PHRASES)
            if has_emotion:
                state["intent"] = "topic_shift_emotion"
            else:
                state["intent"] = "topic_shift_neutral"
            return state

        # Priority 1.5: 'Nothing' edge case
        if clean.startswith("nothing") and len(clean.split()) <= 6:
            state["intent"] = "general_activity"
            return state

        # Priority 1.7: Pending-action confirmation -- when the bot offered
        # something actionable (e.g. a grounding step) and is waiting on a
        # yes/no, resolve that BEFORE the generic answer/low-engagement
        # layers get a chance to misread it as something else.
        if tracker.awaiting_confirmation:
            tracker.awaiting_confirmation = False
            if rule_hit == "short_confirm":
                state["intent"] = "confirm_pending_action"
                return state
            if rule_hit == "short_deny":
                state["intent"] = "decline_pending_action"
                tracker.pending_action = None
                return state
            # Ambiguous reply -- let the pending action lapse and classify normally.
            tracker.pending_action = None

        # ── context-aware short-response disambiguation -- MUST run before
        # Priority 2/3 below: those generic layers would otherwise misread a
        # "yes"/"no" answer to one of these specific pending questions (e.g.
        # "yes" is itself in LOW_ENGAGEMENT_KEYWORDS) as something else,
        # exactly the bug that let a confirmed grounding offer fall through
        # to generic conversation instead of executing. ──────────────────
        if tracker.awaiting_exercise_feedback:
            if rule_hit in ["mixed_relief", "slight_relief", "no_relief", "task_attempted", "short_confirm", "short_deny"]:
                if rule_hit == "no_relief" and tracker.no_relief_count >= 2:
                    state["intent"] = "repeated_no_relief"; return state
                if rule_hit in ["mixed_relief", "slight_relief", "no_relief"]:
                    state["intent"] = rule_hit; return state
                if rule_hit == "short_confirm":
                    state["intent"] = "unclear_positive_feedback"; return state
                if rule_hit == "short_deny":
                    state["intent"] = "no_relief"; return state
                if rule_hit == "task_attempted":
                    state["intent"] = "task_attempted"; return state

        if tracker.awaiting_choice_response:
            if rule_hit in ["breath_choice", "stay_choice", "step_choice", "short_confirm", "short_deny"]:
                if rule_hit == "breath_choice":
                    state["intent"] = "breath_choice"; return state
                if rule_hit == "stay_choice":
                    state["intent"] = "stay_choice"; return state
                if rule_hit == "step_choice":
                    state["intent"] = "step_choice"; return state
                if rule_hit == "short_confirm":
                    state["intent"] = "step_choice"; return state
                if rule_hit == "short_deny":
                    state["intent"] = "stay_choice"; return state

        if tracker.awaiting_grounding_items:
            grounding_words = [
                "laptop", "mouse", "lamp", "table", "phone", "chair", "desk",
                "wall", "bottle", "pen", "keyboard", "screen", "watch", "bed",
                "pillow", "door", "book", "window", "spoon", "glasses", "wallet",
                "cup", "plant", "fan", "light", "curtain", "shelf", "floor",
            ]
            listed_items = sum(1 for word in grounding_words if word in clean)
            is_grounding_list = listed_items >= 2 or "," in clean
            if is_grounding_list or rule_hit == "task_attempted":
                state["intent"] = "grounding_completed"; return state

        if tracker.awaiting_binary_progress_answer:
            if rule_hit in ["short_confirm", "short_deny", "mixed_relief", "slight_relief", "no_relief"]:
                if rule_hit == "short_confirm":
                    state["intent"] = "ambiguous_progress_yes"; return state
                if rule_hit == "short_deny":
                    state["intent"] = "ambiguous_progress_no"; return state
                if rule_hit in ["mixed_relief", "slight_relief", "no_relief"]:
                    state["intent"] = rule_hit; return state

        if tracker.awaiting_open_emotion_detail:
            if rule_hit in ["short_confirm", "short_deny"]:
                if rule_hit == "short_confirm":
                    state["intent"] = "ambiguous_open_yes"; return state
                if rule_hit == "short_deny":
                    state["intent"] = "short_deny"; return state

        # Priority 2: Question-Answer Resolution Layer
        BOOLEAN_ANSWERS = ["yes", "no", "yup", "nope", "sure", "maybe", "yeah"]
        SLOT_ANSWERS = ["backend", "database", "authentication", "flutter", "api", "firebase", "frontend", "ui"]
        SHORT_PHRASES = ["backend stuff", "debugging", "documentation", "final report", "writing code", "testing"]
        
        is_answering = False
        if tracker.last_bot_question.get("text") and not tracker.last_bot_question.get("answered"):
            # Broaden heuristic: if it's a short statement and they were just asked a question.
            # Pure ambiguity fillers (hmm/nothing/.../nah/ok) are excluded here so they fall
            # through to the low-engagement filter below instead of being misread as an answer.
            # Capped at 4 words (not 5) and requires no rule_hit match, so a short but
            # complete new statement ("My backend keeps having problems.") still gets its
            # own classification instead of being swallowed as a generic answer.
            if (
                len(clean.split()) <= 4
                and rule_hit is None
                and not any(kw in clean for kw in EMOTION_KEYWORDS)
                and clean not in LOW_ENGAGEMENT_KEYWORDS
            ):
                is_answering = True
            elif clean in BOOLEAN_ANSWERS or clean in SLOT_ANSWERS or clean in SHORT_PHRASES:
                is_answering = True
            elif len(clean.split()) <= 3 and any(w in clean for w in SLOT_ANSWERS):
                is_answering = True
                
        if is_answering:
            tracker.last_bot_question["answered"] = True
            state["intent"] = "answer_previous_question"
            state["answer_value"] = clean
            return state

        # Priority 3: Low-engagement filter (Only if NOT answering a question)
        if clean in LOW_ENGAGEMENT_KEYWORDS or (len(clean.split()) <= 2 and any(kw == clean for kw in LOW_ENGAGEMENT_KEYWORDS)):
            state["intent"] = "low_engagement"
            return state

        # Priority 4: Emotion Activation Flag
        academic_event_category = state.get("event_category") or tracker.current_event_category
        has_academic = (
            any(kw in clean for kw in ACADEMIC_KEYWORDS)
            or tracker.topic in ["academic", "fyp"]
            or academic_event_category in ("technical", "deadline", "supervisor_feedback", "academic")
        )
        has_emotion = any(kw in clean for kw in EMOTION_KEYWORDS) or any(ph in clean for ph in EMOTION_PHRASES)
        has_physical = any(kw in clean for kw in PHYSICAL_KEYWORDS)
        tracker.explicit_emotion_detected = has_emotion or has_physical

        # ── specific body symptom (sets tracker state) ────────
        if rule_hit and rule_hit.startswith("specific_body_symptom::"):
            symptom_name = rule_hit.split("::", 1)[1]
            tracker.last_body_symptom = symptom_name
            state["intent"] = "specific_body_symptom"
            state["topic"] = "anxiety"
            return state

        # Context-aware handling for "all / both"
        if rule_hit == "body_and_thoughts":
            if tracker.last_strategy in [
                "academic_support",
                "coding_pressure_support",
                "exam_pressure_support",
                "deadline_pressure_support",
                "presentation_pressure_support",
                "group_work_pressure_support"
            ]:
                state["intent"] = "academic_all_pressure"
                state["topic"] = "academic"
                return state

        # ── apply rule hit ────────────────────────────────────
        if rule_hit:
            if rule_hit == "physical_panic":
                if "tight" in clean or "pressure" in clean:
                    tracker.last_body_symptom = "tightness"
                elif "breath" in clean or "shortness" in clean:
                    tracker.last_body_symptom = "breathing"
                elif "shake" in clean or "shaking" in clean or "shaky" in clean:
                    tracker.last_body_symptom = "shaking"

            if rule_hit.startswith("topic_"):
                state["topic"] = rule_hit.split("_", 1)[1]
                state["intent"] = "venting"
            else:
                state["intent"] = rule_hit
            return state

        # ── BiLSTM inference ──────────────────────────────────
        tokens = self.tokenize(clean)
        seq = self.encode_sequence(tokens)
        x_tensor = torch.tensor([seq], dtype=torch.long).to(self.device)

        with torch.no_grad():
            output = self.model(x_tensor)
            probs = torch.softmax(output, dim=1)
            prob, predicted = torch.max(probs, dim=1)
            tag = self.tags[predicted.item()]

        if prob.item() < 0.60:
            # Low BiLSTM confidence -- before giving up with "uncertain", defer to the
            # reliable rule-based academic-keyword signal if one is present.
            if has_academic and not tracker.explicit_emotion_detected:
                state["topic"] = "academic"
                state["intent"] = "academic_workload"
                return state
            state["intent"] = "uncertain"
        else:
            emotion_tags = ["body_better_mind_worry", "physical_panic", "anxiety", "depression", "sadness", "stress", "strong_negative_mood"]

            # Check confidence threshold for academic classification overrides
            if has_academic and not tracker.explicit_emotion_detected:
                if tag in emotion_tags or tag in ["general_activity", "neutral_checkin", "venting"] or prob.item() < 0.85:
                    state["topic"] = "academic"
                    state["intent"] = "academic_workload"
                    return state

            if tag.startswith("topic_"):
                state["topic"] = tag.split("_", 1)[1]
                state["intent"] = "venting"
            else:
                state["intent"] = tag

        # ── Check if user answered the last question ──────────
        if tracker.last_bot_question and not tracker.last_bot_question.get("answered"):
            if len(clean.split()) > 2 and state.get("intent") not in ["topic_shift_neutral", "topic_shift_emotion", "low_engagement"]:
                tracker.last_bot_question["answered"] = True

        return state


# ============================================================
# DIALOGUE MANAGER
# ============================================================
class SmarterDialogueManager:
    def __init__(self):
        self.stage_engine = ConversationStageEngine()

    def get_coping_strategy_for_symptom(self, tracker: "UserContextTracker") -> str:
        symptom_map = {
            "shaking":    "grounding_tactile_step",
            "tightness":  "chest_release_step",
            "breathing":  "guided_breath_step",
            "dizziness":  "orientation_step",
            "sweating":   "cool_down_grounding",
        }
        return symptom_map.get(tracker.last_body_symptom, "deliver_coping_step")

    def compute_strategy(
        self, state: Dict[str, str], tracker: "UserContextTracker"
    ) -> str:
        """Resolve a strategy, then let the stage engine record which
        conversation stage (validation/reflection/exploration/encouragement/
        problem_solving) applies to *this* turn's response in state["active_stage"]."""
        strategy = self._resolve_strategy(state, tracker)
        state["active_stage"] = self.stage_engine.advance(strategy, state, tracker)
        return strategy

    def _resolve_strategy(
        self, state: Dict[str, str], tracker: "UserContextTracker"
    ) -> str:
        intent = state["intent"]
        topic = state.get("topic", "general")
        prevent_questions = tracker.consecutive_questions >= 2

        # ── Gatekeeper / Override Intents ─────────────────────────
        if intent == "topic_shift_emotion":
            return "topic_shift_emotion_strategy"
        if intent == "topic_shift_neutral":
            return "topic_shift_neutral_strategy"
        if intent == "low_engagement":
            return "low_engagement_strategy"
        if intent == "uncertain":
            return "clarify_uncertain"

        # ── Clarification Intent Layer: explain the previous turn, don't
        # advance anything. ───────────────────────────────────────────────
        if intent == "request_clarification":
            return "explain_clarification"

        # ── Answer Interpretation Layer: a short confirm/deny/both/partial
        # reply to the bot's last turn, resolved relative to it instead of
        # being treated as a standalone message. ──────────────────────────
        if intent == "confirmed_both":
            return "confirmed_both_strategy"
        if intent == "confirmed_observation":
            return "confirmed_observation_strategy"
        if intent == "denied_observation":
            return "denied_observation_strategy"
        if intent == "partial_confirmation":
            return "partial_confirmation_strategy"

        # ── safety first ──────────────────────────────────────
        if intent == "emergency_crisis":
            return "escalation"

        # ── pending action confirmation: the bot must follow through on its
        # own offer instead of returning to generic conversation ──────────
        if intent == "confirm_pending_action":
            action = tracker.pending_action
            tracker.pending_action = None
            if action == "grounding":
                return self.get_coping_strategy_for_symptom(tracker)
            return "graceful_close_or_continue"
        if intent == "decline_pending_action":
            return "acknowledge_decline_action"

        # ── emotional overwhelm (panic/anxiety/strong distress), once enough
        # rapport has built up, gets OFFERED a grounding step (consent-gated,
        # since it's a guided exercise) rather than generic encouragement.
        # Practical overwhelm (workload/deadlines) instead gets structured
        # problem-solving once it reaches that stage -- no offer needed since
        # asking a planning question doesn't require the same opt-in.
        EMOTIONAL_OVERWHELM_INTENTS = {"physical_panic", "anxiety", "strong_negative_mood"}
        if (
            intent in EMOTIONAL_OVERWHELM_INTENTS
            and tracker.conversation_stage == "encouragement"
            and not tracker.awaiting_confirmation
            and tracker.coping_steps_tried == 0
        ):
            return "offer_grounding"

        # ── session management ────────────────────────────────
        if intent == "session_close":
            return "close"
        if intent == "greeting":
            return "greeting"
        if intent == "gratitude":
            return "graceful_close_or_continue"

        # ── persistent no-relief → de-escalate ───────────────
        if tracker.no_relief_count >= 3:
            return "persistent_no_relief_support"

        # ── repeated no-relief ────────────────────────────────
        if intent == "repeated_no_relief":
            return "slow_down_support"

        if intent == "academic_workload":
            return "academic_explore_strategy"

        if intent == "answer_previous_question":
            return "answer_acknowledgement_strategy"

        if intent == "general_activity":
            if topic in ["academic", "fyp"]:
                return "academic_explore_strategy"
            return "open_chat"

        if intent == "academic_all_pressure":
            return "academic_all_support"

        # ── Check emotional context before global overrides ──
        # DO NOT allow global emotional overrides if the current intent is neutral/academic
        emotion_tags = [
            "body_better_mind_worry", "physical_panic", "anxiety", "depression", 
            "sadness", "stress", "strong_negative_mood", "anger_frustration",
            "guilt_shame", "emptiness", "repeated_no_relief", "no_relief"
        ]
        
        if intent in emotion_tags:
            # Soft escalation: sustained + worsening
            if (tracker.distress_level >= 5 
                    and tracker.no_relief_count >= 2 
                    and tracker.is_sustained_distress()):
                return "soft_escalation_support"

            # Check distress level escalation
            if tracker.distress_level >= 5:
                # Skip light-touch responses and go straight to coping/grounding
                return self.get_coping_strategy_for_symptom(tracker)

        # Check topic transition
        if (topic != tracker.topic 
                and topic not in [None, "general"]
                and tracker.topic not in [None, "general"] 
                and tracker.turn_count > 2):
            return "topic_shift_acknowledgement"

        # ── mood states ───────────────────────────────────────
        mood_map = {
            "strong_negative_mood": "strong_negative_support",
            "anger_frustration": "anger_frustration_support",
            "sadness": "sadness_support",
            "negative_checkin": "negative_checkin_support",
            "confusion": "confusion_support",
            "guilt_shame": "guilt_shame_support",
            "emptiness": "emptiness_support",
            "friendship_pressure": "friendship_pressure_support",
            "social_anxiety": "social_anxiety_support",
            "self_esteem": "self_esteem_support",
            "future_uncertainty": "future_uncertainty_support",
            "looping_thoughts": "looping_thoughts_support",
            "overthinking": "overthinking_support",
            "sleep_problem": "sleep_support",
            "body_better_mind_worry": "body_better_mind_worry_support",
            "fear_unsolved_problem": "future_worry_support",
            "high_intensity_distress": "high_intensity_support",
            "coding_pressure": "coding_pressure_support",
            "exam_pressure": "exam_pressure_support",
            "deadline_pressure": "deadline_pressure_support",
            "presentation_pressure": "presentation_pressure_support",
            "group_work_pressure": "group_work_pressure_support",
            "academic_pressure": "academic_support",
            "academic_all_support": ("academic_all_support", "open_emotion"),
            "family_pressure": "family_pressure_support",
            "money_stress": "money_stress_support",
            "self_comparison": "self_comparison_support",
            "low_motivation": "low_motivation_support",
            "focus_problem": "focus_problem_support",
        }
        if intent in mood_map:
            return mood_map[intent]

        # ── relationship ──────────────────────────────────────
        if intent == "venting" and topic in ["relationship", "relationship_loss"]:
            return "relationship_loss_support"
        if intent == "venting" and topic == "relationship":
            return "relationship_loss_support"

        # ── random pattern ────────────────────────────────────
        if intent == "random_pattern":
            return (
                "random_pattern_anxiety_support"
                if tracker.topic == "anxiety"
                else "random_pattern_followup"
            )

        # ── check-in / chat ───────────────────────────────────
        if intent == "neutral_checkin":
            if prevent_questions:
                tracker.consecutive_questions = 0 # reset to allow normal flow after pivot
                return "gentle_pivot"
            return "explore_checkin"
        if intent == "intent_chat":
            return "open_chat"

        # ── short replies ─────────────────────────────────────
        if intent == "short_confirm":
            return "validate_confirm"
        if intent == "short_deny":
            return "pure_validation"
        if intent == "short_idk":
            return "soft_idk_response"

        # ── progress / ambiguity ──────────────────────────────
        if intent in ["ambiguous_progress_yes", "ambiguous_progress_no"]:
            return "clarify_progress_binary"
        if intent == "ambiguous_open_yes":
            return "clarify_short_yes"
        if intent == "unclear_positive_feedback":
            return "soft_positive_transition"

        # ── relief feedback ───────────────────────────────────
        if intent == "slight_relief":
            return "reinforce_small_progress"
        if intent == "mixed_relief":
            return "stabilize_partial_relief"
        if intent == "no_relief":
            return "respond_to_no_relief"

        # ── choice responses ──────────────────────────────────
        if intent == "breath_choice":
            return "guided_breath_step"
        if intent == "stay_choice":
            return "stay_present_support"
        if intent == "step_choice":
            return (
                "next_calming_step"
                if tracker.grounding_completed_recently
                else self.get_coping_strategy_for_symptom(tracker)
            )

        # ── physical / body ───────────────────────────────────
        if intent == "physical_panic":
            return "panic_body_symptom_followup"
        if intent == "specific_body_symptom":
            return self.get_coping_strategy_for_symptom(tracker)
        if intent == "body_and_thoughts":
            return "mixed_anxiety_followup"
        if intent == "body_focus":
            return self.get_coping_strategy_for_symptom(tracker) if tracker.last_body_symptom else "body_symptom_probe"

        # ── chronic / coping ──────────────────────────────────
        if intent == "chronic_distress":
            return (
                "chronic_shift_to_body_or_thoughts"
                if tracker.last_question_type == "timing"
                else "deep_empathy_guided"
            )
        if intent == "coping_failure":
            return "coping_alternative"
        if intent == "seeking_solutions":
            return "solution_suggestion"
        if intent in ["task_attempted", "grounding_completed"]:
            return "evaluate_task"

        # ── uncertain ─────────────────────────────────────────
        if intent == "uncertain":
            return "smart_clarification" if not prevent_questions else "pure_validation"

        # ── venting with topic ────────────────────────────────
        if intent == "venting" and topic == "anxiety":
            if tracker.last_question_type == "timing":
                return "anxiety_body_or_thoughts_followup"
            if tracker.turn_count <= 2:
                return "anxiety_direct_open"

        if prevent_questions:
            return "reflective_validation"

        return "topic_exploration"


# ============================================================
# RESPONSE GENERATOR
# ============================================================
class HumanResponseGenerator:
    def __init__(self, responses_path: str = "responses.json"):
        self.responses = self._load_responses(responses_path)

    def _load_responses(self, responses_path: str) -> Dict[str, List[str]]:
        # ── master default bank (single source of truth) ─────
        defaults: Dict[str, List[str]] = {
            # ── session ──────────────────────────────────────
            "greeting": [
                "Hello! I'm here and ready to chat with you. How has your day been so far?",
                "Hey there. It's good to hear from you. How are things going today?",
                "Hi! Thanks for dropping by. What's on your mind today?",
                "Hello! I'm doing well, thanks for asking. How are you doing today?",
            ],
            "close": [
                "Thank you for sharing with me today. Please be gentle with yourself and take care.",
                "It was good to be with you today. Take things one small step at a time, and be kind to yourself.",
                "Thank you for trusting me with this. Rest well, and remember — one moment at a time.",
            ],
            "crisis": [
                (
                    "What you're feeling right now matters deeply, and so do you. "
                    "Please reach out to a crisis helpline or a trusted person near you immediately. "
                    "You deserve real, human support right now. You are not alone in this."
                )
            ],
            "academic_all_support": [
                "That makes sense. When the deadline, workload, and fear of not doing well all hit together, it can feel overwhelming. Let’s make it smaller first — what is the assignment you need to finish?",
                "I hear you. If all of those are pressing at once, we do not need to solve everything immediately. What is the most urgent assignment right now?",
                "That sounds like a lot at the same time. Let’s separate it gently: what is due first?"
            ],
            "graceful_close_or_continue": [
                "You're welcome. I'm glad you stayed with it for a moment. We can pause here, or you can tell me how you're feeling now.",
                "You're welcome. You did well to slow things down. We can stop here, or keep going if you need.",
                "You're welcome. I'm here with you — we can leave it here, or keep talking if that would help.",
            ],

            # ── check-in / chat ───────────────────────────────
            "explore_checkin": [
                "I'm glad you're doing okay. Is there anything on your mind today, or do you just want to chat?",
                "That's good to hear. Is there something you'd like to talk through, or are you just checking in?",
            ],
            "gentle_pivot": [
                "That's okay. Sometimes things just feel quiet or neutral, and that matters too.",
                "That's alright. Not every day needs to be heavy — I'm still here with you.",
            ],
            "low_engagement_strategy": [
                "That's okay, you don't need to find the right words right now. I'm still here whenever you're ready.",
                "No worries. Sometimes there isn't a clear answer, and that's fine — I'm not going anywhere.",
                "That's alright. We can just sit with this for a moment if that feels easier.",
                "It's okay not to know. Take your time — I'll be here when you want to say more.",
            ],
            "topic_shift_neutral_strategy": [
                "Sure, we can shift gears. What's on your mind instead?",
                "Okay, let's leave that there for now. What would you like to talk about?",
                "That's fine, we can change direction. I'm listening — what's up?",
            ],
            "topic_shift_emotion_strategy": [
                "That's okay, we don't have to stay on this if it feels like too much right now. I'm still here with you.",
                "Of course, let's step away from that for now. How are you feeling in this moment?",
                "That makes sense if it feels heavy to stay on this. We can pause it — what would help right now?",
            ],
            "offer_grounding": [
                "Would you be open to trying a short calming step right now?",
                "Would it help to pause for a moment and try a brief grounding exercise together?",
                "Before we go further, would you like to try a quick grounding step with me?",
            ],
            "acknowledge_decline_action": [
                "That's okay, no pressure at all. We can just keep talking.",
                "No worries, we don't have to do that right now.",
                "That's fine, I'm still here either way — let's keep going.",
            ],
            "open_chat": [
                "I'm here with you. What feels most worth talking about right now?",
                "I'm glad you came. What would feel helpful to talk about today?",
            ],
            
            # ── academic exploration / assumptions prevention ─
            "academic_explore_strategy": [
                "Sounds like you're working hard on that. What exactly are you building or doing right now?",
                "That sounds like a busy workload. Which part is taking more time right now?",
                "Got it. What kind of issue or task are you trying to solve at the moment?",
            ],
            "answer_acknowledgement_strategy": [
                "I see. Thanks for letting me know. Tell me a bit more about what's going on.",
                "Got it. What else is on your mind right now?",
                "Understood. How does that make you feel overall?",
            ],

            # ── mood responses ────────────────────────────────
            "strong_negative_support": [
                "That sounds really rough. I'm here with you. What happened that made it feel this bad?",
                "I hear you. That sounds like a heavy moment. Do you want to talk about what triggered it?",
                "That sounds painful to sit with. What part of today has been hitting you the hardest?",
                "It sounds like you're carrying something really heavy right now. I'm not going anywhere — what's been happening?",
            ],
            "negative_checkin_support": [
                "I'm sorry it feels that way today. What has been weighing on you most?",
                "That sounds like a rough day. Do you know what has been affecting you most?",
                "I hear you. Things sound heavy right now. What feels hardest at the moment?",
                "That doesn't sound easy. You don't have to explain it perfectly — what part feels most difficult?",
            ],
            "anger_frustration_support": [
                "That anger sounds heavy. What do you think triggered it most?",
                "I hear that you feel frustrated. Is it more anger, hurt, or feeling misunderstood right now?",
                "That sounds really frustrating. What part of this feels most unfair or upsetting?",
                "Anger can feel exhausting to carry. What has been building up for you?",
            ],
            "sadness_support": [
                "That sounds painful. What has been making you feel this sad lately?",
                "I hear you. That sadness sounds heavy to carry. Do you know what brought it up?",
                "That sounds really hard. Would it help to talk about what's been hurting most?",
                "I'm here with you in this. Sadness doesn't need to be explained perfectly — what's sitting heaviest right now?",
            ],
            "confusion_support": [
                "That's okay. You don't need to understand everything immediately. What part feels most confusing right now?",
                "Feeling confused can be really unsettling. Is it more about your emotions, your situation, or what to do next?",
                "I hear you. When everything feels unclear, we can slow it down. What is one thing you're most unsure about?",
            ],
            "guilt_shame_support": [
                "That sounds heavy to carry. Guilt can feel really painful when you keep turning it inward. What are you blaming yourself for?",
                "I hear that you feel responsible. Would it help to look at what happened more gently, step by step?",
                "That sounds painful. Feeling ashamed can make you want to withdraw — but you don't have to hold this alone here.",
                "I'm here with you. Sometimes we are much harder on ourselves than we would ever be on anyone else. What happened?",
            ],
            "emptiness_support": [
                "That empty feeling can be really hard to explain. Has it been there today only, or for a while?",
                "I hear you. Feeling numb or empty can be exhausting in its own quiet way. What has the day felt like for you?",
                "That sounds lonely and heavy. When you say empty, does it feel more like sadness, tiredness, or just numbness?",
                "Sometimes emptiness is what exhaustion looks like on the inside. How long has it been feeling this way?",
            ],
            "friendship_pressure_support": [
                "Friendship problems can hurt a lot, especially when you feel left out or misunderstood. What happened with your friend?",
                "That sounds painful. Is it more about being ignored, conflict, or feeling like you don't belong anymore?",
                "I hear you. Friendships can feel really fragile when something breaks the trust. What's been happening?",
            ],
            "social_anxiety_support": [
                "That sounds really uncomfortable. Being around people can feel heavy when you keep worrying about how they see you. What situation makes you feel this most?",
                "I hear you. Social anxiety can make even normal conversations feel like a test. Is it more fear of being judged, or not knowing what to say?",
                "That sounds tiring. What kind of situation brings this up the most for you?",
            ],
            "self_esteem_support": [
                "That sounds really heavy to carry. When you feel not good enough, it can make everything harder. What made you feel this way today?",
                "I hear you. Feeling like a failure can be painful, but that doesn't mean it's the truth about you. What happened that triggered this feeling?",
                "That sounds exhausting. Where do you feel like you fall short the most — with others, with yourself, or both?",
            ],
            "future_uncertainty_support": [
                "Feeling unsure about the future can be really scary. You don't have to figure everything out at once. What part feels most unclear right now?",
                "That sounds overwhelming. When the future feels uncertain, it helps to focus on one small next step. Is this more about study, career, relationship, or direction in general?",
                "I hear you. Not knowing where things are headed can make you feel stuck. What's causing the most uncertainty right now?",
            ],

            # ── cognitive ────────────────────────────────────
            "looping_thoughts_support": [
                "That sounds mentally exhausting when a thought keeps circling. Would it help to slow down and look at it together, or would you rather focus on calming your mind first?",
                "I hear you. When something keeps replaying, it can feel impossible to rest. Would you like to talk about the thought, or try a short grounding step first?",
                "That sounds tiring. Repeating thoughts can feel sticky and hard to shake off. What feels stronger right now — the thought itself, or the anxiety it creates?",
            ],
            "overthinking_support": [
                "That sounds mentally exhausting. When thoughts keep looping, it can help to slow the mind down through the body first. Would you like to try a short grounding step?",
                "I hear you. Overthinking can make the same problem feel bigger and heavier each time. Would it help to separate what you can control from what you can't?",
                "That sounds tiring. Let's not try to solve everything at once. What is the one thought that keeps repeating the most?",
            ],
            "sleep_support": [
                "That sounds exhausting, especially when your mind won't slow down at night. Would you like to try a simple wind-down breathing step?",
                "Sleep can become harder when your body is still carrying stress. We can try a small calming step first if you want.",
                "That sounds frustrating. Instead of forcing sleep, it may help to settle your body first. Would you like one gentle step?",
            ],

            # ── relationship ──────────────────────────────────
            "relationship_loss_support": [
                "That sounds really painful to worry about. What has been making you feel like the relationship might end?",
                "Relationship worries can feel very heavy. What happened recently that made you feel this way?",
                "That sounds scary to carry. Are you afraid something changed between you two, or is it more the fear of losing them?",
                "I hear you. Relationships can feel so fragile when something shifts. What's been going on between you?",
            ],

            # ── academic stressors ────────────────────────────
            "coding_pressure_support": [
                "Coding pressure can feel especially frustrating because one small bug can block everything. What part feels hardest — understanding the logic, fixing errors, or not knowing where to start?",
                "That makes sense. Coding can feel heavy when the problem is unclear. Is it more about bugs, deadline pressure, or feeling stuck with the logic?",
                "I hear you. When coding feels overwhelming, it helps to separate the problem. Are you stuck because of an error, confusing logic, or too much workload?",
            ],
            "exam_pressure_support": [
                "Exam stress can feel intense because there is pressure and uncertainty at the same time. What feels hardest — remembering content, lack of time, or fear of failing?",
                "That sounds heavy. Is the stress more about preparation, confidence, or the result?",
                "I hear you. Exams can make everything feel urgent. What part is weighing on you most?",
            ],
            "deadline_pressure_support": [
                "Deadlines can create a lot of pressure quickly. What feels heaviest — too much work, not enough time, or not knowing where to begin?",
                "That sounds stressful. Is it more about time running out, unfinished work, or feeling mentally drained?",
                "I hear you. When deadlines pile up, it can help to focus on one next step. What's the most urgent thing right now?",
            ],
            "presentation_pressure_support": [
                "Presentations can feel scary because you're being seen and evaluated. Is the hardest part speaking in front of people, fear of mistakes, or pressure to perform?",
                "That makes sense. Presentation anxiety is really common. What part feels strongest right now?",
                "I hear you. Is it more about nervousness, confidence, or worrying about what others think?",
            ],
            "group_work_pressure_support": [
                "Group work can feel draining when responsibility is uneven. Is the hardest part unfair workload, poor communication, or conflict with teammates?",
                "That sounds frustrating. Group stress is often about carrying more than your share. What's happening most right now?",
                "I hear you. Is it more about teammates not helping, deadline pressure, or tension in the group?",
            ],
            "academic_support": [
                "That sounds like a lot of pressure. What feels most urgent — the deadline, the workload, or the fear of not doing well?",
                "Academic stress can pile up quickly. What's the one task that feels heaviest at the moment?",
                "I hear you. When everything feels urgent, it helps to choose one small next step. What assignment or exam is stressing you most?",
            ],
            "family_pressure_support": [
                "Family pressure can feel heavy because it follows you even into your safe space. What feels hardest — expectations, arguments, or not feeling understood?",
                "That sounds draining. Is the pressure mostly from expectations, conflict, or feeling like your family doesn't understand you?",
                "I hear you. Family stress can be exhausting. What part of it feels most difficult today?",
            ],
            "money_stress_support": [
                "Money stress can feel really heavy because it affects daily life and future plans. What feels most urgent right now?",
                "That sounds stressful. Is it more about not having enough, upcoming payments, or worrying about the future?",
                "I hear you. Financial pressure can make everything feel tighter. What part is weighing on you most?",
            ],
            "self_comparison_support": [
                "Comparing yourself to others can make you feel like you're always behind, even when you're trying. What comparison has been hurting the most?",
                "That sounds painful. It can be hard when everyone else seems ahead. What makes you feel not good enough right now?",
                "I hear you. Feeling behind can be really discouraging. What area are you comparing yourself in most?",
            ],
            "low_motivation_support": [
                "That sounds draining. Sometimes low motivation is a sign you've been carrying too much. What feels hardest to begin right now?",
                "I hear you. When energy feels low, even small tasks can feel heavy. What feels most stuck today?",
                "That makes sense. Instead of forcing everything, we can start very small. What's one task you wish felt easier?",
            ],
            "focus_problem_support": [
                "Focus can be hard when your mind is overloaded. What usually pulls your attention away the most?",
                "That sounds frustrating. Is it more like mental tiredness, distractions, or anxious thoughts interrupting you?",
                "I hear you. When focus drops, it helps to reduce the task first. What are you trying to focus on right now?",
            ],

            # ── body / panic responses ────────────────────────
            "panic_body_symptom_followup": [
                "That sounds really uncomfortable. When your body reacts that strongly, it helps to settle it first. Would you like to try one small grounding step with me?",
                "That sounds intense in your body right now. Let's help your body slow down first. Would you like to try a quick calming step together?",
                "That sounds hard to sit with. Since it's showing up strongly in your body, we can try one simple grounding step first if you want.",
            ],
            "body_symptom_action": [
                "That sounds really uncomfortable. Since it's showing up strongly in your body, let's focus on easing that first. Would you like to try one slow breathing step with me?",
                "That sounds hard to sit with. Because it's showing up physically, we can help your body settle first. Would you like to do one grounding step together now?",
                "That physical feeling sounds intense. Let's slow it down gently. Would it help to try one small calming step together?",
            ],
            "body_symptom_probe": [
                "Okay, so it feels strongest in your body right now. What are you noticing most — shaking, tightness, chest pressure, or something else?",
                "Got it. Since it feels strongest in your body, what's standing out most — your hands, chest, breathing, or something else?",
                "Okay. Since it's showing up in your body, is it more like shaking, tightness, breathing discomfort, or something else?",
            ],
            "mixed_anxiety_followup": [
                "That makes sense. When it hits both your thoughts and your body at once, it can feel really overwhelming. What are you noticing more strongly — the physical tension, or the thoughts in your mind?",
                "That sounds like a lot to carry at once. Since it's showing up in both your mind and body, what feels strongest right now?",
            ],

            # ── body-mind mismatch ────────────────────────────
            "body_better_mind_worry_support": [
                "That makes sense. Your body may be settling a little, but your mind is still trying to solve the worry. What thought is staying with you most?",
                "That's a useful difference to notice. Your body feels a bit calmer, but the worry is still there. What's the main thing your mind keeps returning to?",
                "I hear you. Sometimes the body calms first, then the thoughts take longer. What feels unresolved in your mind right now?",
            ],
            "high_intensity_support": [
                "That sounds really intense right now. Let's slow this down and focus only on the next few seconds. Would you like to do one grounding step with me?",
                "I hear that it feels very strong. You don't have to solve everything immediately. Let's focus on helping your body settle first.",
                "That sounds overwhelming. For now, let's make the next step very small and steady.",
            ],
            "future_worry_support": [
                "That sounds like a heavy worry to carry. Sometimes when the body calms down, the mind starts focusing on unresolved problems again. What feels most unresolved right now?",
                "I hear that. It sounds like part of you is afraid things won't work out. What feels most important to deal with first?",
                "That makes sense. When something feels unfinished, the mind can keep holding onto it. What part is bothering you most?",
            ],

            # ── coping steps ──────────────────────────────────
            "deliver_coping_step": [
                "Okay. Let's do one small step together. Take one slow breath in, then breathe out gently. After that, name three things around you that feel solid or real right now.",
                "Alright. Put both feet on the ground, take one slow breath, and then tell me three things near you that you can notice clearly.",
                "Okay, we can do that together. Start with one slow breath, then name three objects around you that feel real and steady.",
            ],
            "next_calming_step": [
                "Okay, let's try one more gentle step. Let your shoulders drop, unclench your jaw, and breathe out slowly for longer than you breathe in. Tell me if that eases anything even a little.",
                "Alright, one more small step. Put a hand on your chest if that feels okay, take one slow breath in and a longer breath out. What do you notice after that?",
                "Okay. This time, let your hands rest, soften your shoulders, and take one slow inhale followed by a longer exhale. Tell me if your body feels any softer after that.",
                "Let's make this step even smaller. Notice your feet touching the floor, then slowly relax your hands. Stay there for one breath.",
                "Okay, try gently pressing your feet into the ground for a few seconds, then release. Notice whether your body feels even slightly steadier.",
                "This time, look around slowly and name one colour you can see, one sound you can hear, and one thing your body is touching right now.",
            ],
            "guided_breath_step": [
                "Okay, let's do one slow breath together. Breathe in gently through your nose for 4, hold for 2, and breathe out slowly for 6. When you finish, tell me if your body feels even a little softer.",
                "Alright, just one breath. In slowly, hold for a moment, and out gently. Tell me whether anything in your body feels a little less tight after that.",
                "Okay, stay with me for one breath. Slow inhale, gentle pause, then a long exhale. What do you notice in your body after that?",
            ],
            "stay_present_support": [
                "Okay. We can pause here for a moment. You don't need to explain anything else right now. Just let your hands rest and take one slow breath.",
                "I'm here with you. We don't need to fix it immediately. You can just stay with this moment gently for a bit.",
                "Okay. We can stay here for a moment. You are not alone in this.",
            ],

            # ── feedback on coping ────────────────────────────
            "evaluate_task": [
                "Thank you for trying that. Has anything softened a little, or does it still feel just as strong?",
                "You did well to pause and try that. Do you feel even a little lighter now, or about the same?",
                "Thank you for doing that with me. Does your body feel a bit calmer now, or still very tense?",
            ],
            "reinforce_small_progress": [
                "That small shift matters. Even a little change is still real. Would you like to try one more gentle step, or pause here for a moment?",
                "A little better is still important. We can stay with this calmer moment or try one more short grounding step.",
                "That's a good sign. Even small relief counts. Do you want another gentle step, or would you rather rest here?",
            ],
            "stabilize_partial_relief": [
                "It sounds like some of the intensity has eased, even if it hasn't fully gone yet. Would you like to stay with this calmer moment, or try one more gentle step?",
                "That sounds like a small but real shift. It doesn't have to disappear all at once. Do you want another short calming step, or would you rather stay here?",
                "It's okay if it's still there a little. The fact that it feels lighter matters. Would it help to take one more slow breath, or just stay here for a moment?",
            ],
            "respond_to_no_relief": [
                "That's okay. One step not helping right away doesn't mean you failed. Would you like to try another gentle grounding step?",
                "That makes sense. Sometimes it takes a few small steps before anything shifts. Should we try one more together?",
                "That's understandable. We can try a different calming step if you want — something even smaller.",
            ],
            "slow_down_support": [
                "It sounds like your body is still holding onto a lot right now. We don't have to keep forcing it. We can slow down and stay with one very small step.",
                "That makes sense. If it's not shifting much yet, we don't need to push harder. We can just stay with something gentler for a moment.",
                "It sounds like this is still sitting strongly in you. We don't have to solve it all at once. Let's keep things very small and steady.",
            ],
            "persistent_no_relief_support": [
                "I hear you. When nothing seems to shift, that can feel really discouraging. Let's stop trying to fix it for now — can we just sit together here for a moment?",
                "That sounds really hard. When the feeling won't move, sometimes the kindest thing is to stop pushing and just let yourself be with it. You're not alone in this.",
                "It's okay. We don't have to keep trying steps right now. Sometimes just being heard is the most important thing. What's weighing on you most underneath all of this?",
            ],

            # ── chronic ───────────────────────────────────────
            "deep_empathy_guided": [
                "That sounds exhausting, especially if it's been going on for a long time. Is there a time when it feels heaviest?",
                "Carrying this for so long sounds really tiring. When it peaks, what kind of thoughts usually come up?",
                "That sounds hard to deal with for such a long time. When it gets worse, do you notice it more in your body, your thoughts, or both?",
            ],
            "chronic_shift_to_body_or_thoughts": [
                "That unpredictability can make it even more draining. When it starts, do you notice it more in your thoughts, your body, or both?",
                "That sounds frustrating. When it happens, what do you usually notice first?",
                "That can feel really unsettling. Does it come with racing thoughts, chest tightness, or something else first?",
            ],

            # ── anxiety-specific ──────────────────────────────
            "anxiety_direct_open": [
                "I'm here with you. Is the anxiety showing up more in your thoughts, your body, or both right now?",
                "That sounds heavy. Is it feeling more like racing thoughts, physical tension, or both?",
                "I'm with you. When the anxiety comes up, do you notice it more in your mind, your body, or both?",
            ],
            "anxiety_body_or_thoughts_followup": [
                "That unpredictability can make it feel even harder to manage. When it starts, do you notice it more in your thoughts, your body, or both?",
                "That sounds really unsettling. What do you usually notice first when the anxiety starts?",
                "When it comes on, does it feel more like racing thoughts, chest tightness, or something else first?",
            ],
            "random_pattern_anxiety_support": [
                "That unpredictability can feel really unsettling. Since it shows up strongly in your body, we can focus on helping your body settle first. Would you like to try a quick grounding step with me now?",
                "That sounds hard, especially when you can't predict it. Because it hits your body so strongly, it makes sense to calm the body first. Would you like to try that together?",
                "That kind of unpredictability can make anxiety feel even more overwhelming. We can start with one small calming step if you want.",
            ],
            "random_pattern_followup": [
                "That unpredictability can make it even more draining. When it starts, do you notice it more in your thoughts, your body, or both?",
                "That sounds frustrating, especially when it feels random. What do you usually notice first when it starts?",
                "That can feel really unsettling. Does it usually begin with racing thoughts, chest tightness, or something else?",
            ],

            # ── short-answer handlers ─────────────────────────
            "validate_confirm": [
                "Okay, I'm with you. What feels strongest right now?",
                "Alright. What are you noticing most in this moment?",
                "Got it. Is it showing up more in your thoughts, your body, or both?",
            ],
            "soft_idk_response": [
                "That's okay. You don't need to have the perfect words. What feels heaviest right now?",
                "That's alright. Sometimes there are no words for it — what is your body doing right now?",
            ],
            "pure_validation": [
                "Living with that for a while can feel really exhausting.",
                "That sounds really tiring, especially when it keeps returning.",
                "It makes sense that this feels heavy.",
                "I hear you. You don't have to explain it any more than this.",
            ],
            "reflective_validation": [
                "It sounds like this is still sitting heavily with you.",
                "I can hear that this still feels difficult right now.",
                "That makes sense. Your body and mind both sound worn down from it.",
            ],
            "smart_clarification": [
                "I want to understand you properly. Could you tell me which feeling is strongest right now?",
                "It can be hard to find the words sometimes. What feels heaviest for you right now?",
                "Take your time. What's the one thing that feels most pressing in this moment?",
            ],

            # ── progress clarification ────────────────────────
            "clarify_progress_binary": [
                "I'm not fully sure what you mean by that. Does it feel a bit more manageable now, or is it still quite strong?",
                "Just to make sure I understand — is the feeling easing a little, or still hitting quite hard?",
            ],
            "clarify_short_yes": [
                "I want to make sure I understand you properly. Could you say a little more about what you mean?",
                "I'm with you. Can you tell me a bit more so I understand better?",
            ],
            "soft_positive_transition": [
                "I'm glad there may be a small shift there. Would you rather pause here for a moment, or try one more gentle step?",
                "That sounds like it may be easing a little. We can pause here, or take one more small step if you want.",
            ],

            # ── coping alternative ────────────────────────────
            "coping_alternative": [
                "It sounds really frustrating when it keeps coming back. Since forcing it away isn't helping, maybe we can focus on helping your body settle for a moment instead. How does that sound?",
                "That sounds discouraging. When coping steps don't seem to hold, it can help to stop forcing the feeling away and try something gentler. Would you be open to a slow grounding breath with me?",
            ],

            # ── solution suggestions ──────────────────────────
            "solution_suggestion_anxiety": [
                "When anxiety peaks, it can help to anchor your body first. Would you like to try one small grounding step with me right now?"
            ],
            "solution_suggestion_stress": [
                "When stress gets heavy, it can help to make the next step very small. What's one small thing that feels manageable for you today?"
            ],
            "solution_suggestion_general": [
                "When this feels overwhelming, grounding can sometimes create a little space. Would you be open to trying a short calming step right now?"
            ],

            # ── topic exploration ─────────────────────────────
            "topic_exploration_anxiety": [
                "Anxiety can feel intense when it hits. Does it feel more like racing thoughts or physical tension?",
                "That sounds frightening in the moment. Where do you usually feel it in your body?",
                "When it comes up, is it mostly in your mind, your body, or both?",
            ],
            "topic_exploration_burnout": [
                "Burnout can drain everything. Are you finding it harder to start things, or do you feel more mentally exhausted than anything else?",
                "That sounds heavy. Is it more like emotional exhaustion, or like your motivation has completely gone?",
            ],
            "topic_exploration_stress": [
                "Stress can make everything feel crowded at once. What's been putting the most pressure on you lately?",
                "That sounds overwhelming. Is the stress coming from one main thing, or is it a lot of things piling up?",
            ],
            "topic_exploration_loneliness": [
                "That kind of loneliness can feel really isolating. Has it been more recent, or has it been there for a while?",
                "I hear you. Feeling alone can be really painful. What makes it feel most lonely?",
            ],
            "topic_exploration_general": [
                "I see. Tell me a bit more about what's going on.",
                "Got it. What else is on your mind regarding that?",
                "I'm listening. How has that been for you lately?",
            ],

            # ── soft escalation (sustained distress) ─────────
            "soft_escalation_support": [
                "It sounds like this has been really weighing on you for a while now. I want you to know you don't have to carry this alone. Would it help to slow things down and try a very gentle grounding step together?",
                "I can hear how much you've been struggling, and I'm genuinely concerned. When things feel this heavy for this long, sometimes the kindest thing is to take one very small step. Would you like to try that with me?",
                "That sounds really exhausting to keep holding. You've been sitting with this for a while and it hasn't lifted much. Would you like to pause everything else and just focus on one small moment of calm together?",
            ],

            # ── topic shift acknowledgement ───────────────────
            "topic_shift_acknowledgement": [
                "It sounds like something new is coming up — I want to make sure I'm following you. Are you moving away from [topic], or did something new just come up on top of it?",
                "I notice the focus may have shifted a little. Is [topic] still what's weighing on you most, or is something else coming up now?",
                "That sounds like it may be connected to something different. Are we still on [topic], or is this a new thing that's come up?",
            ],

            # ── symptom-specific coping steps ─────────────────
            "grounding_tactile_step": [
                "Since your hands are shaking, let's bring your attention into your body. Press your feet flat on the floor, then slowly press your palms together and hold for five seconds. Tell me if the shaking eases even a little.",
                "Let's slow the shaking down gently. Press both hands into your thighs firmly, take one slow breath, and focus on the pressure and warmth. Tell me what you notice after that.",
                "Okay. Slowly rub the palms of your hands together and focus on the warmth and friction. Do that for ten seconds, then let your hands rest. Does anything in your body feel slightly steadier?",
            ],
            "chest_release_step": [
                "Since your chest feels tight, let's loosen it gently. Sit back, let your shoulders drop, take a slow breath in through your nose, and then breathe out through your mouth for longer than you breathed in. Tell me if that softens the tightness at all.",
                "Let's ease that chest pressure together. Breathe in slowly for four counts, hold for two, then breathe out for six. Focus only on the release on the way out. What do you notice after?",
                "Okay. Roll your shoulders back gently, open your chest a little, and take one very slow breath out first before breathing in. Does the tightness shift at all?",
            ],
            "orientation_step": [
                "Since you're feeling dizzy, let's anchor you. Keep your eyes open and find one fixed point in the room to focus on. Press your feet into the floor and take one slow breath. Tell me how that feels.",
                "Let's steady you gently. Sit down if you can, press your back into the chair, and name five things you can see around you right now. What can you see?",
                "Okay. Look straight ahead and find something still to focus on. Take three slow breaths while keeping your eyes on it. Does the dizziness ease at all?",
            ],
            "cool_down_grounding": [
                "Since sweating is one of the things you're noticing, let's help your body cool slightly. If you can, press the inside of your wrists against something cool. Then take one slow breath out. Does anything shift?",
                "Let's ease that physical feeling gently. Slow your breath down first — breathe out for longer than you breathe in, and if possible, let some cool air reach your face or wrists. Tell me if anything settles.",
                "Okay. Let's slow the physical reaction down. Press your feet into the floor, breathe out slowly, and if you can, hold something cool. What do you notice after a moment?",
            ],
        }

        # ── merge from JSON if it exists (JSON wins for any non-empty list) ──
        if os.path.exists(responses_path):
            try:
                with open(responses_path, "r", encoding="utf-8") as f:
                    loaded = json.load(f)
                # detect and warn on duplicate keys (JSON itself allows, Python last-wins)
                if isinstance(loaded, dict):
                    for key, value in loaded.items():
                        if isinstance(value, list) and value:
                            defaults[key] = value
            except Exception as e:
                print(f"[WARN] Could not load {responses_path}: {e}")

        return defaults

    def _pick(
        self,
        key: str,
        tracker: "UserContextTracker",
        fallback: str = "I am here with you, and I am listening.",
    ) -> str:
        options = self.responses.get(key, [])
        if not options:
            return fallback

        valid_options = list(options)
        
        # ── 1. Check if user just answered our last question ──
        # (This is handled conceptually upstream, but we can prevent
        # asking the exact same text again by filtering recent responses)
        recent_texts = [r.get("text", "") for r in tracker.recent_bot_responses]
        filtered_options = [opt for opt in valid_options if opt not in recent_texts]
        
        if not filtered_options:
            # Fallback if everything was recently used
            filtered_options = valid_options
            if tracker.previous_response in filtered_options and len(filtered_options) > 1:
                filtered_options.remove(tracker.previous_response)

        choice = random.choice(filtered_options)

        # ── [topic] placeholder substitution ─────────────────
        if "[topic]" in choice:
            entity = tracker.current_entity or tracker.topic or "this"
            choice = choice.replace("[topic]", entity)

        # ── 2. Track this response in session memory ──────────
        tracker.recent_bot_responses.append({"text": choice, "category": key})
        if len(tracker.recent_bot_responses) > 5:
            tracker.recent_bot_responses.pop(0)

        # ── 3. Track if this is a question ────────────────────
        if "?" in choice:
            tracker.last_bot_question = {
                "text": choice,
                "intent_slot": key,
                "topic": tracker.topic,
                "answered": False
            }

        return choice

    # ── question ratio is now stage-specific, since each stage has a different
    # natural tendency to ask (exploration investigates; encouragement mostly
    # just affirms) rather than one global ratio applied everywhere ──────────
    STAGE_QUESTION_PROBABILITY = {
        "validation": 0.5,
        "reflection": 0.35,
        "exploration": 0.8,
        "encouragement": 0.3,
        "problem_solving": 0.6,
    }

    ENTITY_ALIASES_WORK = ["it", "the project", "that part of the work"]
    ENTITY_ALIASES_GENERIC = ["it", "the situation", "that part of it"]

    def _should_ask_question(self, stage: Optional[str], tracker: "UserContextTracker") -> bool:
        if tracker.consecutive_questions >= 2:
            return False
        prob = self.STAGE_QUESTION_PROBABILITY.get(stage, 0.5)
        return random.random() < prob

    def _resolve_entity_for_turn(self, tracker: "UserContextTracker") -> Optional[str]:
        """Fade a repeated literal entity ("your backend", "your backend"...) into a
        generic alias after a couple of consecutive mentions, then let it return."""
        raw_entity = tracker.current_entity or (tracker.topic if tracker.topic != "general" else None)
        if not raw_entity:
            tracker.entity_mention_streak = 0
            return "this"

        if raw_entity != tracker.last_literal_entity:
            tracker.last_literal_entity = raw_entity
            tracker.entity_mention_streak = 0

        if tracker.entity_mention_streak >= 2:
            pool = (
                self.ENTITY_ALIASES_WORK
                if tracker.current_situation in ("academic", "career")
                else self.ENTITY_ALIASES_GENERIC
            )
            alias_pool = [a for a in pool if a != tracker.last_entity_alias] or pool
            alias = random.choice(alias_pool)
            tracker.last_entity_alias = alias
            tracker.entity_mention_streak = 0
            return alias

        tracker.entity_mention_streak += 1
        return raw_entity

    def _generate_via_component_engine(
        self,
        state: Dict[str, str],
        tracker: "UserContextTracker",
        action_options: Optional[List[str]] = None,
        stage_override: Optional[str] = None,
    ) -> Tuple[str, bool]:
        """Shared ComponentNLGEngine call used by both the main STRATEGY_MAP
        routing and solution_suggestion's practical-overwhelm path. Returns
        (response_text, has_question)."""
        entity = self._resolve_entity_for_turn(tracker)
        # tracker.conversation_stage already holds the *next* turn's stage by
        # this point (compute_strategy's stage_engine.advance() ran already) --
        # state["active_stage"] is the value that applies to THIS turn's reply.
        stage = stage_override or state.get("active_stage", tracker.conversation_stage)
        ask_question = self._should_ask_question(stage, tracker)
        choice_options = None
        if state.get("choice_option_a") and state.get("choice_option_b"):
            choice_options = (state["choice_option_a"], state["choice_option_b"])
        response, used_phrases, used_categories = self.component_engine.generate_response(
            emotion_intent=state.get("intent", ""),
            topic_entity=entity,
            stage=stage,
            meaning_shift=state.get("meaning_shift"),
            event_category=state.get("event_category") or tracker.current_event_category,
            action_options=action_options,
            event_phrase=tracker.current_event,
            repetition_cue=state.get("repetition_cue", False),
            progress_detail=state.get("progress_detail") or tracker.current_progress_detail,
            choice_options=choice_options,
            has_evidence=tracker.technical_failure_evidence,
            new_info=state.get("new_info", False),
            recent_phrases=tracker.recent_component_phrases,
            recent_categories=tracker.recent_observation_categories,
            ask_question=ask_question,
        )
        tracker.recent_component_phrases.extend(used_phrases)
        if len(tracker.recent_component_phrases) > 8:
            tracker.recent_component_phrases = tracker.recent_component_phrases[-8:]
        tracker.recent_observation_categories.extend(used_categories)
        if len(tracker.recent_observation_categories) > 2:
            tracker.recent_observation_categories = tracker.recent_observation_categories[-2:]
        tracker.last_response_mode = "question" if ask_question else "statement"

        has_question = "?" in response
        if has_question:
            tracker.last_bot_question = {
                "text": response, "intent_slot": stage, "topic": tracker.topic, "answered": False,
            }
        return response, has_question

    def generate(
        self,
        strategy: str,
        state: Dict[str, str],
        tracker: "UserContextTracker",
    ) -> Tuple[str, Optional[str]]:
        topic = state.get("topic", "general")

        # strategy → (response_key, question_type)
        STRATEGY_MAP: Dict[str, Tuple[str, Optional[str]]] = {
            # session
            "escalation":                       ("crisis",                          None),
            "greeting":                         ("greeting",                        None),
            "close":                            ("close",                           None),
            "graceful_close_or_continue":       ("graceful_close_or_continue",      None),
            # mood
            "strong_negative_support":          ("strong_negative_support",         "open_emotion"),
            "negative_checkin_support":         ("negative_checkin_support",        "open_emotion"),
            "anger_frustration_support":        ("anger_frustration_support",       "open_emotion"),
            "sadness_support":                  ("sadness_support",                 "open_emotion"),
            "confusion_support":                ("confusion_support",               "open_emotion"),
            "guilt_shame_support":              ("guilt_shame_support",             "open_emotion"),
            "emptiness_support":                ("emptiness_support",               "open_emotion"),
            "friendship_pressure_support":      ("friendship_pressure_support",     "open_emotion"),
            "social_anxiety_support":           ("social_anxiety_support",          "open_emotion"),
            "self_esteem_support":              ("self_esteem_support",             "open_emotion"),
            "future_uncertainty_support":       ("future_uncertainty_support",      "open_emotion"),
            # cognitive
            "looping_thoughts_support":         ("looping_thoughts_support",        "choice"),
            "overthinking_support":             ("overthinking_support",            "choice"),
            "sleep_support":                    ("sleep_support",                   "choice"),
            # stressors
            "relationship_loss_support":        ("relationship_loss_support",       "open_emotion"),
            "coding_pressure_support":          ("coding_pressure_support",         "open_emotion"),
            "exam_pressure_support":            ("exam_pressure_support",           "open_emotion"),
            "deadline_pressure_support":        ("deadline_pressure_support",       "open_emotion"),
            "presentation_pressure_support":    ("presentation_pressure_support",   "open_emotion"),
            "group_work_pressure_support":      ("group_work_pressure_support",     "open_emotion"),
            "academic_support":                 ("academic_support",                "open_emotion"),
            "family_pressure_support":          ("family_pressure_support",         "open_emotion"),
            "money_stress_support":             ("money_stress_support",            "open_emotion"),
            "self_comparison_support":          ("self_comparison_support",         "open_emotion"),
            "low_motivation_support":           ("low_motivation_support",          "open_emotion"),
            "focus_problem_support":            ("focus_problem_support",           "open_emotion"),
            "future_worry_support":             ("future_worry_support",            "open_emotion"),
            "body_better_mind_worry_support":   ("body_better_mind_worry_support",  "open_emotion"),
            "high_intensity_support":           ("high_intensity_support",          "choice"),
            # body / panic
            "panic_body_symptom_followup":      ("panic_body_symptom_followup",     "choice"),
            "body_symptom_action":              ("body_symptom_action",             "choice"),
            "body_symptom_probe":               ("body_symptom_probe",              "body"),
            "mixed_anxiety_followup":           ("mixed_anxiety_followup",          "body_vs_thoughts"),
            # coping
            "deliver_coping_step":              ("deliver_coping_step",             "grounding_items"),
            "next_calming_step":                ("next_calming_step",               "exercise_feedback"),
            "guided_breath_step":               ("guided_breath_step",              "exercise_feedback"),
            "stay_present_support":             ("stay_present_support",            None),
            "evaluate_task":                    ("evaluate_task",                   "exercise_feedback"),
            "reinforce_small_progress":         ("reinforce_small_progress",        "choice"),
            "stabilize_partial_relief":         ("stabilize_partial_relief",        "choice"),
            "respond_to_no_relief":             ("respond_to_no_relief",            "choice"),
            "slow_down_support":                ("slow_down_support",               None),
            "persistent_no_relief_support":     ("persistent_no_relief_support",    "open_emotion"),
            "coping_alternative":               ("coping_alternative",              "choice"),
            # chronic / deep
            "deep_empathy_guided":              ("deep_empathy_guided",             "timing"),
            "chronic_shift_to_body_or_thoughts":("chronic_shift_to_body_or_thoughts","body_vs_thoughts"),
            # anxiety-specific
            "anxiety_direct_open":              ("anxiety_direct_open",             "body_vs_thoughts"),
            "anxiety_body_or_thoughts_followup":("anxiety_body_or_thoughts_followup","body_vs_thoughts"),
            "random_pattern_anxiety_support":   ("random_pattern_anxiety_support",  "choice"),
            "random_pattern_followup":          ("random_pattern_followup",         "open_emotion"),
            # check-in / short
            "explore_checkin":                  ("explore_checkin",                 "open_emotion"),
            "gentle_pivot":                     ("gentle_pivot",                    None),
            "open_chat":                        ("open_chat",                       "open_emotion"),
            "validate_confirm":                 ("validate_confirm",                "clarify"),
            "soft_idk_response":                ("soft_idk_response",               "open_emotion"),
            "pure_validation":                  ("pure_validation",                 None),
            "reflective_validation":            ("reflective_validation",           None),
            "smart_clarification":              ("smart_clarification",             "clarify"),
            "soft_positive_transition":         ("soft_positive_transition",        "choice"),
            "clarify_progress_binary":          ("clarify_progress_binary",         "binary_progress"),
            "clarify_short_yes":                ("clarify_short_yes",               "clarify"),
            # escalation / distress path
            "soft_escalation_support":          ("soft_escalation_support",         "open_emotion"),
            "topic_shift_acknowledgement":      ("topic_shift_acknowledgement",     "open_emotion"),
            # symptom-specific coping
            "grounding_tactile_step":           ("grounding_tactile_step",          "exercise_feedback"),
            "chest_release_step":               ("chest_release_step",              "exercise_feedback"),
            "orientation_step":                 ("orientation_step",                "exercise_feedback"),
            "cool_down_grounding":              ("cool_down_grounding",             "exercise_feedback"),
            # missing academic/activity mappings
            "academic_explore_strategy":        ("academic_explore_strategy",       "open_emotion"),
            "answer_acknowledgement_strategy":  ("answer_acknowledgement_strategy", "open_emotion"),
            "clarify_uncertain":                ("clarify_uncertain",               "clarify"),
            # ambiguity / topic-shift (previously fell through to the absolute fallback)
            "low_engagement_strategy":          ("low_engagement_strategy",         None),
            "topic_shift_neutral_strategy":     ("topic_shift_neutral_strategy",    "open_emotion"),
            "topic_shift_emotion_strategy":     ("topic_shift_emotion_strategy",    "open_emotion"),
            # pending-action confirmation
            "offer_grounding":                  ("offer_grounding",                 "choice"),
            "acknowledge_decline_action":       ("acknowledge_decline_action",      None),
            # Answer Interpretation Layer
            "confirmed_both_strategy":          ("confirmed_both_strategy",         "open_emotion"),
            "confirmed_observation_strategy":   ("confirmed_observation_strategy",  "open_emotion"),
            "denied_observation_strategy":      ("denied_observation_strategy",     "open_emotion"),
            "partial_confirmation_strategy":    ("partial_confirmation_strategy",   "open_emotion"),
            # Clarification Intent Layer
            "explain_clarification":            ("explain_clarification",           "open_emotion"),
        }

        if strategy == "offer_grounding":
            tracker.pending_action = "grounding"
            tracker.awaiting_confirmation = True

        if strategy in STRATEGY_MAP:
            key, qtype = STRATEGY_MAP[strategy]

            # Use Component NLG Engine for emotions: composes content whose *shape*
            # follows the conversation stage (validate / summarize / investigate /
            # encourage / next-steps), reacts to meaning-shifts, fades repeated
            # entity mentions, and tracks anti-repetition (phrase + "flavor") via
            # the tracker.
            #
            # academic_explore_strategy and answer_acknowledgement_strategy are
            # included even though neither is a "_support" strategy:
            # - academic_explore_strategy: intent=academic_workload is reached for
            #   plain academic distress ("my backend keeps having problems") that
            #   lacks an explicit emotion keyword; its own question bank is
            #   specific/useful enough to keep, passed through as action_options.
            # - answer_acknowledgement_strategy: intent=answer_previous_question
            #   fires whenever the user directly answers our last question -- it
            #   must continue the SAME thread (acknowledge + follow up), not pivot
            #   to a generic canned line that discards what was just said.
            EXPLORE_BANK_KEYS = {"academic_explore_strategy"}
            # Answer Interpretation Layer strategies also need the rich,
            # context-aware composition (event/entity/category-aware elaboration,
            # stored choice options) rather than a static template bank.
            ANSWER_INTERPRETATION_KEYS = {
                "confirmed_both_strategy", "confirmed_observation_strategy",
                "denied_observation_strategy", "partial_confirmation_strategy",
                "explain_clarification",
            }
            if ((
                    "support" in key or key in EXPLORE_BANK_KEYS
                    or key == "answer_acknowledgement_strategy"
                    or key in ANSWER_INTERPRETATION_KEYS
                ) and hasattr(self, 'component_engine')):
                action_options = self.responses.get(key) if key in EXPLORE_BANK_KEYS else None
                response, has_question = self._generate_via_component_engine(
                    state, tracker, action_options=action_options
                )
                return response, (qtype if has_question else None)

            return self._pick(key, tracker), qtype

        # ── solution suggestion ────────────────────────────────
        # Genuine anxiety keeps the existing grounding-style choice offer
        # (Problem 4: emotional overwhelm -> grounding). Everything else
        # ("seeking_solutions" while discussing a project/deadline/bug) is
        # practical overwhelm -> route through the real problem-solving
        # content (blockers/breakdown/prioritization) instead of a generic
        # anxiety-flavored bank that doesn't know about the actual situation.
        if strategy == "solution_suggestion":
            if topic == "anxiety":
                return self._pick("solution_suggestion_anxiety", tracker), "choice"
            if hasattr(self, 'component_engine'):
                response, has_question = self._generate_via_component_engine(
                    state, tracker, stage_override="problem_solving"
                )
                return response, ("open_emotion" if has_question else None)
            return self._pick("solution_suggestion_general", tracker), "choice"

        # ── topic exploration (topic-dependent) ───────────────
        if strategy == "topic_exploration":
            key_map = {
                "anxiety": "topic_exploration_anxiety",
                "burnout": "topic_exploration_burnout",
                "stress": "topic_exploration_stress",
                "loneliness": "topic_exploration_loneliness",
            }
            key = key_map.get(topic, "topic_exploration_general")
            qtype = "body_vs_thoughts" if topic == "anxiety" else "open_emotion"
            return self._pick(key, tracker), qtype

        # ── absolute fallback ─────────────────────────────────
        return "I am here with you, and I am listening. Take your time.", None


# ============================================================
# SAFETY FILTER
# ============================================================
BANNED_TERMS = frozenset([
    "diagnosing", "schizophrenia", "bipolar", "prescribe",
    "medication", "pill", "antidepressant", "lithium",
])

DISCLAIMER = (
    "I'm a supportive companion, not a doctor. "
    "For medical or psychiatric concerns, please speak with a qualified professional."
)


def safety_filter(response: str) -> str:
    if any(term in response.lower() for term in BANNED_TERMS):
        return DISCLAIMER
    return response


# ============================================================
# ANSWER INTERPRETATION: classify the bot's own turn so a short reply next
# turn ("yes"/"both"/"not really") can be interpreted relative to it.
# ============================================================
NO_CONFIRMATION_STRATEGIES = {
    "escalation", "close", "greeting", "graceful_close_or_continue",
    "topic_shift_neutral_strategy", "topic_shift_emotion_strategy",
}


def classify_bot_turn(
    response_text: str, strategy: str,
    topic: Optional[str] = None, entity: Optional[str] = None, intent: Optional[str] = None,
) -> dict:
    """Classify the bot's outgoing turn: a binary/open question, an A-or-B
    CHOICE question (with both options extracted), or a plain statement.
    Statements count too -- an observation ("This seems like it's been about
    chasing bugs...") can be confirmed/denied just like a literal question.

    Conversation Commitment Layer: also records what the question was ABOUT
    (question_topic/question_entity/question_intent) so the next turn's
    fresh answer can be checked against what was actually being asked,
    instead of just persisted tracker state that may have moved on."""
    if strategy in NO_CONFIRMATION_STRATEGIES:
        return {
            "text": response_text, "kind": "none", "option_a": None, "option_b": None,
            "answered": True, "topic": topic, "entity": entity, "intent": intent,
        }

    has_question = "?" in response_text
    option_a = option_b = None

    if has_question:
        # The question is usually the final clause/sentence of the response.
        q = response_text.rstrip("?").strip()
        sentences = re.split(r'(?<=[.!])\s+', q)
        last_clause = sentences[-1] if sentences else q
        if " or " in last_clause.lower():
            idx = last_clause.lower().rfind(" or ")
            left = last_clause[:idx].strip()
            right = last_clause[idx + 4:].strip()
            left = re.sub(
                r'^(is it|is the|is this|was it|does it feel like|is that)\s+',
                '', left, flags=re.IGNORECASE,
            ).strip().rstrip(",")
            right = re.split(r',\s+(?:that|which)\b', right, maxsplit=1, flags=re.IGNORECASE)[0].strip()
            if left and right:
                option_a, option_b = left, right

    kind = "choice" if option_a else ("question" if has_question else "statement")
    return {
        "text": response_text, "kind": kind,
        "option_a": option_a, "option_b": option_b, "answered": False,
        "topic": topic, "entity": entity, "intent": intent,
    }


# ============================================================
# MAIN BOT
# ============================================================
class ProfessionalFYPBot:
    def __init__(self):
        print("\n" + "=" * 60)
        print("[AI] INITIALIZING EUNOIA HYBRID SUPPORT AI")
        print("=" * 60)
        self.nlu = AdvancedNLUPipeline()
        self.dialogue_manager = SmarterDialogueManager()
        self.generator = HumanResponseGenerator("responses.json")
        self.generator.component_engine = ComponentNLGEngine()
        
        # User session tracking
        self.trackers = {}
        self.firebase = FirebaseManager()

    def _get_tracker(self, user_id: str) -> UserContextTracker:
        if user_id not in self.trackers:
            self.trackers[user_id] = UserContextTracker()
            
            # Try load from firebase
            session_data = self.firebase.load_session(user_id)
            if session_data:
                self.trackers[user_id].topic = session_data.get("topic")
                self.trackers[user_id].turn_count = session_data.get("turn_count", 0)
        return self.trackers[user_id]

    def _save_tracker(self, user_id: str, tracker: UserContextTracker):
        session_data = {
            "topic": tracker.topic,
            "turn_count": tracker.turn_count,
            "last_active": "now", # Could be timestamp
        }
        self.firebase.save_session(user_id, session_data)

    def _handle_turn(self, user_id: str, user_input: str) -> Tuple[str, Dict[str, str], str]:
        """Process one user turn and return the bot response string."""
        tracker = self._get_tracker(user_id)
        
        state = self.nlu.analyze(user_input, tracker)
        
        # ── session reset on mid-conversation greeting ────────
        if state["intent"] == "greeting" and tracker.turn_count > 0:
            tracker.reset_for_new_session()
            
        strategy = self.dialogue_manager.compute_strategy(state, tracker)
        
        response, question_type = self.generator.generate(strategy, state, tracker)
        response = safety_filter(response)
        tracker.last_bot_turn = classify_bot_turn(
            response, strategy,
            topic=state.get("topic"), entity=tracker.current_entity, intent=state.get("intent"),
        )

        tracker.update(
            user_text=user_input,
            intent=state["intent"],
            topic=state["topic"],
            bot_text=response,
            strategy=strategy,
            question_type=question_type,
        )
        
        self._save_tracker(user_id, tracker)
        
        return response, state, strategy

    def run(self):
        print("\n[READY] Type 'exit' to end the session.\n")
        print("Bot: Hello! I'm here with you. How are you feeling today?\n")

        while True:
            try:
                user_input = input("You: ").strip()

                if not user_input:
                    continue

                if user_input.lower() in ["exit", "quit"]:
                    print("\nBot: Thank you for sharing with me today. Take care of yourself.")
                    break

                response, state, strategy = self._handle_turn("cli_user", user_input)

                # debug line — remove or guard with a flag in production
                print(
                    f"  [DEBUG] intent={state['intent']} | "
                    f"topic={state['topic']} | strategy={strategy} | "
                    f"stage={state.get('active_stage')}"
                )
                print(f"\nBot: {response}\n")

            except KeyboardInterrupt:
                print("\n\nBot: Take care. I'm here whenever you need.")
                break


if __name__ == "__main__":
    chatbot = ProfessionalFYPBot()
    chatbot.run()