import os
import re
import json
import random
import warnings
from dataclasses import dataclass, field
from typing import Optional, Tuple, Dict, List

import torch
import nltk
from nltk.sentiment.vader import SentimentIntensityAnalyzer

from custom_model import CustomNeuralNet
from topic_extractor import TopicExtractor
from nlg_engine import ComponentNLGEngine
from firebase_manager import FirebaseManager
from stage_engine import ConversationStageEngine, RELATIONSHIP_DECISION_TOPICS, RELATIONSHIP_DECISION_REPEAT_THRESHOLD

warnings.filterwarnings("ignore")
nltk.download("vader_lexicon", quiet=True)


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
class AttentionState:
    """Attention Lock System: once the user introduces a more specific topic
    (backend, supervisor feedback, a relationship conflict, etc.), this holds
    conversational attention on it for several turns so the bot keeps
    building on it instead of reverting to whatever generic category
    (deadline/workload) it was discussing before."""
    focus_topic: Optional[str] = None     # short label, e.g. "backend"
    focus_entity: Optional[str] = None    # full noun phrase, e.g. "your core tech and backend stuff"
    focus_event: Optional[str] = None     # verb-phrase event tied to the focus, if any
    focus_domain: Optional[str] = None    # category key, e.g. "technical" (-> technical_implementation)
    lock_strength: float = 0.0
    lock_turns_remaining: int = 0


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
    conversation_stage: str = "validation"  # validation/reflection/exploration/synthesis/encouragement/problem_solving
    stage_turns: int = 0                    # turns spent in the current stage
    current_situation: Optional[str] = None # explicit situation slot (mirrors topic/topic category)
    # Counts consecutive turns where the user expresses a relationship
    # stay-or-leave dilemma (topic in relationship_uncertainty/
    # fear_of_breakup) -- once it repeats, the stage engine fast-tracks to
    # problem_solving instead of waiting for the normal exploration ->
    # synthesis -> encouragement progression (see ConversationStageEngine).
    relationship_decision_repeat_count: int = 0
    current_event: Optional[str] = None     # lightweight event phrase, e.g. "revise your proposal"
    current_event_category: Optional[str] = None  # technical/deadline/supervisor_feedback/relationship/family/academic
    current_progress_detail: Optional[str] = None  # e.g. "completed 30 modules, 10 left"
    technical_failure_evidence: bool = False  # bug/debug/error/crash actually mentioned (Assumption Safety Layer)
    emotional_evidence: bool = False  # stress/exhaustion/frustration/anxiety etc. actually expressed (Assumption Safety Layer) -- topic mention alone never sets this
    recent_component_phrases: List[str] = field(default_factory=list)  # ComponentNLGEngine anti-repetition
    last_response_mode: Optional[str] = None  # last question-ratio mode used (avoid back-to-back repeats)
    recent_observation_categories: List[str] = field(default_factory=list)  # avoid same "flavor" twice in a row
    attention: AttentionState = field(default_factory=AttentionState)  # Attention Lock System

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

    # ── Safety Override Layer: tracks whether the bot just asked the
    # crisis-check question ("are you having thoughts about hurting
    # yourself...") so the very next reply is resolved against THAT
    # question first -- before any other classification layer runs. ──
    awaiting_crisis_followup: bool = False
    last_crisis_phrase: Optional[str] = None

    # ── Persistent Crisis Mode: once a crisis signal fires, this stays True
    # across MULTIPLE turns (not just the immediate next reply) so a vague,
    # low-content, or topic-shifting message ("who, there's no one", "I
    # don't know", "whatever") can never fall back into normal intent
    # classification -- answer_previous_question, clarify_uncertain,
    # greeting, casual chat, and topic continuity all stay suppressed while
    # this is True. Cleared only after several consecutive stable turns. ──
    crisis_mode: bool = False
    crisis_level: int = 0          # 1 = ambiguous risk, 2 = explicit/emergency
    crisis_stable_turns: int = 0   # consecutive turns showing real stability

    # ── Crisis Stage Engine: a finer-grained severity tier than crisis_level,
    # used to choose response framing/content within Persistent Crisis Mode.
    # 0=normal 1=concern 2=self_harm 3=suicidal_ideation 4=imminent_danger.
    # Never downgraded immediately -- decays at most one tier per consecutive
    # stable turn (see analyze()), and only escalates on genuine new evidence. ──
    crisis_stage: int = 0
    crisis_hotline_shown: bool = False  # the full hotline/resource message is shown once per session; afterwards adaptive composition takes over
    crisis_clarify_shown: bool = False  # the stage-1 "what do you mean" canned message is shown once per session; afterwards adaptive composition takes over

    # ── Crisis Cooldown: after sustained stability, crisis support tapers
    # off gradually over several turns rather than snapping back to normal
    # conversation immediately. ──
    in_crisis_cooldown: bool = False
    crisis_cooldown_turns: int = 0

    # ── Crisis emotional memory: sticky facts already disclosed during a
    # crisis conversation, so the bot never re-asks for information it
    # already has (e.g. "do you have anyone?" after the user already said
    # "there's no one") and can broaden/avoid certain response content
    # (contradiction awareness). ──
    recent_loneliness: bool = False
    recent_hopelessness: bool = False
    recent_fears: bool = False

    # ── Crisis response rotation memory: separate from recent_bot_responses
    # (whole-message anti-repeat) -- tracks individual template FRAGMENTS
    # used across the last few crisis turns, and the literal last crisis
    # question asked, so the same question is never repeated back-to-back. ──
    recent_crisis_phrases: List[str] = field(default_factory=list)
    last_crisis_question: Optional[str] = None

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

    # ── Pending-Question Type Binding: when the bot asks a CASUAL question
    # ("How's your day been so far?"), this stores what TYPE of question it
    # was (day_status/emotion/recent_activity/...), not just its topic/entity.
    # A short reply ("so far okay") is then answered against this TYPE,
    # instead of being bound to whatever stale entity happens to be sitting
    # in tracker.current_entity -- which is how "I just came to chat" -> a
    # spaCy noun-chunk mis-parse of "chat" -> "Chat is what's been keeping
    # you busy" happened. ──────────────────────────────────────────────────
    pending_question: dict = field(default_factory=lambda: {
        "type": None, "topic": None, "text": "", "answered": True,
    })

    # ── Casual followup anti-repeat: avoids asking about the same small-talk
    # category (food/weather/games/...) twice in a row during extended
    # casual conversation. ──────────────────────────────────────────────────
    recent_casual_categories: List[str] = field(default_factory=list)

    DISTRESS_WEIGHT = {
        "emergency_crisis": 10, "crisis_risk": 9, "crisis_followup": 8, "physical_panic": 8,
        "repeated_no_relief": 7, "chronic_distress": 6, "strong_negative_mood": 5,
        "crisis_risk_denied": 4, "sadness": 3,
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
        self.relationship_decision_repeat_count = 0
        self.current_situation = None
        self.current_event = None
        self.current_event_category = None
        self.current_progress_detail = None
        self.technical_failure_evidence = False
        self.emotional_evidence = False
        self.last_bot_turn = {
            "text": "", "kind": "statement", "option_a": None, "option_b": None,
            "answered": True, "topic": None, "entity": None, "intent": None,
        }
        self.pending_question = {"type": None, "topic": None, "text": "", "answered": True}
        self.recent_casual_categories = []
        self.recent_component_phrases = []
        self.last_response_mode = None
        self.recent_observation_categories = []
        self.attention = AttentionState()

        self.entity_mention_streak = 0
        self.last_literal_entity = None
        self.last_entity_alias = None

        self.pending_action = None
        self.awaiting_confirmation = False

        self.awaiting_crisis_followup = False
        self.last_crisis_phrase = None

        self.crisis_mode = False
        self.crisis_level = 0
        self.crisis_stable_turns = 0
        self.crisis_stage = 0
        self.crisis_hotline_shown = False
        self.crisis_clarify_shown = False
        self.in_crisis_cooldown = False
        self.crisis_cooldown_turns = 0
        self.recent_loneliness = False
        self.recent_hopelessness = False
        self.recent_fears = False
        self.recent_crisis_phrases = []
        self.last_crisis_question = None

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
        elif intent in ["session_close", "greeting", "emergency_crisis", "crisis_risk", "crisis_followup"]:
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
        self.sia = SentimentIntensityAnalyzer()

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

    # Discourse-filler interjections ("ermm", "like", "i guess", "sort of",
    # "kind of", "maybe") that pad out a message without adding real content
    # for the BiLSTM classifier, which otherwise reads enough of them as
    # unknown/noise tokens to tank its confidence below the "uncertain"
    # threshold on perfectly understandable venting. normalize_text() above
    # only strips a leading erm/umm/uh/hmm/well/actually/maybe run -- this
    # additionally covers "like"/"i guess"/"sort of"/"kind of", and applies
    # after every clause boundary (start of string, or right after a comma/
    # semicolon/colon/period), not just the very first one. It deliberately
    # does NOT match mid-clause ("feel like", "kind of person") so the real
    # content those phrases carry is never touched -- and it's only ever
    # used to build the BiLSTM's input, never the shared `clean` text that
    # every rule-based keyword match in this file still runs against.
    CLASSIFICATION_FILLER_RE = re.compile(
        r'(^|[,;:.])\s*(?:erm+|umm?|uhh?|hmm+|like|i guess|sort of|kind of|maybe)\b,?\s*',
        re.IGNORECASE,
    )

    def _strip_classification_fillers(self, text: str) -> str:
        def _repl(m: "re.Match") -> str:
            boundary = m.group(1)
            return f"{boundary} " if boundary else " "
        stripped = self.CLASSIFICATION_FILLER_RE.sub(_repl, text)
        return re.sub(r"\s+", " ", stripped).strip(" ,.!?;:")

    def _is_near_empty_after_fillers(self, clean: str) -> bool:
        """True when `clean` reduces to at most one real word once every
        known discourse-filler/hedge phrase is stripped out -- "like...",
        "ermm...", "i guess...", "but then..." all qualify. Combines the
        clause-boundary discourse-filler stripper above (catches "like"/
        "i guess"/ermm-variants) with _strip_filler_phrases' broader
        particle list (catches "but"/"so"/"well" and elongated yes/no
        spellings) so a message that's genuinely just a trailing-off filler
        is recognized regardless of which filler vocabulary it uses. Used
        to stop these from being read as a confident answer/confirmation/
        entity, or from resetting an ongoing conversation into "uncertain"
        (see Priority 2 and the BiLSTM low-confidence branch below)."""
        stripped = self._strip_filler_phrases(self._strip_classification_fillers(clean))
        return len(stripped.split()) <= 1

    def tokenize(self, sentence: str) -> List[str]:
        sentence = self.normalize_text(sentence)
        sentence = self._strip_classification_fillers(sentence)
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

    # ============================================================
    # SAFETY OVERRIDE LAYER
    # ============================================================
    # Highest-priority gate in the entire pipeline (see analyze()). Crisis /
    # self-harm language in the user's CURRENT message must always win over
    # answer_previous_question, the attention lock, topic continuity, the
    # stage engine, and every fallback strategy below it. Checked as plain
    # substrings on the normalized text, same approach as the rest of this
    # rule-based layer.
    #
    # Two tiers, deliberately handled differently:
    # - CRISIS_EXPLICIT_PHRASES: unambiguous statements of suicidal intent or
    #   self-harm -> intent="emergency_crisis" -> direct crisis-resource
    #   response (existing "escalation" strategy/"crisis" response, unchanged).
    # - CRISIS_RISK_PHRASES: language that strongly *suggests* risk but isn't
    #   unambiguous ("I want to jump", "I can't do this anymore") ->
    #   intent="crisis_risk" -> "crisis_support" strategy, which validates and
    #   asks directly whether the user means self-harm, rather than assuming
    #   either way.
    CRISIS_EXPLICIT_PHRASES = [
        "suicide", "kill myself", "self harm", "end it all",
        "i want to die", "i don't want to live", "i dont want to live",
        "hurt myself", "i want to disappear forever",
        "want to end my life", "i'm going to hurt myself",
        "thinking to die", "thinking of dying", "thinking about dying",
        "i'm thinking to die", "im thinking to die",
    ]

    CRISIS_RISK_PHRASES = [
        "i want to jump",
        "i want to disappear",
        "everyone would be better without me",
        "everyone would be better off without me",
        "everyone is better off without me",
        "everyone is better without me",
        "i can't do this anymore", "i cant do this anymore",
        "i want to end everything",
        "there's no point anymore", "theres no point anymore",
        "i don't want to wake up", "i dont want to wake up",
        "i feel like giving up",
    ]

    # First-person trigger -> natural second-person echo, so the crisis_support
    # response can reflect the user's own words back ("When you say you want to
    # jump...") instead of echoing the raw first-person match phrase verbatim.
    CRISIS_RISK_ECHO = {
        "i want to jump": "you want to jump",
        "i want to disappear": "you want to disappear",
        "everyone would be better without me": "everyone would be better without you",
        "everyone would be better off without me": "everyone would be better off without you",
        "everyone is better off without me": "everyone is better off without you",
        "everyone is better without me": "everyone is better without you",
        "i can't do this anymore": "you can't do this anymore",
        "i cant do this anymore": "you can't do this anymore",
        "i want to end everything": "you want to end everything",
        "there's no point anymore": "there's no point anymore",
        "theres no point anymore": "there's no point anymore",
        "i don't want to wake up": "you don't want to wake up",
        "i dont want to wake up": "you don't want to wake up",
        "i feel like giving up": "you feel like giving up",
    }

    # ── Persistent Crisis Mode: once tracker.crisis_mode is True, it takes
    # several CONSECUTIVE turns showing one of these explicit safety/relief
    # confirmations before the conversation is allowed to exit crisis mode
    # and resume normal classification -- a single reassuring-sounding
    # message must not end it immediately (see analyze()).
    CRISIS_STABILITY_PHRASES = [
        "i'm safe", "im safe", "i feel safe", "i am safe",
        "i'm okay now", "im okay now", "i feel better", "i'm feeling better",
        "i'm not going to hurt myself", "im not going to hurt myself",
        "i talked to someone", "i'm with someone", "im with someone",
        "i feel calmer", "i'm calmer now", "i'm going to be okay",
        "i'm not in danger", "im not in danger",
    ]
    CRISIS_EXIT_STABLE_TURNS = 3
    # Problem 8: once stability is confirmed, crisis support stays active for
    # several more turns (tapering, not silent) before returning to normal.
    CRISIS_COOLDOWN_TURNS = 7

    # ════════════════════════════════════════════════════════════════
    # CRISIS STAGE ENGINE -- a finer-grained severity tier (0-4) layered on
    # top of the existing emergency_crisis/crisis_risk intents, used purely
    # to select RESPONSE FRAMING within Persistent Crisis Mode. Does not
    # change intent classification (CRISIS_EXPLICIT_PHRASES/CRISIS_RISK_
    # PHRASES and safety_override() above are unchanged and remain the
    # source of truth for intent).
    #   0 = normal, 1 = concern, 2 = self_harm,
    #   3 = suicidal_ideation, 4 = imminent_danger
    # ════════════════════════════════════════════════════════════════
    CRISIS_STAGE2_PHRASES = [
        "hurt myself", "self harm", "harm myself", "cut myself",
        "i'm going to hurt myself", "im going to hurt myself",
    ]
    CRISIS_STAGE3_PHRASES = [
        "kill myself", "suicide", "i want to die", "i don't want to live",
        "i dont want to live", "end it all", "want to end my life",
        "i want to disappear forever", "i want to end everything",
        "thinking to die", "thinking of dying", "thinking about dying",
        "i'm thinking to die", "im thinking to die",
    ]
    # Imminence cues only count as stage 4 when ALREADY at stage >= 2 this
    # turn -- on their own they're far too generic ("I have an exam
    # tonight") to ever be a standalone crisis signal.
    CRISIS_IMMINENCE_PHRASES = [
        "tonight", "right now", "today", "this morning", "this evening",
        "in a few minutes", "in an hour", "i have a plan", "i have the pills",
        "i have a rope", "going to do it now", "want to do it tonight",
        "want to do it now", "i'm going to do it", "im going to do it",
    ]

    def _detect_crisis_stage(self, clean: str, current_stage: int) -> int:
        """Returns the crisis_stage suggested by THIS message alone (0 if no
        signal). Caller combines with tracker.crisis_stage via max() so a
        single message can only ESCALATE, never silently downgrade -- decay
        is handled separately, gradually, on sustained stability."""
        stage = 0
        if any(p in clean for p in self.CRISIS_RISK_PHRASES):
            stage = max(stage, 1)
        if any(p in clean for p in self.CRISIS_STAGE2_PHRASES):
            stage = max(stage, 2)
        if any(p in clean for p in self.CRISIS_STAGE3_PHRASES):
            stage = max(stage, 3)
        effective = max(stage, current_stage)
        if effective >= 2 and any(p in clean for p in self.CRISIS_IMMINENCE_PHRASES):
            stage = max(stage, 4)
        return stage

    # ── Crisis emotional memory cues (Problem 3/7): contradiction-aware --
    # once any of these fire, the bot must stop suggesting "talk to your
    # friends" and never re-ask whether the user has someone to talk to. ──
    CRISIS_LONELINESS_PHRASES = [
        "no one", "noone", "nobody", "no friend", "no friends",
        "i'm alone", "im alone", "i am alone", "nobody understands me",
        "no body understands me", "there is no one", "theres no one",
        "there's no one", "i have no one", "i have no friend",
        "no one to talk to", "nobody to talk to", "no one understands",
    ]
    CRISIS_HOPELESSNESS_PHRASES = [
        "no point", "nothing works", "i give up", "why bother",
        "it's useless", "its useless", "i can't do this anymore",
        "i cant do this anymore", "there's no use", "theres no use",
        "i'm done trying", "im done trying", "nothing helps",
        "no point anymore",
    ]
    CRISIS_FEAR_PHRASES = [
        "i'm scared", "im scared", "i'm afraid", "im afraid",
        "i'm terrified", "im terrified", "scared of", "afraid of",
        "i'm so scared", "im so scared", "i'm frightened", "im frightened",
    ]

    def safety_override(self, clean: str) -> Tuple[Optional[str], Optional[str]]:
        """
        Runs before all other logic in analyze(). If the current message
        contains crisis or self-harm language, immediately return the
        matching intent (plus the phrase that triggered it) so it can never
        be reclassified as answer_previous_question, a greeting, casual
        conversation, or "ambiguous" by any lower-priority layer.
        """
        for phrase in self.CRISIS_EXPLICIT_PHRASES:
            if phrase in clean:
                return "emergency_crisis", phrase
        for phrase in self.CRISIS_RISK_PHRASES:
            if phrase in clean:
                return "crisis_risk", phrase
        return None, None

    # ════════════════════════════════════════════════════════════════
    # TOPIC != EMOTION SAFETY LAYER
    # ════════════════════════════════════════════════════════════════
    # Bare mentions of school/work nouns ("assignment", "class", "exam",
    # "coding", "deadline", "presentation", "group work") carry NO inherent
    # emotional valence on their own -- below, each *_kws list is split into
    # a STRONG tier (phrases that already encode real distress, e.g. "study
    # stress", "i scared i fail") which still fires the pressure intent
    # unconditionally, and a WEAK tier (bare topic nouns) which is routed
    # through _classify_topic_mention() instead. That helper looks for
    # genuine evidence elsewhere in the message: completion/achievement
    # language (-> "accomplishment"), explicit distress language (-> the
    # pressure intent, same as before), or neither (-> "neutral_checkin").
    # This stops "I finished some assignments" from being treated the same
    # as "I'm so stressed about my assignment".
    DISTRESS_EVIDENCE_KWS = [
        "stress", "stressed", "stressful", "overwhelm", "overwhelmed", "overwhelming",
        "anxious", "anxiety", "worried", "worry", "worrying", "nervous", "afraid",
        "scared", "fear", "exhausted", "exhausting", "drained", "burnt out",
        "burnout", "burning out", "hard", "difficult", "tough", "struggl",
        "can't cope", "cant cope", "too much", "too many", "pressure",
        "panick", "frustrat", "behind", "falling behind", "can't keep up",
        "cant keep up", "no time", "not enough time", "running out of time",
        "time running out", "can't handle", "cant handle", "can't focus",
        "cant focus", "cannot focus", "drowning", "breaking down",
        "can't take it", "cant take it", "losing it", "freaking out",
        "crying", "want to cry", "piling up", "pile up", "giving up",
        "no energy", "dread", "dreading", "miserable", "suffering",
        "rushing", "rush to",
    ]
    ACHIEVEMENT_EVIDENCE_KWS = [
        "finished", "finish", "completed", "complete", "submitted", "submit",
        "done with", "got done", "all done", "wrapped up", "got through",
        "cleared", "passed", "i did it", "finally submitted", "finally finished",
        "finally done", "checked off", "ticked off", "knocked out",
        "i'm proud", "im proud", "proud of myself", "made progress",
        "made some progress", "good progress", "managed to", "accomplished",
    ]
    # "finished"/"completed"/etc. flip meaning entirely under negation ("I
    # can't finish", "haven't completed it yet") -- any of these anywhere in
    # the message means the completion verbs above must NOT be read as
    # achievement evidence.
    NEGATION_KWS = [
        "can't", "cant", "couldn't", "couldnt", "haven't", "havent",
        "didn't", "didnt", "won't", "wont", "unable to", "not yet",
        "not able to", "never finished", "never completed",
    ]
    # Hedging about whether a task will actually get done ("not sure i can
    # finish my fyp or not", "dunno if i can", "might not finish") is worry,
    # not a confirmed accomplishment -- the completion verb inside one of
    # these is incidental, not evidence. Distinct from NEGATION_KWS above
    # (a flat "can't"/"haven't") because the verb itself ("can", "finish")
    # is still present; what flips the meaning is the surrounding hedge.
    CAPABILITY_HEDGE_KWS = [
        "not sure i can", "not sure if i can", "not sure whether i can",
        "not sure i could", "not sure i'll", "not sure ill",
        "dunno if i can", "dunno whether i can", "dunno if i'll", "dunno if ill",
        "don't know if i can", "dont know if i can",
        "don't know whether i can", "dont know whether i can",
        "might not finish", "might not be able to", "may not finish",
        "may not be able to", "might not manage", "might not make it",
    ]
    # The same hedge without a fixed leading phrase ("can i finish this or
    # not", "i can submit on time or not, idk").
    CAPABILITY_HEDGE_PATTERN = re.compile(r"\bcan\b[^.!?]{0,25}\bor not\b")
    # Laughter tacked onto an otherwise negative/uncertain clause ("...or not
    # haha") is masking, not genuine amusement -- must never flip sentiment
    # positive (see _classify_topic_mention), and nudges distress up
    # slightly instead (see _annotate_distress).
    MASKING_LAUGHTER_PATTERN = re.compile(
        r"\bha(?:ha)+h?\b|\blo+l+\b|\blm[fa]*o+\b|\bhe(?:he)+\b", re.IGNORECASE
    )

    def _has_distress_evidence(self, clean: str) -> bool:
        return any(kw in clean for kw in self.DISTRESS_EVIDENCE_KWS)

    def _has_capability_hedge(self, clean: str) -> bool:
        if any(kw in clean for kw in self.CAPABILITY_HEDGE_KWS):
            return True
        return bool(self.CAPABILITY_HEDGE_PATTERN.search(clean))

    def _has_masking_laughter(self, clean: str) -> bool:
        return bool(self.MASKING_LAUGHTER_PATTERN.search(clean))

    def _strip_masking_laughter(self, clean: str) -> str:
        stripped = self.MASKING_LAUGHTER_PATTERN.sub(" ", clean)
        return re.sub(r"\s+", " ", stripped).strip()

    def _has_achievement_evidence(self, clean: str) -> bool:
        if any(neg in clean for neg in self.NEGATION_KWS):
            return False
        if self._has_capability_hedge(clean):
            return False
        return any(kw in clean for kw in self.ACHIEVEMENT_EVIDENCE_KWS)

    def _classify_topic_mention(self, clean: str, pressure_intent: str) -> str:
        """A bare topic-noun mention (no inherent emotional valence) was
        matched -- decide what it actually means from evidence elsewhere in
        the message instead of assuming distress. Topic != emotion.

        Distress evidence is checked BEFORE achievement evidence: when a
        message mentions both ("so stressed about my assignment, don't know
        if I can finish it"), the actually-expressed distress must win over
        an incidental completion-flavored word. A capability hedge ("not
        sure i can finish... or not") is checked in the same tier as
        distress evidence, before achievement -- it's worry about the
        outcome, never a confirmed accomplishment, regardless of which
        completion verb happens to appear inside it.

        The DISTRESS_EVIDENCE_KWS list can't enumerate every way of phrasing
        a real problem ("my code keeps crashing", "this is killing me") --
        VADER sentiment is the fallback for genuinely negative phrasing that
        doesn't use one of the literal keywords, so this doesn't silently
        downgrade real distress to neutral just because of word choice.
        Masking laughter ("...or not haha") is stripped before that VADER
        check so it can't drag a genuinely negative/uncertain clause back
        up to neutral or positive."""
        if self._has_distress_evidence(clean):
            return pressure_intent
        if self._has_capability_hedge(clean):
            return pressure_intent
        if self._has_achievement_evidence(clean):
            return "accomplishment"
        sentiment_text = self._strip_masking_laughter(clean) if self._has_masking_laughter(clean) else clean
        if self.sia.polarity_scores(sentiment_text)["compound"] <= -0.2:
            return pressure_intent
        return "neutral_checkin"

    # ════════════════════════════════════════════════════════════════
    # CASUAL QUESTION TYPE CLASSIFIER -- used to tag the bot's OWN outgoing
    # casual-mode question (see tracker.pending_question) with what it's
    # actually asking about, so a short reply can be bound to that semantic
    # TYPE instead of to whatever stale entity happens to be sitting around.
    # ════════════════════════════════════════════════════════════════
    CASUAL_QUESTION_TYPE_PATTERNS = [
        ("progress", ["made any progress", "any progress", "progress on your",
                       "coming along", "how's it coming along"]),
        ("busy", ["busy lately", "been busy", "keeping you busy", "busy?"]),
        ("day_status", ["how's your day", "how was your day", "your day been",
                         "day going", "day so far", "today been"]),
        ("emotion", ["how are you feeling", "how do you feel", "feeling today",
                     "feeling right now", "how you feeling", "how are you"]),
        ("weekend", ["weekend"]),
        ("food", ["eat", "food"]),
        ("entertainment", ["watch", "movie", "show"]),
        ("hobbies", ["hobby", "hobbies", "free time"]),
        ("weather", ["weather"]),
        ("games", ["game", "games", "playing"]),
        ("music", ["music", "song", "songs", "listening to"]),
        ("memories", ["memorable", "memories", "memory"]),
        ("fyp", ["fyp", "final year project", "project coming along", "project going"]),
        ("recent_activity", ["been up to", "what's been going on", "whats been going on",
                              "anything interesting", "what happened", "what's new", "whats new",
                              "going on lately"]),
    ]

    def _classify_casual_question_type(self, text: str) -> str:
        t = text.lower()
        for qtype, kws in self.CASUAL_QUESTION_TYPE_PATTERNS:
            if any(kw in t for kw in kws):
                return qtype
        return "open"

    # ════════════════════════════════════════════════════════════════
    # ANSWER SEMANTICS -- classifies a short REPLY by its own grammatical
    # shape (yes_no/small_positive/small_negative/neutral/uncertain/
    # intensity/quantity), independent of the question's topic, so filler
    # particles ("ya", "abit", "okay", "hmm") are read as modifiers of that
    # shape instead of being handed to entity extraction. Returns "entity"
    # when the reply doesn't look like a short filler-laden answer at all --
    # the caller should then fall through to normal topic/entity extraction.
    # Priority, per spec: answer_semantics() -> entity_extraction() ->
    # generic_acknowledgement().
    # ════════════════════════════════════════════════════════════════
    FILLER_PARTICLES = {
        "ya", "yeah", "yep", "yup", "yes", "yea", "no", "nah", "nope", "hmm", "erm",
        "uh", "um", "okay", "ok", "abit", "maybe", "but", "only", "really",
        "and", "so", "well", "just", "kinda", "sorta",
    }
    SMALL_AMOUNT_KWS = [
        "a bit", "abit", "bit only", "a little", "a little bit", "a tad",
        "slightly", "kind of", "sort of", "kinda", "sorta",
    ]
    UNCERTAIN_KWS = [
        "maybe", "i guess", "not sure", "idk", "i don't know", "i dont know", "guess so",
    ]
    NEUTRAL_FILLER_KWS = ["okay", "ok", "alright", "fine", "so so", "soso", "decent"]
    AFFIRM_FILLER_KWS = ["ya", "yeah", "yep", "yup", "yes", "yea", "sure"]
    DENY_FILLER_KWS = ["no", "nah", "nope", "not really"]
    # Pronouns/light verbs/intensifiers that carry no entity content on
    # their own -- if everything left over after stripping fillers is made
    # of these, the reply is still describing the SAME thing the question
    # already asked about ("it keep raining"), not naming a new topic, so
    # it must never be handed to entity extraction (see answer_semantics()).
    LIGHT_CONTINUATION_WORDS = {
        "it", "this", "that", "there", "here", "they", "he", "she", "we",
        "him", "her", "them", "us",
        "still", "keep", "keeps", "kept", "going", "getting", "gets", "got",
        "been", "being", "is", "was", "are", "be", "very", "too",
        "lately", "today", "now", "again", "around", "out", "on",
    }

    @staticmethod
    def _collapse_repeated_letters(word: str) -> str:
        """'nopee' -> 'nope', 'yeaaa' -> 'yea', 'hmmmm' -> 'hm' -- collapses
        any run of the same letter down to one occurrence, so an elongated
        or fat-fingered spelling of a short filler word still matches its
        canonical form. Letter-elongation for emphasis/typos is effectively
        unbounded, so a fixed spelling list can never fully cover it."""
        return re.sub(r'(.)\1+', r'\1', word)

    def _elongation_match(self, core: str, keywords) -> bool:
        """any(kw in core for kw in keywords), additionally tolerant of
        letter-elongated spellings of single-word keywords -- "yeaaa"
        still satisfies "yeah", "nopee" still satisfies "nope". Multi-word
        entries are only matched as plain substrings (elongation lands on
        the short reaction word itself, not a whole phrase)."""
        if any(kw in core for kw in keywords):
            return True
        single_word_targets = {
            self._collapse_repeated_letters(kw) for kw in keywords if " " not in kw
        }
        if not single_word_targets:
            return False
        return any(
            self._collapse_repeated_letters(tok.strip(".,!?;:")) in single_word_targets
            for tok in core.split()
        )

    def _strip_filler_phrases(self, core: str) -> str:
        """Remove every known filler/amount/confirm/deny phrase from `core`
        and return what's left. Longest phrases first so multi-word entries
        ("a little bit") are removed whole before their substrings, then a
        second token-level pass catches letter-elongated single-word
        fillers ("nopee", "yeaaa") that survive the exact-phrase pass above
        since they don't match any fixed spelling."""
        phrase_set = (
            set(self.SMALL_AMOUNT_KWS) | set(self.UNCERTAIN_KWS)
            | set(self.NEUTRAL_FILLER_KWS) | set(self.AFFIRM_FILLER_KWS)
            | set(self.DENY_FILLER_KWS) | self.FILLER_PARTICLES
        )
        phrases = sorted(phrase_set, key=len, reverse=True)
        remainder = core
        for phrase in phrases:
            remainder = re.sub(rf'\b{re.escape(phrase)}\b', ' ', remainder)

        single_word_targets = {
            self._collapse_repeated_letters(p) for p in phrase_set if " " not in p
        }
        remainder = " ".join(
            tok for tok in remainder.split()
            if self._collapse_repeated_letters(tok.strip(".,!?;:")) not in single_word_targets
        )
        return re.sub(r'\s+', ' ', remainder).strip(" ,.!?;:")

    def answer_semantics(self, clean: str) -> str:
        core = clean.rstrip(".!?,;: ")
        if len(core.split()) > 8:
            return "entity"

        # A filler word at the START of a reply ("yeah, finished the
        # database migration") doesn't make the rest of it filler too --
        # but real content surviving the strip only means "entity" when
        # it's an actual noun-bearing topic, not when it's just light
        # continuation words describing the SAME thing the question
        # already asked about ("nopee.. it keep raining" must read as a
        # negative answer about the weather, never as a new entity named
        # "it"/"keep raining" -- see LIGHT_CONTINUATION_WORDS above).
        stripped_words = self._strip_filler_phrases(core).split()
        if stripped_words:
            content_words = [w for w in stripped_words if w not in self.LIGHT_CONTINUATION_WORDS]
            if len(content_words) >= 2:
                return "entity"

        has_small_amount = self._elongation_match(core, self.SMALL_AMOUNT_KWS)
        has_uncertain = self._elongation_match(core, self.UNCERTAIN_KWS)
        has_deny = self._elongation_match(core, self.DENY_FILLER_KWS)
        has_affirm = self._elongation_match(core, self.AFFIRM_FILLER_KWS)
        has_neutral = self._elongation_match(core, self.NEUTRAL_FILLER_KWS)

        if has_small_amount:
            # "ya, but abit only" (affirmed + small amount) reads as a mild
            # positive/intensity update; "no, just a bit" (denied + small
            # amount, no affirm) reads as a mild negative.
            return "small_negative" if (has_deny and not has_affirm) else "small_positive"
        if has_uncertain:
            return "uncertain"
        if has_neutral:
            return "neutral"
        if stripped_words and (has_affirm or has_deny):
            # A leading yes/no signal plus leftover light-continuation
            # words ("nope, still raining") -- the reply both answers AND
            # elaborates on the same topic, so the caller should treat this
            # as ongoing description of that topic rather than a flat
            # yes/no (see _event_continuation_ack in HumanResponseGenerator).
            return "event_continuation"
        if has_affirm or has_deny or core in {"yes", "yeah", "yep", "yup", "no", "nah", "nope"}:
            return "yes_no"

        # Entire reply is made only of filler tokens with no real content
        # word at all -- still not an entity, just an unclassified filler.
        tokens = [t.strip(".,!?;:") for t in core.split()]
        if tokens and all(
            t in self.FILLER_PARTICLES or self._collapse_repeated_letters(t) in {
                self._collapse_repeated_letters(p) for p in self.FILLER_PARTICLES
            }
            for t in tokens
        ):
            return "neutral"
        return "entity"

    def _is_real_entity_phrase(self, phrase: Optional[str]) -> bool:
        """Sanity gate before a noun/topic phrase is persisted as
        tracker.current_entity or handed to the "So X is where most of
        this is coming from" family of templates -- X must be an actual
        topic noun (backend, database, deadline, relationship, exam),
        never a stray filler/conversational particle that slipped past
        upstream filtering (e.g. spaCy mistagging an OOV token like
        "nopee" as a noun chunk -- see TopicExtractor.extract()). This is
        a defense-in-depth backstop; answer_semantics() above is the
        primary fix and should normally intercept these first."""
        if not phrase:
            return False
        words = phrase.lower().split()
        if not words:
            return False
        filler_collapsed = {self._collapse_repeated_letters(p) for p in self.FILLER_PARTICLES}
        if any(
            w in self.FILLER_PARTICLES or self._collapse_repeated_letters(w.strip(".,!?;:")) in filler_collapsed
            for w in words
        ):
            return False
        if len(words) == 1 and (words[0] in self.LIGHT_CONTINUATION_WORDS or len(words[0]) < 3):
            return False
        return True

    # ── rule-based fast-path ─────────────────────────────────
    def extract_direct_rules(self, text: str) -> Optional[str]:
        clean = self.normalize_text(text)

        # NOTE: crisis/self-harm detection is NOT handled here -- it runs
        # earlier and unconditionally in analyze() via safety_override(),
        # before this rule-based fast-path is even reached.

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

        # ── repair statement: the user is apologizing for/re-explaining
        # their OWN earlier wording ("sorry again", "let me explain again"),
        # not correcting a misreading by the bot (that's
        # MISUNDERSTANDING_REPAIR_KWS above, already checked before this
        # function is even called) and not asking the bot to clarify itself
        # (that's CLARIFICATION_SUBSTRINGS). Never extract an entity from
        # these -- the topic_info extraction skip lives in
        # NO_ENTITY_EXTRACTION_INTENTS alongside misunderstanding_repair.
        repair_statement_kws = [
            "sorry again", "sorry i mean", "sorry, i mean", "let me explain again",
            "let me try again", "let me rephrase", "let me say that again",
            "let me put it another way", "let me explain that again",
        ]
        if any(kw in clean for kw in repair_statement_kws):
            return "repair_statement"
        # Bare "i mean" only counts as its own repair_statement turn when
        # it's the WHOLE (short) message -- "i mean, sometimes he's nice but
        # i don't feel loved" still needs its real classification below, not
        # to be swallowed just because it opens with "i mean".
        core_for_repair = clean.rstrip(".!?,;: ")
        if len(core_for_repair.split()) <= 4 and "i mean" in core_for_repair:
            return "repair_statement"

        # ── sarcasm: exaggerated-positive opener + an explicit negative
        # outcome in the SAME message ("Great, another wonderful day where
        # everything went wrong.") reads as frustration/venting, not joy --
        # checked BEFORE positive_checkin_kws below so VADER/keyword
        # positivity from "great"/"wonderful" never wins on its own. Reuses
        # the existing anger_frustration intent rather than inventing a
        # parallel one (-> anger_frustration_support, already tuned).
        SARCASM_POSITIVE_OPENERS = [
            "great, another", "great, just", "wonderful day", "fantastic, just",
            "just what i needed", "love how", "love it when", "perfect, just",
            "oh great,", "oh wonderful,",
        ]
        SARCASM_NEGATIVE_SIGNALS = [
            "everything went wrong", "nothing works", "ruined", "failed",
            "disaster", "went wrong", "worst", "of course it broke",
            "of course it crashed", "everything is broken", "what a mess",
        ]
        if (
            any(p in clean for p in SARCASM_POSITIVE_OPENERS)
            and any(p in clean for p in SARCASM_NEGATIVE_SIGNALS)
        ):
            return "anger_frustration"

        # ── ambiguous emotion term: a bare, unqualified feeling word
        # ("I'm tired", "I feel off") with nothing else to disambiguate it
        # is genuinely underspecified -- "tired" alone could mean physically
        # exhausted, emotionally drained, or just sleep-deprived, and each
        # implies a different kind of support. Ask rather than guess.
        AMBIGUOUS_EMOTION_CLARIFY_QUESTIONS = {
            "tired": "When you say you're tired, do you mean physically exhausted, stressed, or emotionally drained?",
            "exhausted": "When you say you're exhausted, do you mean physically worn out, stressed, or emotionally drained?",
            "drained": "When you say you feel drained, do you mean physically, mentally, or emotionally?",
            "off": "When you say you feel off, do you mean physically, mentally, or something else entirely?",
            "weird": "When you say you feel weird, what's that like for you -- more physical, or more in your head?",
            "not myself": "When you say you're not feeling like yourself, what's that like for you right now?",
            "blah": "When you say you feel blah, what's that like for you right now?",
            "meh": "When you say you feel meh, what's that like for you right now?",
        }
        AMBIGUOUS_EMOTION_EXACT = {
            "i'm tired": "tired", "im tired": "tired", "i am tired": "tired",
            "i feel tired": "tired", "tired": "tired",
            "i'm exhausted": "exhausted", "im exhausted": "exhausted",
            "i feel exhausted": "exhausted", "exhausted": "exhausted",
            "i'm drained": "drained", "im drained": "drained",
            "i feel drained": "drained", "drained": "drained",
            "i'm off": "off", "im off": "off", "i feel off": "off",
            "i'm weird": "weird", "i feel weird": "weird",
            "i'm not myself": "not myself", "im not myself": "not myself",
            "not myself": "not myself",
            "i feel blah": "blah", "blah": "blah",
            "i feel meh": "meh", "meh": "meh",
        }
        core_for_ambiguity = clean.rstrip(".!?,;: ")
        if core_for_ambiguity in AMBIGUOUS_EMOTION_EXACT:
            # "category::detail" convention (see specific_body_symptom::name
            # above) -- avoids stashing per-request state on self, which
            # would race under Flask's threaded dev server.
            return f"ambiguous_emotion_clarify::{AMBIGUOUS_EMOTION_EXACT[core_for_ambiguity]}"

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

        # ── relationship uncertainty / mixed feelings ─────────
        # Ongoing ambivalence about whether a partner truly loves them
        # ("he's nice but I don't feel loved") -- distinct from
        # relationship_loss below (fear of an active breakup). Checked
        # first so loose, mixed-feelings phrasing never falls through to
        # the BiLSTM and gets mistaken for low-confidence "uncertain"
        # (see _resolve_strategy/clarify_uncertain).
        relationship_uncertainty_kws = [
            "don't know whether to break up", "dont know whether to break up",
            "don't know whether i should break up", "dont know whether i should break up",
            "don't know if i should break up", "dont know if i should break up",
            "don't know if i should stay", "dont know if i should stay",
            "don't know whether to leave", "dont know whether to leave",
            "don't know whether i should leave", "dont know whether i should leave",
            "don't know if i should leave", "dont know if i should leave",
            "should i break up", "should i break up with him", "should i break up with her",
            "should i leave him", "should i leave her", "should i stay or leave",
            "mixed feelings about him", "mixed feelings about her",
            "mixed feelings about us", "mixed feelings about my relationship",
            "mixed feelings about this relationship",
            "torn about him", "torn about her", "torn about this relationship",
            "torn about us", "torn between",
            "don't feel loved", "dont feel loved",
            "don't feel like he loves me", "dont feel like he loves me",
            "don't feel like he love me", "dont feel like he love me",
            "don't feel like she loves me", "dont feel like she loves me",
            "don't feel like she love me", "dont feel like she love me",
            "doesn't feel like he loves me", "doesn't feel like she loves me",
            "don't think he loves me", "dont think he loves me",
            "don't think she loves me", "dont think she loves me",
            "not sure he loves me", "not sure she loves me",
            "not sure if he loves me", "not sure if she loves me",
            "don't know if he loves me", "dont know if he loves me",
            "don't know if she loves me", "dont know if she loves me",
            "he's nice but", "hes nice but", "she's nice but", "shes nice but",
            "he is nice but", "she is nice but",
            "he cares but", "she cares but",
            "treats me nice but", "treat me nice but",
            "treats me well but", "treat me well but",
            "good to me but", "kind to me but",
            "sometimes good sometimes bad", "sometimes nice sometimes",
            "some days good some days bad",
        ]
        if any(kw in clean for kw in relationship_uncertainty_kws):
            return "topic_relationship_uncertainty"

        # Structural variant of the same ambivalence that doesn't reduce to
        # one fixed phrase ("sometimes he treats me nice, but sometimes I
        # don't feel loved") -- two "sometimes" clauses joined by a
        # contrast connective.
        if clean.count("sometimes") >= 2 and any(c in clean for c in self.CONTRAST_CONNECTIVES):
            return "topic_relationship_uncertainty"

        # Second structural variant: a care/kindness signal ("he's nice to
        # me", "takes care of me") and a doubt-about-being-loved signal
        # ("can't feel his love") joined by a contrast connective, in
        # either order ("he nice to me and take care of me, but i still
        # can't feel his love"). Looser than the fixed phrases above so it
        # doesn't depend on exact grammar ("he's nice but" vs "he nice to
        # me ... but ... can't feel his love") -- this is what keeps a
        # clearly-relationship-ambivalent message OUT of the BiLSTM's
        # low-confidence "uncertain" fallback (see clarify_uncertain gate).
        relationship_care_kws = [
            "nice to me", "treats me nice", "treat me nice", "treats me well",
            "treat me well", "takes care of me", "take care of me",
            "is good to me", "good to me", "kind to me", "cares for me",
            "cares about me", "caring towards me", "treats me right",
        ]
        relationship_love_doubt_kws = [
            "can't feel his love", "cant feel his love", "can't feel her love",
            "cant feel her love", "can't feel the love", "cant feel the love",
            "can't feel love", "cant feel love", "can't feel loved", "cant feel loved",
            "don't feel loved", "dont feel loved", "don't feel his love",
            "dont feel his love", "don't feel her love", "dont feel her love",
            "doesn't feel like love", "don't feel the love", "dont feel the love",
        ]
        if (
            any(c in clean for c in relationship_care_kws)
            and any(c in clean for c in self.CONTRAST_CONNECTIVES)
            and any(d in clean for d in relationship_love_doubt_kws)
        ):
            return "topic_relationship_uncertainty"

        # ── fear of breakup ────────────────────────────────────
        # Distinct from both relationship_uncertainty (doubt about being
        # loved) and relationship_loss below (fear the partner will leave)
        # -- this is fear of the AFTERMATH of leaving/being left: what life
        # would feel like alone, not whether the relationship itself is
        # healthy or at risk.
        fear_of_breakup_kws = [
            "scared after breakup", "scared after a breakup", "afraid after breakup",
            "afraid after a breakup", "scared of life after breakup",
            "afraid to leave", "scared to leave", "afraid of leaving",
            "scared of leaving", "afraid to break up", "scared to break up",
            "don't want to be alone", "dont want to be alone",
            "don't want to be single", "dont want to be single",
            "fear being single", "fear being alone", "afraid of being single",
            "afraid of being alone", "scared of being single", "scared of being alone",
            "scared to be alone", "afraid to be alone",
            "scared of ending up alone", "afraid of ending up alone",
            "what life would be like without him", "what life would be like without her",
            "don't know what life would be like alone", "dont know what life would be like alone",
        ]
        if any(kw in clean for kw in fear_of_breakup_kws):
            return "topic_fear_of_breakup"

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
        # Each category below is split into a STRONG tier (already
        # distress-laden, fires unconditionally -- unchanged behavior) and a
        # WEAK tier (bare topic nouns with no inherent emotional valence --
        # see the TOPIC != EMOTION SAFETY LAYER above _classify_topic_mention).
        coding_kws_strong = [
            "debugging", "bug", "bugs",
            "cannot code", "can't code", "my code not working",
            "coding assignment", "programming assignment",
            "fyp code", "project code", "system bug", "stuck in coding", "code error",
        ]
        coding_kws_weak = ["coding", "code", "programming"]
        if any(kw in clean for kw in coding_kws_strong):
            return "coding_pressure"
        if any(kw in clean for kw in coding_kws_weak):
            return self._classify_topic_mention(clean, "coding_pressure")

        exam_kws_strong = [
            "scared fail exam", "afraid fail exam", "exam stress",
            "fear of failing exam", "nervous for exam",
        ]
        exam_kws_weak = [
            "exam", "exams", "test", "quiz", "midterm", "final exam", "study for exam",
        ]
        if any(kw in clean for kw in exam_kws_strong):
            return "exam_pressure"
        if any(kw in clean for kw in exam_kws_weak):
            return self._classify_topic_mention(clean, "exam_pressure")

        deadline_kws_strong = [
            "late submission", "many deadlines",
            "rush to finish", "not enough time", "time running out", "deadline stress",
        ]
        deadline_kws_weak = [
            "deadline", "submission", "due tomorrow", "due soon", "assignment due",
        ]
        if any(kw in clean for kw in deadline_kws_strong):
            return "deadline_pressure"
        if any(kw in clean for kw in deadline_kws_weak):
            return self._classify_topic_mention(clean, "deadline_pressure")

        presentation_kws_strong = ["nervous present", "presentation anxiety"]
        presentation_kws_weak = [
            "presentation", "present tomorrow", "public speaking",
            "speak in front of class", "oral presentation",
        ]
        if any(kw in clean for kw in presentation_kws_strong):
            return "presentation_pressure"
        if any(kw in clean for kw in presentation_kws_weak):
            return self._classify_topic_mention(clean, "presentation_pressure")

        group_work_kws_strong = [
            "teammate lazy", "my teammate no do work", "carry whole team",
            "team conflict", "member not helping", "teammates not helping",
        ]
        group_work_kws_weak = ["group work", "group project"]
        if any(kw in clean for kw in group_work_kws_strong):
            return "group_work_pressure"
        if any(kw in clean for kw in group_work_kws_weak):
            return self._classify_topic_mention(clean, "group_work_pressure")

        academic_kws_strong = [
            "study stress", "academic pressure", "i scared i fail", "i'm scared i fail",
            "my grades are dropping", "i cannot focus study",
            "i can't focus study", "too many assignments",
        ]
        academic_kws_weak = [
            "assignment", "assignments", "coursework",
            "class", "classes", "lecture", "lectures", "homework",
        ]
        if any(kw in clean for kw in academic_kws_strong):
            return "academic_pressure"
        if any(kw in clean for kw in academic_kws_weak):
            return self._classify_topic_mention(clean, "academic_pressure")

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

        # ── neutral day-recap phrases ──────────────────────────
        # Short, unambiguous "nothing notable happened" statements
        # ("Today was pretty normal.") were otherwise falling through to
        # the BiLSTM model, which predicts negative_checkin for these with
        # high confidence (a training-data skew, not a rule this file can
        # fix by example) -- and that wrong intent then also picks up
        # "Today" as a spurious topic_entity, producing "...when you are
        # facing Today." Short-circuiting these here avoids both problems
        # at once, the same way the academic-keyword weak-tier gate does
        # for topic words elsewhere in this function.
        neutral_day_recap_kws = [
            "pretty normal", "fairly normal", "just normal", "totally normal",
            "nothing special", "nothing much happened", "same as usual",
            "pretty uneventful", "just a normal day", "an average day",
            "pretty average", "nothing out of the ordinary", "fairly uneventful",
        ]
        if any(kw in clean for kw in neutral_day_recap_kws):
            return "neutral_checkin"

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

        # ── casual companion mode: explicit small-talk signals ─
        # These are specific enough multi-word phrases (or the standalone
        # "bored") to substring-match safely -- unlike bare "chat"/"talk"
        # above, which stay exact-match only so "I need to talk to my
        # professor about my grade" doesn't get misread as small talk.
        casual_smalltalk_kws = [
            "just came to chat", "just want to chat", "just want to talk",
            "just here to chat", "just here to talk", "just wanted to chat",
            "just wanted to talk", "came to say hi", "came to say hello",
            "just saying hi", "just saying hello", "just dropping by",
            "just popping in", "just felt like talking", "just felt like chatting",
            "wanted to talk", "bored", "just checking in", "just check in",
        ]
        if any(kw in clean for kw in casual_smalltalk_kws):
            return "intent_chat"

        # ── casual companion mode: short, breezy acknowledgments ──
        # ("okeie", "okayy", "alrighty", "kk", "lol", "haha") -- these carry
        # no request for clarification and no distress, so they must not
        # fall through to the low-confidence "uncertain" -> clarify_uncertain
        # path, which reads as overly formal for a one-word casual reply.
        CASUAL_ACK_PATTERN = re.compile(r"^(ok(ay)?|alright|fine|okie|kk|cool|nice|sure)[a-z]{0,4}[!.~]*$")
        CASUAL_LAUGH_KWS = ["lol", "lols", "lmao", "haha", "hahaha", "hehe"]
        if CASUAL_ACK_PATTERN.match(clean) or clean in CASUAL_LAUGH_KWS:
            return "casual_ack"

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

        # ── suggest_topic: the user is handing conversational lead back
        # to the bot ("anything to chat?", "idk what to talk about", "up to
        # you") -- this is NOT an answer to the bot's last question, even
        # though it's short and follows one. Checked late (after every more
        # specific category above) but BEFORE returning None, so rule_hit is
        # never None for these -- which is what stops the older Question-
        # Answer Resolution heuristic (Priority 2, keyed off rule_hit is
        # None) from misreading it as answer_previous_question and handing
        # "anything"/"idk" to the topic extractor as if it were a real entity.
        # NOTE: deliberately NOT named "topic_suggestion" -- rule_hit values
        # starting with "topic_" are a separate, existing convention (see
        # "if rule_hit.startswith('topic_')" below) meaning "strip the
        # prefix and use the rest as state['topic'] with intent='venting'",
        # which would silently swallow this into the wrong branch.
        topic_suggestion_kws = [
            "anything to chat", "anything to talk about", "anything you want to talk about",
            "idk what to talk about", "i don't know what to talk about",
            "i dont know what to talk about", "up to you", "you choose",
            "you decide", "you pick", "surprise me", "whatever you want",
            "whatever you'd like", "whatever you like", "what do you want to talk about",
            "you tell me",
        ]
        if any(kw in clean for kw in topic_suggestion_kws):
            return "suggest_topic"

        # ── new_topic: a bare trailing-off pivot phrase with no content of
        # its own yet ("by the way...", "actually..."). Deliberately exact/
        # near-exact only -- a full sentence starting with "actually" still
        # carries real content and should classify normally below.
        new_topic_exact = {
            "by the way", "by the way...", "btw", "speaking of which",
            "anyway", "actually", "actually...",
        }
        if clean.rstrip(".!?,;: ") in new_topic_exact:
            return "new_topic"

        return None

    # ════════════════════════════════════════════════════════════════
    # DISTRESS SCORING -- a per-turn numeric read of the CURRENT intent's
    # actual severity, independent of topic. Support intensity should track
    # this, not the mere presence of an academic/work/etc. keyword:
    #   0      -> conversation / acknowledgement (accomplishment, neutral, greeting...)
    #   1-2    -> light support (mild/ambiguous negative signal)
    #   3-5    -> validation (clear, non-crisis distress)
    #   6+     -> crisis support
    # Intents not listed default to DISTRESS_SCORE_DEFAULT (light support),
    # which is the conservative middle ground for the many control-flow/meta
    # intents (e.g. "breath_choice", "short_confirm") whose actual severity
    # is really inherited from whatever distress was already in play.
    # ════════════════════════════════════════════════════════════════
    DISTRESS_SCORE_MAP = {
        # 0 -- conversation / acknowledgement
        "accomplishment": 0, "neutral_checkin": 0, "greeting": 0, "gratitude": 0,
        "session_close": 0, "intent_chat": 0, "open_chat": 0, "short_confirm": 0,
        "slight_relief": 0, "unclear_positive_feedback": 0, "grounding_completed": 0,
        "casual_ack": 0, "general_activity": 0, "casual_answer": 0,
        "misunderstanding_repair": 0, "suggest_topic": 0, "new_topic": 0,
        "ambiguous_emotion_clarify": 1,

        # 1-2 -- light support
        "negative_checkin": 2, "confusion": 2, "short_idk": 1, "mixed_relief": 1,
        "random_pattern": 2, "low_motivation": 2, "focus_problem": 2,
        "low_engagement": 1, "uncertain": 1,

        # 3-5 -- validation (clear, non-crisis distress)
        "academic_pressure": 4, "academic_workload": 3, "exam_pressure": 4,
        "deadline_pressure": 4, "presentation_pressure": 4, "group_work_pressure": 4,
        "coding_pressure": 4, "family_pressure": 4, "money_stress": 4,
        "self_comparison": 3, "sadness": 4, "anger_frustration": 4,
        "guilt_shame": 4, "emptiness": 5, "social_anxiety": 4,
        "friendship_pressure": 4, "future_uncertainty": 4, "looping_thoughts": 4,
        "overthinking": 4, "sleep_problem": 3, "body_better_mind_worry": 4,
        "fear_unsolved_problem": 4, "self_esteem": 5, "strong_negative_mood": 5,
        "physical_panic": 5, "no_relief": 5, "high_intensity_distress": 5,
        "topic_relationship_loss": 4, "venting": 3,

        # 6+ -- crisis support
        "chronic_distress": 6, "repeated_no_relief": 6, "crisis_risk_denied": 6,
        "crisis_risk": 8, "crisis_followup": 8, "emergency_crisis": 10,
    }
    DISTRESS_SCORE_DEFAULT = 2

    # conversation_mode is a direct read of the distress tier (see the table
    # above DISTRESS_SCORE_MAP) -- support intensity, including whether the
    # bot leans into casual companion mode, should follow distress, not
    # topic. Deliberately kept separate from tracker.conversation_stage
    # (validation/reflection/exploration/encouragement/problem_solving),
    # which is an orthogonal, already-working concept this must not touch.
    def _conversation_mode_for_score(self, score: int) -> str:
        if score <= 0:
            return "casual_companion"
        if score <= 2:
            return "light_support"
        if score <= 5:
            return "validation"
        return "crisis_support"

    def _annotate_distress(self, state: Dict[str, str]) -> Dict[str, str]:
        intent = state.get("intent", "")
        state["achievement_flag"] = intent == "accomplishment"
        score = self.DISTRESS_SCORE_MAP.get(intent, self.DISTRESS_SCORE_DEFAULT)
        # Masking laughter alongside a real distress/hedge signal (see
        # _analyze_core) nudges the score up by one tier-step at most --
        # capped to the low/mild range so a "haha" never pushes an
        # already-significant distress intent across a conversation_mode
        # boundary (e.g. into crisis_support) on its own.
        if state.pop("_masking_laughter_with_distress", False) and 0 < score <= 3:
            score += 1
        state["distress_score"] = score
        state["conversation_mode"] = self._conversation_mode_for_score(state["distress_score"])
        return state

    # ════════════════════════════════════════════════════════════════
    # META-TAXONOMY LAYER -- a coarse, three-axis report view (topic /
    # emotion / intent / strategy / confidence) layered ON TOP of the
    # fine-grained intent/topic/distress_score above, never replacing it.
    # Both topic_category and emotion are derived from the fine-grained
    # intent + distress_score that the pipeline above already computed
    # from actual evidence (keyword/VADER/achievement checks) -- topic
    # alone still never determines emotion or intent here, exactly
    # preserving the guarantee the rest of this file already enforces.
    # ════════════════════════════════════════════════════════════════
    TOPIC_CATEGORY_MAP = {
        "academic": "academic", "fyp": "academic",
        "social": "relationship", "friendshipconflict": "relationship",
        "relationshipconflict": "relationship", "relationship": "relationship",
        "relationship_loss": "relationship",
        "relationship_uncertainty": "relationship",
        "fear_of_breakup": "relationship",
        "family": "family",
        "work": "work",
        "health": "health",
    }
    CRISIS_INTENTS = {"emergency_crisis", "crisis_risk", "crisis_followup", "crisis_risk_denied"}
    CONTRAST_CONNECTIVES = [" but ", " however ", " although ", " even though ", " yet "]
    MIXED_EMOTION_WORRY_KWS = ["worried", "anxious", "nervous", "scared", "afraid", "concerned"]
    MIXED_EMOTION_SAD_KWS = ["sad", "down", "upset"]

    def _classify_topic_category(self, topic: Optional[str], intent: str = "") -> str:
        base = self.TOPIC_CATEGORY_MAP.get((topic or "general").lower(), "general")
        if base != "general":
            return base
        # The ML topic extractor doesn't always set state["topic"] (many
        # rule-based intents return a bare intent string without touching
        # it), even when the intent name itself clearly implies a category
        # -- e.g. "exam_pressure" leaves topic="general" but is obviously
        # academic. Fall back to the intent name in that case.
        i = intent.lower()
        if any(h in i for h in ("academic", "exam", "deadline", "coding", "presentation", "group_work")):
            return "academic"
        if "friendship" in i or "relationship" in i:
            return "relationship"
        if "family" in i:
            return "family"
        return "general"

    # Checked against the message text BEFORE the intent-string heuristic
    # below -- topic-flavored intents like "friendship_pressure"/
    # "family_pressure" all contain "pressure" and would otherwise bucket as
    # "stress" even when the actual content is a conflict/argument, which
    # reads as anger, not stress (e.g. "I argued with my friend").
    ANGER_CONTENT_KWS = [
        "argued", "argument", "fight with", "fought with", "conflict with",
        "angry at", "mad at", "furious", "pissed off", "pissed at",
    ]

    def _classify_emotion_bucket(self, intent: str, distress_score: int, clean: str = "", topic: str = "") -> str:
        if any(kw in clean for kw in self.ANGER_CONTENT_KWS):
            return "anger"
        if intent in ("accomplishment", "gratitude", "slight_relief", "unclear_positive_feedback"):
            return "joy"
        # Mixed/ambivalent feelings ("he's nice but I don't feel loved") and
        # the rule-based "confusion" intent both genuinely read as confusion,
        # not the "neutral"/"sadness" bucket distress_score would otherwise
        # fall back to below.
        if intent == "confusion" or topic == "relationship_uncertainty":
            return "confusion"
        if topic == "fear_of_breakup":
            return "anxiety"
        i = intent.lower()
        if "anger" in i or "frustrat" in i:
            return "anger"
        if "lonel" in i or "emptiness" in i:
            return "loneliness"
        if "hopeless" in i or "chronic_distress" in i or "repeated_no_relief" in i:
            return "hopelessness"
        if "sad" in i or "guilt" in i or "self_esteem" in i:
            return "sadness"
        if "panic" in i or "anxi" in i or "worry" in i or "fear" in i or "looping" in i or "overthink" in i:
            return "anxiety"
        if "pressure" in i or "stress" in i or "burnout" in i or "workload" in i:
            return "stress"
        if distress_score == 0:
            return "neutral"
        if distress_score >= 6:
            return "hopelessness"
        if distress_score >= 3:
            # Real distress already established (3-5 = validation tier) but
            # the intent name itself doesn't say which flavor (e.g. the
            # generic "strong_negative_mood"/"negative_checkin") -- sadness
            # is the most common default for unflavored negative distress,
            # vs. "neutral" which would understate it.
            return "sadness"
        return "neutral"

    def _classify_meta_intent(self, intent: str, emotion: str, distress_score: int) -> str:
        if intent in self.CRISIS_INTENTS or distress_score >= 6:
            return "crisis_support"
        if intent == "greeting":
            return "greeting"
        if intent == "seeking_solutions":
            return "advice_seeking"
        if distress_score == 0:
            return "check_in"
        if emotion == "anger":
            return "venting"
        if emotion in ("sadness", "anxiety", "loneliness", "hopelessness", "stress"):
            return "emotional_support"
        return "check_in"

    def _classify_meta_strategy(self, meta_intent: str, mixed_emotion: bool) -> str:
        if meta_intent == "crisis_support":
            return "crisis_support"
        if mixed_emotion:
            return "validate_positive_then_explore_concern"
        if meta_intent == "venting":
            return "reflective_listening"
        if meta_intent == "emotional_support":
            return "validate_then_explore"
        if meta_intent == "advice_seeking":
            return "advice_seeking"
        if meta_intent == "greeting":
            return "greeting"
        return "normal_conversation"

    def _detect_mixed_emotion(self, clean: str) -> Optional[Tuple[str, str]]:
        """Returns (primary_emotion, secondary_emotion) if `clean` pairs an
        achievement/positive clause with a worry/negative one across a
        contrast connective ("I passed my exam BUT I'm worried about the
        future" -> ("anxiety", "joy")), else None. The positive clause
        always contributes "joy" as the secondary emotion -- it's gated on
        achievement evidence or clearly positive sentiment, so it's never a
        neutral/ambiguous clause being mislabeled as joyful. Order matters:
        only a positive-then-negative pattern counts as "mixed" here, not a
        negative-then-positive recovery statement (handled elsewhere by
        meaning_shift)."""
        for conn in self.CONTRAST_CONNECTIVES:
            if conn in clean:
                before, after = clean.split(conn, 1)
                before_positive = (
                    self._has_achievement_evidence(before)
                    or self.sia.polarity_scores(before)["compound"] > 0.3
                )
                if not before_positive:
                    continue
                if any(kw in after for kw in self.MIXED_EMOTION_WORRY_KWS):
                    return ("anxiety", "joy")
                if any(kw in after for kw in self.MIXED_EMOTION_SAD_KWS):
                    return ("sadness", "joy")
                if self._has_distress_evidence(after):
                    return ("anxiety", "joy")
        return None

    def _compute_confidence(self, state: Dict[str, str]) -> float:
        if "confidence" in state:
            return state["confidence"]  # already set explicitly upstream
        if state.get("intent") in self.CRISIS_INTENTS:
            return 0.99  # safety_override is a deterministic phrase match, same as _rule_based
        if state.get("_rule_based"):
            return 0.92  # deterministic substring/phrase match
        if "_model_confidence" in state:
            return round(float(state["_model_confidence"]), 2)
        if state.get("intent") == "uncertain":
            return 0.3
        return 0.75

    def classify_meta(self, state: Dict[str, str]) -> Dict[str, str]:
        """Populate the coarse topic/emotion/intent/strategy/confidence
        taxonomy. If confidence < 0.65, meta_intent/meta_strategy fall back
        to clarify_uncertain instead of forcing a category -- but this never
        softens an actual crisis signal, and never touches the underlying
        fine-grained state["intent"] that the real strategy dispatch uses
        (so existing, already-tuned behavior for the dozens of fine-grained
        intents is untouched; this is a reporting layer on top of it)."""
        intent = state.get("intent", "")
        distress_score = state.get("distress_score", 0)

        confidence = self._compute_confidence(state)
        state["confidence"] = confidence
        state.pop("_model_confidence", None)
        state.pop("_rule_based", None)

        state["topic_category"] = self._classify_topic_category(state.get("topic"), intent)

        # Only a genuinely low-confidence read (model has essentially no
        # leaning at all) should report as "uncertain" -- a merely moderate
        # score (e.g. filler-laden but otherwise clear venting) still gets a
        # real emotion/intent below instead of being mislabeled (see
        # _resolve_strategy's matching clarify_uncertain gate).
        if confidence < 0.35 and intent not in self.CRISIS_INTENTS and intent != "ambiguous_emotion_clarify":
            state["emotion"] = "uncertain"
            state["meta_intent"] = "uncertain"
            state["meta_strategy"] = "clarify_uncertain"
            return state

        clean = state.get("clean_text", "")
        mixed = self._detect_mixed_emotion(clean) if clean else None

        emotion = self._classify_emotion_bucket(intent, distress_score, clean, state.get("topic", ""))
        state["emotion"] = emotion
        if mixed:
            mixed_primary, mixed_secondary = mixed
            state["primary_emotion"] = mixed_primary
            state["secondary_emotion"] = mixed_secondary
            emotion_for_intent = mixed_primary
        else:
            emotion_for_intent = emotion

        meta_intent = self._classify_meta_intent(intent, emotion_for_intent, distress_score)
        state["meta_intent"] = meta_intent
        state["meta_strategy"] = self._classify_meta_strategy(meta_intent, bool(mixed))
        return state

    def analyze(self, text: str, tracker: "UserContextTracker") -> Dict[str, str]:
        """Public entry point -- delegates to the rule/model pipeline below,
        then annotates the result with distress_score/achievement_flag/
        emotion (see DISTRESS_SCORE_MAP) so callers can gate support
        intensity on actual distress rather than re-deriving it from topic,
        and with the coarse topic/emotion/intent/strategy/confidence
        taxonomy (see classify_meta) for callers that want that view."""
        return self.classify_meta(self._annotate_distress(self._analyze_core(text, tracker)))

    # ── main analysis method ─────────────────────────────────
    def _analyze_core(self, text: str, tracker: "UserContextTracker") -> Dict[str, str]:
        state = {
            "topic": tracker.topic if tracker.topic else "general",
            "intent": "venting",
        }

        clean = self.normalize_text(text)
        state["clean_text"] = clean
        state["msg_word_count"] = len(clean.split())
        # Masking laughter ("...or not haha") riding alongside a real
        # distress/hedge signal nudges distress_score up slightly (see
        # _annotate_distress) -- computed once, here, so it applies
        # regardless of which path below ends up classifying the intent.
        state["_masking_laughter_with_distress"] = (
            self._has_masking_laughter(clean)
            and (self._has_distress_evidence(clean) or self._has_capability_hedge(clean))
        )

        # ── Crisis emotional memory (Problem 3/7): sticky for the session,
        # checked unconditionally and as early as possible so it's captured
        # regardless of which branch ultimately classifies this turn. Once
        # set, the crisis response composer must never re-ask for this
        # information and must broaden away from "talk to your friends"
        # once loneliness has been disclosed. ──────────────────────────────
        if any(p in clean for p in self.CRISIS_LONELINESS_PHRASES):
            tracker.recent_loneliness = True
            state["mentions_loneliness_now"] = True
        if any(p in clean for p in self.CRISIS_HOPELESSNESS_PHRASES):
            tracker.recent_hopelessness = True
        if any(p in clean for p in self.CRISIS_FEAR_PHRASES):
            tracker.recent_fears = True

        # ════════════════════════════════════════════════════════════════
        # SAFETY OVERRIDE LAYER -- priority 1, runs before literally
        # everything else: answer_previous_question, the attention lock,
        # topic continuity, the stage engine, response generation, and every
        # fallback strategy. The CURRENT message's meaning always overrides
        # conversational history when safety is at stake.
        # ════════════════════════════════════════════════════════════════

        # ── 1. Always check the CURRENT message for crisis/self-harm
        # language first -- this covers both a fresh disclosure and any
        # crisis language embedded in a reply to our own crisis follow-up
        # question (e.g. "no, but I do want to kill myself" must still
        # escalate, despite the "no" prefix). See safety_override()
        # docstring for the two severity tiers. ────────────────────────────
        override_intent, override_phrase = self.safety_override(clean)
        if override_intent:
            tracker.awaiting_crisis_followup = False
            state["intent"] = override_intent
            # Enter/refresh Persistent Crisis Mode -- a fresh signal always
            # resets the stability counter, since whatever progress toward
            # exiting crisis mode existed no longer applies. A relapse also
            # cancels any cooldown tapering in progress (Problem 8).
            tracker.crisis_mode = True
            tracker.crisis_stable_turns = 0
            tracker.in_crisis_cooldown = False
            tracker.crisis_cooldown_turns = 0
            tracker.crisis_stage = max(tracker.crisis_stage, self._detect_crisis_stage(clean, tracker.crisis_stage))
            if override_intent == "crisis_risk":
                tracker.crisis_level = max(tracker.crisis_level, 1)
                tracker.awaiting_crisis_followup = True
                tracker.last_crisis_phrase = self.CRISIS_RISK_ECHO.get(override_phrase, "that")
                state["crisis_phrase"] = tracker.last_crisis_phrase
            else:  # emergency_crisis
                tracker.crisis_level = 2
                tracker.crisis_stage = max(tracker.crisis_stage, 2)
            return state

        # ── 2. No fresh crisis language in this message -- if we were
        # waiting on an answer to our own "are you having thoughts about
        # hurting yourself...?" question, resolve THIS reply against THAT
        # question before the generic Answer Interpretation Layer below gets
        # a chance to misread a plain "yes"/"no" as confirming some
        # unrelated prior observation. ──────────────────────────────────────
        if tracker.awaiting_crisis_followup:
            tracker.awaiting_crisis_followup = False
            CONFIRM_SELF_HARM_PREFIX = re.compile(
                r"^(yes|yeah|yep|yup|sure|correct|exactly|that's right|thats right)\b"
            )
            CONFIRM_SELF_HARM_PHRASES = [
                "i am having those thoughts", "i do have those thoughts",
                "i am having thoughts of hurting myself",
                "thinking about hurting myself", "thoughts of hurting myself",
                "i am thinking about it", "i want to hurt myself",
            ]
            DENY_SELF_HARM_PREFIX = re.compile(
                r"^(no|nah|nope|not really|not at all|no i'm not|no im not)\b"
            )
            if CONFIRM_SELF_HARM_PREFIX.match(clean) or any(p in clean for p in CONFIRM_SELF_HARM_PHRASES):
                state["intent"] = "emergency_crisis"
                tracker.crisis_mode = True
                tracker.crisis_level = 2
                tracker.crisis_stable_turns = 0
                tracker.in_crisis_cooldown = False
                tracker.crisis_cooldown_turns = 0
                # Confirming active self-harm thoughts in response to a direct
                # question is itself a suicidal_ideation-tier signal at minimum.
                tracker.crisis_stage = max(tracker.crisis_stage, 3, self._detect_crisis_stage(clean, tracker.crisis_stage))
                return state
            if DENY_SELF_HARM_PREFIX.match(clean):
                state["intent"] = "crisis_risk_denied"
                # A single denial of self-harm intent is not, by itself, the
                # "several stable turns" required to leave crisis mode --
                # stay in it at the current level (see CRISIS_EXIT_STABLE_TURNS).
                return state
            # Ambiguous reply -- let it lapse; falls through to the
            # Persistent Crisis Mode gate below (if still active) instead of
            # being classified normally.

        # ── 3. Persistent Crisis Mode: once active, this OUTRANKS normal
        # intent classification entirely -- answer_previous_question,
        # clarify_uncertain, greeting, casual chat, and topic continuity must
        # never resume control while it's on. Vague/low-content replies
        # ("who, there's no one", "I don't know", "maybe", "I can't",
        # "nothing", "whatever") inherit the crisis context instead of being
        # reclassified from scratch. Cleared only after several CONSECUTIVE
        # turns showing real stability -- never after a single message, and
        # even then only via a gradual cooldown taper (Problem 8), not an
        # instant snap back to normal conversation. ────────────────────────
        if tracker.crisis_mode:
            # Re-escalation check FIRST: a followup message can disclose a
            # higher tier than what's already known (e.g. "I want to do it
            # tonight" while already at stage>=2) -- this must win over the
            # stability/decay logic below and, at imminent_danger, re-fire a
            # full emergency response rather than a routine continuation.
            followup_stage = self._detect_crisis_stage(clean, tracker.crisis_stage)
            if followup_stage > tracker.crisis_stage:
                tracker.crisis_stage = followup_stage
                tracker.crisis_stable_turns = 0
                tracker.in_crisis_cooldown = False
                tracker.crisis_cooldown_turns = 0
                if followup_stage >= 4:
                    tracker.crisis_level = 2
                    state["intent"] = "emergency_crisis"
                    return state
                # Otherwise (a defensive fallback for stage 1-3 signals that
                # weren't already caught by safety_override above) continue
                # below as a crisis_followup turn at the new, higher stage.

            if tracker.in_crisis_cooldown:
                # Already tapering (Problem 8): the countdown advances every
                # turn regardless of whether THIS message happens to repeat
                # a stability phrase -- a relapse is already caught by the
                # re-escalation check above (which returns early before
                # reaching here), so simply not relapsing is enough to keep
                # progressing toward normal conversation.
                tracker.crisis_cooldown_turns -= 1
                if tracker.crisis_cooldown_turns <= 0:
                    tracker.crisis_mode = False
                    tracker.crisis_level = 0
                    tracker.crisis_stage = 0
                    tracker.crisis_stable_turns = 0
                    tracker.in_crisis_cooldown = False
                    # Cooldown complete -- let THIS turn be classified normally.
                else:
                    state["intent"] = "crisis_followup"
                    return state
            else:
                if any(p in clean for p in self.CRISIS_STABILITY_PHRASES):
                    tracker.crisis_stable_turns += 1
                    # Stage decays at most one tier per consecutive stable
                    # turn -- never downgraded immediately, and more severe
                    # starting points naturally require more stable turns to
                    # fully calm.
                    tracker.crisis_stage = max(0, tracker.crisis_stage - 1)
                else:
                    tracker.crisis_stable_turns = 0

                if tracker.crisis_stable_turns >= self.CRISIS_EXIT_STABLE_TURNS:
                    # Sustained stability confirmed -- begin a gradual
                    # cooldown taper instead of exiting crisis mode outright.
                    tracker.in_crisis_cooldown = True
                    tracker.crisis_cooldown_turns = self.CRISIS_COOLDOWN_TURNS
                state["intent"] = "crisis_followup"
                return state

        rule_hit = self.extract_direct_rules(text)

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

        # ── Misunderstanding Repair Layer (runs BEFORE everything below) ──
        # "That's not what I mean"/"I didn't mean that" are the user correcting
        # a misreading -- distinct from "what do you mean?" (asking the BOT to
        # re-explain itself) and from a plain "no" denying a confirmable
        # observation (already handled by the Answer Interpretation Layer
        # below). These specific phrases are unambiguous enough to claim
        # unconditionally, regardless of what the prior turn was.
        MISUNDERSTANDING_REPAIR_KWS = [
            "that's not what i mean", "thats not what i mean",
            "that's not what i meant", "thats not what i meant",
            "not what i meant", "not what i mean",
            "i didn't mean that", "i didnt mean that",
            "you misunderstood", "you got it wrong",
            "that's not it", "thats not it", "that's not right", "thats not right",
        ]
        if any(p in clean for p in MISUNDERSTANDING_REPAIR_KWS) and tracker.last_bot_turn.get("text"):
            state["intent"] = "misunderstanding_repair"
            return state

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
            # If the thing being questioned IS the bot's own pending CASUAL
            # question, a bare "what?"/"huh?" reads as "I misunderstood/
            # didn't catch that" rather than a request to re-explain a
            # substantive prior statement -- stay light instead of pivoting
            # into "let me put that differently: ... the toughest part of
            # that for you" style re-explanation.
            pq_for_clarify = tracker.pending_question
            if (
                pq_for_clarify.get("type") and pq_for_clarify["type"] != "open"
                and not pq_for_clarify.get("answered")
                and pq_for_clarify.get("text") == tracker.last_bot_turn.get("text")
            ):
                pq_for_clarify["answered"] = True
                state["intent"] = "misunderstanding_repair"
                return state
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
        # If what's actually being confirmed/denied IS the bot's own pending
        # CASUAL question (not some substantive observation), a plain "no"
        # reads as "that's not what I meant" rather than "you got the facts
        # wrong" -- route through the same light repair/answer paths instead
        # of the clinical confirmed/denied_observation flow (which would ask
        # something like "what's actually been the main thing, then?").
        pending_q_now = tracker.pending_question
        answering_casual_question = (
            pending_q_now.get("type") and pending_q_now["type"] != "open"
            and not pending_q_now.get("answered")
            and pending_q_now.get("text") == prior_turn.get("text")
        )
        if (
            answer_sentiment
            and not any_specific_awaiting_flag
            and prior_turn.get("kind") in ("choice", "question", "statement")
            and not prior_turn.get("answered")
            and len(clean.split()) <= 8
        ):
            prior_turn["answered"] = True
            if answering_casual_question:
                pending_q_now["answered"] = True
                if answer_sentiment == "deny":
                    state["intent"] = "misunderstanding_repair"
                else:
                    state["intent"] = "casual_answer"
                    state["answer_type"] = pending_q_now["type"]
                    # core_answer is an exact CONFIRM/BOTH/PARTIAL token ("a
                    # little", "yeah", "maybe") -- still run it through
                    # answer_semantics() rather than guessing, so "a little"
                    # comes back small_positive/intensity, not a blanket
                    # "uncertain" for every non-confirm token.
                    semantic = self.answer_semantics(core_answer)
                    state["answer_semantic"] = semantic if semantic != "entity" else "yes_no"
                return state
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

        # ── Pending-Question Type Binding (answer_semantics-first) ──────
        # A short reply to a CASUAL question ("How's your day been so far?"
        # -> "so far okeeie", "Made any progress?" -> "ya, but abit only")
        # carries no topical content of its own and isn't a confirm/deny/
        # both/partial token either (those were already claimed above) --
        # classify the reply's own semantic SHAPE first (answer_semantics:
        # yes_no/small_positive/small_negative/neutral/uncertain/intensity),
        # and only fall through to entity extraction when that comes back
        # "entity" (real content). This runs regardless of whether the
        # question's own type was recognized ("open" included) -- "Made any
        # progress on your project lately?" classifies as type=progress, but
        # even a fully generic question should never have "ya"/"abit"/"okay"
        # extracted as its answer's entity.
        # "anything to chat?"/"idk what to talk about" mean something
        # categorically different -- the user handing conversational lead
        # BACK to the bot, not casually answering it. rule_hit already
        # disambiguates this (computed at the very top, unaffected by
        # anything below), so suggest_topic/new_topic must win regardless.
        pending_q = tracker.pending_question
        if (
            pending_q.get("text") and not pending_q.get("answered")
            and len(clean.split()) <= 8
            and not self._has_distress_evidence(clean)
            and rule_hit not in ("suggest_topic", "new_topic")
        ):
            answer_semantic = self.answer_semantics(clean)
            if answer_semantic != "entity":
                pending_q["answered"] = True
                state["intent"] = "casual_answer"
                state["answer_type"] = pending_q.get("type") or "open"
                state["answer_semantic"] = answer_semantic
                return state

        # ── Extract and store topic/situation/event memory ────
        # Skip entirely for purely meta/conversational intents -- "I just
        # came to chat" has no real-world topic, but spaCy's noun-chunk
        # parser can mis-tag the bare verb "chat" (in "came to chat") as the
        # object of "to" and hand back topic_entity="chat", which then
        # contaminates every later answer_previous_question/confirmed_
        # observation/clarification turn that falls back to tracker.
        # current_entity (e.g. "Chat is what's been keeping you busy.").
        # These intents are about the act of talking itself, not a topic.
        NO_ENTITY_EXTRACTION_INTENTS = {
            "intent_chat", "casual_ack", "greeting", "gratitude", "session_close",
            "casual_answer", "misunderstanding_repair", "suggest_topic", "new_topic",
            "repair_statement",
        }
        if rule_hit in NO_ENTITY_EXTRACTION_INTENTS:
            topic_info = {
                "topic_category": "general", "topic_entity": None,
                "event_phrase": None, "repetition_cue": False,
            }
        else:
            topic_info = self.topic_extractor.extract(text)
        new_info = False
        if (
            topic_info.get("topic_entity")
            and topic_info["topic_entity"] != tracker.current_entity
            and self._is_real_entity_phrase(topic_info["topic_entity"])
        ):
            tracker.current_entity = topic_info["topic_entity"]
            new_info = True
            state["new_entity_this_turn"] = True
        if topic_info.get("event_phrase") and topic_info["event_phrase"] != tracker.current_event:
            tracker.current_event = topic_info["event_phrase"]
            new_info = True
            state["new_event_this_turn"] = True

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
                "proposal",
            ],
            "relationship": [
                "boyfriend", "girlfriend", "partner", "breakup", "broke up",
                "relationship",
            ],
            "family": ["mother", "father", "mom", "dad", "family", "parents"],
        }
        fresh_category_match = next(
            (cat for cat, kws in EVENT_CATEGORY_KEYWORDS.items() if any(kw in clean for kw in kws)),
            None,
        )
        detected_category = fresh_category_match
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

        # ── Attention Lock System ──────────────────────────────
        # A FRESH, explicit mention of a specific domain (not just the
        # inherited/persisted category) locks conversational attention onto
        # it for several turns, so later generation overrides whatever the
        # stage/category machinery would otherwise have used (e.g. reverting
        # to "deadline" content just because that's what current_event_category
        # used to be). Re-mentioning the SAME domain refreshes the lock;
        # explicitly mentioning a DIFFERENT one replaces it -- this is how
        # "unless the user explicitly returns to them" is satisfied.
        ATTENTION_DOMAINS = {"technical", "deadline", "supervisor_feedback", "relationship", "family"}
        DOMAIN_LABELS = {
            "technical": "the technical side of things",
            "deadline": "the amount of work and time pressure",
            "supervisor_feedback": "the feedback you've been given",
            "relationship": "what's going on in the relationship",
            "family": "what's going on with family",
            "academic": "the workload itself",
        }
        state["attention_fresh_match"] = False
        if fresh_category_match and fresh_category_match in ATTENTION_DOMAINS:
            previous_domain = tracker.attention.focus_domain
            tracker.attention.focus_domain = fresh_category_match
            # Only overwrite the locked entity/event if THIS turn actually
            # produced one -- a refresh-only turn (e.g. "still breaking")
            # shouldn't erase the more detailed focus from a turn or two ago.
            if topic_info.get("topic_entity"):
                tracker.attention.focus_entity = topic_info["topic_entity"]
            if topic_info.get("event_phrase"):
                tracker.attention.focus_event = topic_info["event_phrase"]
            tracker.attention.focus_topic = next(
                (kw for kw in EVENT_CATEGORY_KEYWORDS[fresh_category_match] if kw in clean),
                fresh_category_match,
            )
            tracker.attention.lock_strength = 1.0
            tracker.attention.lock_turns_remaining = 3
            state["attention_fresh_match"] = True
            state["attention_shifted"] = bool(previous_domain and previous_domain != fresh_category_match)
            state["attention_previous_domain"] = previous_domain
            state["attention_domain_labels"] = DOMAIN_LABELS

        # ── GATEKEEPER LAYER ──────────────────────────────────
        # NOTE: "overwhelmed" was previously listed here, which meant ANY
        # message expressing overwhelm ("I have so many assignments and I
        # feel overwhelmed") got read as "stop talking about this topic"
        # instead of as the distress signal it actually is -- the opposite
        # of what a feelings word expressing overwhelm should trigger.
        # Disengagement is specifically about wanting to change the
        # subject, not about naming a feeling.
        DISENGAGE_KEYWORDS = ["don't want to talk", "dont want to talk", "stop", "change topic", "not this", "let's talk about something else", "lets talk about something else"]
        LOW_ENGAGEMENT_KEYWORDS = ["nothing", "ok", "okay", "idk", "hmm", "...", "no", "nah", "yep", "yes"]
        
        ACADEMIC_KEYWORDS = ["fyp", "assignment", "project", "coding", "backend", "report", "deadline", "due date", "due soon", "overdue", "submission", "exam", "study", "work", "alot of thing", "a lot of thing", "task"]
        EMOTION_KEYWORDS = ["stressed", "overwhelmed", "anxious", "depressed", "sad", "frustrated", "hopeless", "angry", "tired", "panic", "worry"]
        EMOTION_PHRASES = ["i feel", "i'm feeling", "im feeling", "i can't cope", "icant cope", "i am not okay", "im not okay", "i'm not okay"]
        PHYSICAL_KEYWORDS = ["heart racing", "breathe", "panic", "shaking", "tense", "dizzy"]

        # ── Assumption Safety Layer (emotional): sticky for the session once
        # real distress/emotion language has actually been used, mirroring
        # technical_failure_evidence. Set as early as possible (before any
        # branch below might return early, e.g. answer_previous_question) so
        # it reflects the conversation's history rather than just this turn --
        # a later neutral topic-only message ("I'm doing my FYP") must not
        # lose context that distress was already established, but a plain
        # topic mention on its own must never set this. ──────────────────
        if any(kw in clean for kw in EMOTION_KEYWORDS) or any(ph in clean for ph in EMOTION_PHRASES):
            tracker.emotional_evidence = True

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
            tracker.emotional_evidence = False
            tracker.recent_loneliness = False
            tracker.recent_hopelessness = False
            tracker.recent_fears = False
            tracker.last_bot_turn = {
                "text": "", "kind": "statement", "option_a": None, "option_b": None,
                "answered": True, "topic": None, "entity": None, "intent": None,
            }
            tracker.attention = AttentionState()
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
            # A trailing-off discourse filler ("like...", "ermm...", "i guess...",
            # "but then...") is excluded the same way -- it isn't a real answer
            # either, just on a different bot turn (a clinical/non-casual one,
            # so the casual-tier Pending-Question-Type-Binding layer above never
            # saw it) and was getting misread as one, with a stale/unrelated
            # entity then parroted back ("So care is where most of this is
            # coming from."). Falling through instead lets the BiLSTM branch's
            # "maintain previous situation" fallback handle it.
            if (
                len(clean.split()) <= 4
                and rule_hit is None
                and not any(kw in clean for kw in EMOTION_KEYWORDS)
                and clean not in LOW_ENGAGEMENT_KEYWORDS
                and not self._is_near_empty_after_fillers(clean)
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

        if rule_hit and rule_hit.startswith("ambiguous_emotion_clarify::"):
            state["ambiguous_emotion_term"] = rule_hit.split("::", 1)[1]
            state["intent"] = "ambiguous_emotion_clarify"
            state["confidence"] = 0.4
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

            # A rule-based substring/phrase match is deterministic -- treat
            # it as high-confidence for the confidence-scoring layer below.
            state["_rule_based"] = True

            if rule_hit.startswith("topic_"):
                state["topic"] = rule_hit.split("_", 1)[1]
                state["intent"] = "venting"
                # Relationship-flavored topics don't always contain a literal
                # EVENT_CATEGORY_KEYWORDS word ("boyfriend"/"relationship"/...
                # -- e.g. "he nice to me but i still can't feel his love" has
                # neither), so the event-category detector further down would
                # never tag this turn -- or any later one in the same
                # conversation ("what should i do") -- as "relationship"
                # without this. That category is what lets later turns (e.g.
                # seeking_solutions -> problem_solving) generate relationship-
                # aware content instead of generic technical/academic framing.
                if state["topic"] in ("relationship", "relationship_loss", "relationship_uncertainty", "fear_of_breakup"):
                    state["event_category"] = "relationship"
                    tracker.current_event_category = "relationship"
            else:
                state["intent"] = rule_hit
                # Academic-pressure-flavored bare intents (not "topic_"-
                # prefixed, so the branch above never runs) otherwise leave
                # state["topic"] untouched -- it just inherits whatever
                # tracker.topic was, which can still be a stale, DIFFERENT
                # domain from a few turns ago (e.g. "relationship_uncertainty")
                # and silently defeats SmarterDialogueManager's cross-domain
                # topic_shift_acknowledgement check, since same-value
                # comparisons never look like a shift.
                if rule_hit in (
                    "academic_workload", "academic_pressure", "coding_pressure",
                    "exam_pressure", "deadline_pressure", "presentation_pressure",
                    "group_work_pressure", "academic_all_pressure",
                ):
                    state["topic"] = "academic"
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

        # Surfaced for the confidence-scoring layer in _annotate_distress --
        # the actual softmax probability is a much better confidence signal
        # than a flat heuristic whenever the BiLSTM path was taken at all.
        state["_model_confidence"] = prob.item()

        if prob.item() < 0.60:
            # Low BiLSTM confidence -- before giving up with "uncertain", defer to the
            # reliable rule-based academic-keyword signal if one is present.
            if has_academic and not tracker.explicit_emotion_detected:
                state["topic"] = "academic"
                # Topic != Emotion: ACADEMIC_KEYWORDS (fyp/assignment/report/
                # study/work/task/...) carries no emotional valence by itself
                # -- route through the same evidence gate used for the
                # rule-based weak-keyword tiers instead of blindly forcing
                # academic_workload on every academic-flavored mention.
                state["intent"] = self._classify_topic_mention(clean, "academic_workload")
                return state
            # A genuinely contentless filler ("like...", "ermm...", "i
            # guess...", "but then...") doesn't carry enough on its own to
            # justify resetting the conversation into "uncertain" -- if
            # there's already a tracked situation, stay on it (continue the
            # SAME topic/intent) instead of asking the user to clarify
            # something they were never actually confused about. Only
            # kicks in when almost nothing real survives filler-stripping;
            # a substantive low-confidence message still genuinely needs
            # clarify_uncertain/smart_clarification.
            if self._is_near_empty_after_fillers(clean) and tracker.topic not in (None, "general"):
                state["topic"] = tracker.topic
                state["intent"] = "venting"
                return state
            state["intent"] = "uncertain"
        else:
            emotion_tags = ["body_better_mind_worry", "physical_panic", "anxiety", "depression", "sadness", "stress", "strong_negative_mood"]

            # Check confidence threshold for academic classification overrides
            if has_academic and not tracker.explicit_emotion_detected:
                if tag in emotion_tags or tag in ["general_activity", "neutral_checkin", "venting"] or prob.item() < 0.85:
                    state["topic"] = "academic"
                    state["intent"] = self._classify_topic_mention(clean, "academic_workload")
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
    # Parent domains: fine-grained topics that are really the same broad
    # life-area shouldn't trigger topic_shift_acknowledgement just because
    # the specific situation within it evolved (e.g. relationship_uncertainty
    # -> relationship_loss as a conversation deepens is still the SAME
    # relationship, not a new subject -- see _topic_domain below).
    TOPIC_DOMAIN_MAP = {
        "relationship": "relationship_domain",
        "relationship_loss": "relationship_domain",
        "relationship_uncertainty": "relationship_domain",
        "fear_of_breakup": "relationship_domain",
        "social": "relationship_domain",
        "friendshipconflict": "relationship_domain",
        "relationshipconflict": "relationship_domain",
        "friendship_pressure": "relationship_domain",
        "academic": "academic_domain",
        "fyp": "academic_domain",
        "work": "work_domain",
        "health": "health_domain",
    }

    def _topic_domain(self, topic: Optional[str]) -> str:
        t = (topic or "general").lower()
        return self.TOPIC_DOMAIN_MAP.get(t, t)

    def _has_worry_signal(self, clean: str) -> bool:
        """Defensive gate (Part 4, Item 7): even if intent classification
        somehow got it wrong, a casual/accomplishment-flavored strategy must
        never be picked while the raw message still carries a real worry/
        distress or capability-hedge signal. Reuses AdvancedNLUPipeline's
        own keyword sets directly (they're class-level constants, so no
        instance is needed) instead of a separate list, so this gate can't
        silently drift out of sync with the classifier it's backing up."""
        if not clean:
            return False
        return (
            any(kw in clean for kw in AdvancedNLUPipeline.DISTRESS_EVIDENCE_KWS)
            or any(kw in clean for kw in AdvancedNLUPipeline.CAPABILITY_HEDGE_KWS)
            or bool(AdvancedNLUPipeline.CAPABILITY_HEDGE_PATTERN.search(clean))
        )

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
        conversation stage (validation/reflection/exploration/synthesis/
        encouragement/problem_solving) applies to *this* turn's response in
        state["active_stage"]."""
        strategy = self._resolve_strategy(state, tracker)
        state["active_stage"] = self.stage_engine.advance(strategy, state, tracker)
        return strategy

    def _resolve_strategy(
        self, state: Dict[str, str], tracker: "UserContextTracker"
    ) -> str:
        intent = state["intent"]
        topic = state.get("topic", "general")
        prevent_questions = tracker.consecutive_questions >= 2

        # Problem 5: updated here (BEFORE the stage engine runs, see
        # compute_strategy above) rather than inside ConversationStageEngine
        # itself, so the relationship_uncertainty/fear_of_breakup dispatch
        # below can react to THIS turn's count immediately -- reading
        # tracker.conversation_stage instead would always be one turn behind
        # whenever the stage engine's own fast-track fires (it runs after
        # this method returns).
        if topic in RELATIONSHIP_DECISION_TOPICS:
            tracker.relationship_decision_repeat_count += 1
        else:
            tracker.relationship_decision_repeat_count = 0

        # ── SAFETY OVERRIDE: crisis/self-harm intents always win, checked
        # before every other gatekeeper, continuity, or fallback strategy in
        # this method (see safety_override() in AdvancedNLUPipeline). ──────
        if intent == "emergency_crisis":
            # The full hotline/resource message is the safety net shown
            # exactly once per session, the first time explicit risk is
            # confirmed -- every re-trigger after that (including a stage-4
            # imminent_danger re-escalation mid-conversation) goes through
            # the adaptive composer instead of repeating the same canned
            # paragraph verbatim (Problem 1).
            if not tracker.crisis_hotline_shown:
                tracker.crisis_hotline_shown = True
                return "escalation"
            return "crisis_continuation"
        if intent == "crisis_risk":
            # Same one-time-then-adaptive pattern for the stage-1 "what do
            # you mean" clarifying message.
            if not tracker.crisis_clarify_shown:
                tracker.crisis_clarify_shown = True
                return "crisis_support"
            return "crisis_continuation"
        if intent == "crisis_risk_denied":
            return "crisis_followup_support"
        if intent == "crisis_followup":
            # Persistent Crisis Mode is still active (see analyze()) --
            # adaptive, rotating, stage-aware continuation (Problems 1/4/5/6),
            # never answer_previous_question/clarify_uncertain/greeting/topic
            # continuity.
            return "crisis_continuation"

        # ── Gatekeeper / Override Intents ─────────────────────────
        if intent == "topic_shift_emotion":
            return "topic_shift_emotion_strategy"
        if intent == "topic_shift_neutral":
            return "topic_shift_neutral_strategy"
        if intent == "low_engagement":
            return "low_engagement_strategy"
        # "uncertain" only means "I genuinely have no idea what this is" when
        # the model's confidence is this low -- a merely moderate score (the
        # filler-laden-but-otherwise-clear case, e.g. "ermm, like sometimes
        # he treats me nice, but sometimes I don't feel loved") instead falls
        # through to the gentler smart_clarification/pure_validation fallback
        # further down, never the blunt "could you rephrase that?".
        if intent == "uncertain" and state.get("confidence", 1.0) < 0.35:
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

        # Check topic transition -- but an active Attention Lock outranks the
        # broad topic-category model here (Priority 1: Current Attention Focus
        # > Priority 5: Global Topic). Without this, a vague message like "I
        # don't even know what's wrong anymore" can get misclassified into an
        # unrelated topic_category and spuriously ask "did the topic change?"
        # even though the user is still deep in the locked technical/deadline/
        # relationship focus.
        if (self._topic_domain(topic) != self._topic_domain(tracker.topic)
                and topic not in [None, "general"]
                and tracker.topic not in [None, "general"]
                and tracker.turn_count > 2
                and tracker.attention.lock_turns_remaining <= 0):
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
            "accomplishment": "accomplishment_ack",
            "family_pressure": "family_pressure_support",
            "money_stress": "money_stress_support",
            "self_comparison": "self_comparison_support",
            "low_motivation": "low_motivation_support",
            "focus_problem": "focus_problem_support",
        }
        if intent in mood_map:
            # Defensive gate (Part 4, Item 7): "accomplishment" specifically
            # is the one mood_map entry that reads as good news -- never let
            # it fire while the raw message still carries a worry/hedge
            # signal classification may have missed.
            if intent == "accomplishment" and self._has_worry_signal(state.get("clean_text", "")):
                return "reflective_validation" if prevent_questions else "topic_exploration"
            return mood_map[intent]

        # ── relationship ──────────────────────────────────────
        # relationship_uncertainty_response/fear_of_breakup_response are
        # static _pick() banks (deliberately bypass ComponentNLGEngine --
        # see their definitions), so they'd otherwise never reflect the
        # stage engine's synthesis/problem_solving progression (Problems
        # 3/5) the way "_support" strategies do automatically. Checking
        # tracker.conversation_stage here (the PRE-this-turn stage the
        # stage engine already computed -- see compute_strategy) routes
        # those two specific stages to dedicated content instead.
        if intent == "venting" and topic in ("relationship_uncertainty", "fear_of_breakup"):
            wants_decision_support = (
                tracker.conversation_stage != "validation"
                and tracker.relationship_decision_repeat_count >= RELATIONSHIP_DECISION_REPEAT_THRESHOLD
            )
            if tracker.conversation_stage == "problem_solving" or wants_decision_support:
                return "solution_suggestion"
            if tracker.conversation_stage == "synthesis":
                return "relationship_synthesis_response"
            return "relationship_uncertainty_response" if topic == "relationship_uncertainty" else "fear_of_breakup_response"
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
            # Defensive gate (Part 4, Item 7): same reasoning as the
            # "accomplishment" gate above -- a plain check-in pivot/filler
            # bank must never fire while the raw message still carries a
            # worry/hedge signal.
            if self._has_worry_signal(state.get("clean_text", "")):
                return "reflective_validation" if prevent_questions else "topic_exploration"
            if prevent_questions:
                tracker.consecutive_questions = 0 # reset to allow normal flow after pivot
                return "gentle_pivot"
            return "explore_checkin"
        if intent == "intent_chat":
            return "open_chat"
        if intent == "casual_ack":
            return "casual_ack_strategy"
        if intent == "casual_answer":
            return "casual_answer_strategy"
        if intent == "misunderstanding_repair":
            return "misunderstanding_repair_strategy"
        if intent == "repair_statement":
            return "repair_statement_strategy"
        if intent == "suggest_topic":
            return "conversation_leader_strategy"
        if intent == "new_topic":
            return "new_topic_strategy"
        if intent == "ambiguous_emotion_clarify":
            return "ambiguous_emotion_clarify_strategy"

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
        self._init_crisis_templates()
        self._init_casual_templates()

    # ════════════════════════════════════════════════════════════════
    # CRISIS RESPONSE COMPOSER -- rotating, non-repetitive, stage- and
    # content-aware continuation responses for Persistent Crisis Mode
    # (Problems 1, 4, 5, 6). The one-time canned "crisis"/"crisis_risk_check"
    # first-contact messages are deliberately left untouched elsewhere --
    # this composer only handles ongoing/repeat crisis turns.
    # ════════════════════════════════════════════════════════════════
    def _init_crisis_templates(self):
        self.crisis_presence_templates = [
            "I'm still here with you.",
            "Thank you for telling me this.",
            "You don't have to carry this alone.",
            "I'm not going anywhere.",
            "I'm staying right here with you through this.",
        ]
        self.crisis_validation_templates = [
            "This sounds incredibly painful.",
            "It makes sense that things feel overwhelming right now.",
            "That sounds like an enormous amount to be carrying right now.",
            "What you're feeling right now is real, and it matters.",
        ]
        self.crisis_connection_templates = [
            "Feeling alone can make these thoughts even heavier.",
            "I'm glad you told me instead of sitting with this alone.",
            "You reaching out right now, even like this, matters.",
        ]
        # Contradiction-aware (Problem 3): used instead of the plain
        # connection templates once recent_loneliness is known -- never
        # "talk to your friends", always broadened beyond friends.
        self.crisis_connection_broadened_templates = [
            "Even if it doesn't feel like it right now, there may be people who'd want to know -- family, a relative, a roommate, a teacher, a counsellor, or even a neighbour.",
            "It doesn't have to be a friend -- a counsellor, a helpline, a family member, or emergency services can be the right kind of support right now too.",
            "When it feels like there's no one, sometimes the people who can help aren't the ones you'd expect -- a teacher, a relative, a neighbour, or a crisis helpline are all real options.",
        ]
        self.crisis_safety_questions = [
            "Are you somewhere safe right now?",
            "Are you physically alone at the moment?",
            "Is there anything within reach right now that could hurt you?",
        ]
        self.crisis_immediacy_questions = [
            "Are you thinking about doing this soon, or right now?",
            "Is this something you're thinking about acting on tonight?",
            "How soon are you feeling like you might act on this?",
        ]
        self.crisis_clarify_questions = [
            "Can you help me understand a bit more about what you mean?",
            "What's going through your mind right now, as you say that?",
            "When you say that, what does it feel like for you?",
        ]
        self.crisis_grounding_statements = [
            "Let's focus on getting through this moment together.",
            "You don't have to solve everything tonight.",
            "Right now, we just need to get through the next little while.",
            "One moment at a time is enough for right now.",
        ]
        self.crisis_tonight_statements = [
            "Getting through tonight is enough of a goal right now.",
            "If sleep feels possible, that's okay -- just focus on getting through to morning.",
            "Resting can genuinely help right now. Let's just aim for getting through to morning.",
        ]
        self.crisis_resource_reminders = [
            "If things ever feel unsafe, please reach out to a crisis helpline or someone nearby you trust.",
            "A crisis helpline or someone close to you can help carry this with you, even right now.",
        ]
        self.crisis_cooldown_statements = [
            "I'm glad things feel a little steadier right now.",
            "It's good to hear you're feeling a bit more okay.",
            "That's a real shift, even if it still feels fragile.",
            "I'm still glad to be here with you while things settle.",
        ]
        self.crisis_cooldown_questions = [
            "How are you feeling right now, compared to before?",
            "Is there anything that's helped you feel a bit steadier?",
        ]
        # Question probability by crisis_stage (Problem 5) -- higher-risk
        # stages ask LESS, so a high-risk user never feels interrogated.
        self.CRISIS_QUESTION_PROBABILITY = {1: 0.7, 2: 0.6, 3: 0.4, 4: 0.2}
        self.CRISIS_LOW_CONTENT_REPLIES = {
            "i don't know", "i dont know", "maybe", "i can't", "i cant",
            "nothing", "whatever", "idk", "not sure", "dunno",
        }
        # NOTE: normalize_text() strips a leading "maybe" as a filler word
        # when something meaningful follows, so "maybe I'll sleep" arrives
        # here as "i'll sleep" -- these phrases deliberately don't depend on
        # the "maybe" prefix surviving.
        self.CRISIS_SLEEP_CUES = [
            "i'll sleep", "ill sleep", "i'll just sleep", "ill just sleep",
            "i think i'll sleep", "i think ill sleep", "i'm just gonna sleep",
            "im just gonna sleep", "going to sleep", "i'll try to sleep",
            "i'll try and sleep", "going to try to sleep", "just sleep",
            "i'm gonna sleep", "im gonna sleep", "gonna go to sleep",
        ]

    # ════════════════════════════════════════════════════════════════
    # CASUAL COMPANION MODE -- dynamic, diverse, low-pressure continuation
    # for casual small talk (open_chat/casual_ack/casual_answer). Question
    # probability decays with tracker.consecutive_questions (set generically
    # by tracker.update() whenever the bot's last reply contained "?") so a
    # long casual exchange doesn't read like an interview, and followups
    # rotate across topics instead of repeating "anything on your mind?".
    # ════════════════════════════════════════════════════════════════
    def _init_casual_templates(self):
        self.casual_followup_categories = {
            "recent_activity": [
                "What have you been up to recently?",
                "Anything interesting happen today?",
                "What's been keeping you busy lately?",
            ],
            "entertainment": [
                "Watched anything good lately?",
                "Seen any good shows or movies recently?",
            ],
            "food": [
                "Had anything good to eat today?",
                "Tried any new food lately?",
            ],
            "weekend": [
                "Got any plans for the weekend?",
                "How was your weekend, by the way?",
            ],
            "fyp": [
                "How's your FYP coming along, by the way?",
                "Made any progress on your project lately?",
            ],
            "hobbies": [
                "Got any hobbies you've been enjoying lately?",
                "Done anything fun in your free time recently?",
            ],
            "memories": [
                "Any fun memories from this week?",
                "Anything memorable happen recently?",
            ],
            "weather": [
                "How's the weather been on your end?",
                "Has the weather been alright lately?",
            ],
            "games": [
                "Playing any games lately?",
                "Got any games you've been into recently?",
            ],
            "music": [
                "Listening to anything good lately?",
                "Got any songs on repeat recently?",
            ],
            "random": [
                "If you could instantly master any skill, what would it be?",
                "Would you rather travel to the past or the future?",
                "What's a small thing that made you smile recently?",
            ],
        }
        self.casual_ack_only = [
            "Nice 😊.", "Sounds good.", "Haha fair enough.", "Glad to hear that.",
            "That's nice.", "Cool.", "Nothing wrong with that.", "Gotcha 😄.",
        ]
        self.casual_openers = [
            "Sounds good 😊.", "Nice.", "Gotcha.", "Glad to hear that.", "Fair enough.",
        ]
        # ── casual_answer: acknowledgments specific to the TYPE of the bot's
        # own last question (day_status/emotion/...), never an entity. ──────
        self.casual_answer_acks = {
            "day_status": [
                "Glad to hear that 😊.", "Nice, glad it's going alright.",
                "That's good to hear.", "Glad today's been decent.",
            ],
            "emotion": [
                "Glad to hear that.", "That's good.", "Nice, glad you're feeling okay.",
                "Glad to hear things are okay 😊.",
            ],
        }
        self.casual_answer_default_ack = [
            "Nice.", "Sounds good.", "Got it, thanks for sharing that.",
        ]
        # ── event_continuation: the reply both answers AND elaborates on
        # the SAME topic ("nope, still raining" answering "How's the
        # weather?") -- keyed by the casual question's own type, then by a
        # keyword group naming the specific event/condition mentioned, so
        # the reply can react to that detail instead of a flat ack. Checked
        # in order, first keyword group to match wins.
        self.event_continuation_kws = {
            "weather": [
                (["rain", "raining", "rainy", "drizzl", "downpour"], [
                    "Sounds like the rain has been sticking around lately.",
                    "Yeah, constant rain can get tiring.",
                ]),
                (["storm", "stormy", "thunder"], [
                    "Sounds like the storms have been rough lately.",
                ]),
                (["hot", "heat", "humid"], [
                    "Sounds like the heat's been a lot lately.",
                ]),
                (["cold", "freezing", "chilly"], [
                    "Sounds like the cold has been rough lately.",
                ]),
                (["snow", "snowing", "snowy"], [
                    "Sounds like the snow has been a lot lately.",
                ]),
                (["cloudy", "gloomy", "grey", "gray"], [
                    "Sounds like it's been pretty gloomy out lately.",
                ]),
                (["sunny", "clear", "nice weather", "good weather"], [
                    "Nice, sounds like the weather's been on your side lately.",
                ]),
            ],
        }
        # ── (question type, answer_semantics category) -> response. Wins
        # over both casual_answer_acks and generic_semantic_acks below when
        # present, since it's the most specific combination of "what was
        # asked" and "what kind of answer this is" (e.g. progress +
        # small_positive -- "ya, but abit only" replying to "Made any
        # progress?" reads as a small win, not a complaint). ─────────────
        self.semantic_answer_banks = {
            ("progress", "small_positive"): [
                "Hey, progress is still progress 😊.",
                "Even a little progress counts.",
                "Nice 😄. Small steps are still steps.",
            ],
            ("progress", "small_negative"): [
                "That's alright, these things take time.",
                "No worries, even slow progress is still progress.",
            ],
            ("busy", "small_positive"): [
                "Sounds like you've had a few things on your plate.",
                "Fair, sounds like a bit of a busy stretch.",
            ],
            ("busy", "intensity"): [
                "Sounds like you've had a few things on your plate.",
                "Fair, sounds like a bit of a busy stretch.",
            ],
            ("emotion", "neutral"): [
                "Glad to hear things are okay 😊.",
                "That's good, glad you're doing okay.",
            ],
        }
        # ── generic, type-agnostic fallback per answer_semantics category --
        # used when the (type, semantic) combo above has no specific bank
        # and the question's own type (casual_answer_acks) doesn't apply
        # either (e.g. type="open"). ───────────────────────────────────────
        self.generic_semantic_acks = {
            "small_positive": [
                "Even a little counts 😊.", "Hey, that still counts for something.",
                "Nice, small steps still count.",
            ],
            "small_negative": [
                "That's alright, these things take time.",
                "No worries, not every day is the same.",
            ],
            "neutral": ["Glad to hear that.", "Nice, sounds steady.", "Got it, thanks."],
            "uncertain": [
                "That's okay, no need to have it all figured out.",
                "No worries, take your time with it.",
            ],
            "intensity": [
                "Sounds like a fair amount going on.",
                "Got it, sounds moderately busy.",
            ],
            "yes_no": ["Got it, thanks for letting me know.", "Nice, got it."],
        }
        # ── conversation_leader_mode: the user explicitly handed conversational
        # lead to the bot ("anything to chat?", "idk what to talk about", "up
        # to you") -- take initiative with a fresh topic instead of treating
        # "anything"/"idk" as an answer to be extracted as an entity. ────────
        self.conversation_leader_openers = [
            "Haha, sure 😄.", "Random question —", "We can talk about anything 😊.",
            "Sure, let's find something to talk about.", "Okay, let's see...",
        ]
        self.misunderstanding_repair_openers = [
            "Ah, I misunderstood 😄.", "No worries, thanks for correcting me.",
            "I see, I misunderstood that.", "Oops, my bad — thanks for the correction.",
        ]
        self.misunderstanding_repair_followups = [
            "What did you mean instead?", "Could you tell me what you meant?",
            "What were you trying to say?",
        ]
        self.CASUAL_QUESTION_BASE_PROB = 0.75
        self.CASUAL_QUESTION_DECAY = 0.25
        self.CASUAL_QUESTION_MIN_PROB = 0.15

    def _pick_casual(self, options: List[str], tracker: "UserContextTracker") -> str:
        """Anti-repeat against the same whole-message memory used elsewhere
        (tracker.recent_bot_responses) -- keeps casual replies from echoing
        the last few turns verbatim."""
        recent_texts = [r.get("text", "") for r in tracker.recent_bot_responses]
        fresh = [o for o in options if o not in recent_texts]
        pool = fresh if fresh else options
        choice = random.choice(pool)
        tracker.recent_bot_responses.append({"text": choice, "category": "casual"})
        if len(tracker.recent_bot_responses) > 5:
            tracker.recent_bot_responses.pop(0)
        return choice

    def _pick_casual_category(self, tracker: "UserContextTracker") -> str:
        categories = list(self.casual_followup_categories.keys())
        fresh = [c for c in categories if c not in tracker.recent_casual_categories]
        pool = fresh if fresh else categories
        category = random.choice(pool)
        tracker.recent_casual_categories.append(category)
        if len(tracker.recent_casual_categories) > 3:
            tracker.recent_casual_categories.pop(0)
        return category

    def _casual_followup_or_blank(self, tracker: "UserContextTracker") -> str:
        """Bare rotating-category followup question, with NO leading
        acknowledgment of its own -- callers already supply their own
        opener/ack, so this just decides (with decaying probability as
        tracker.consecutive_questions rises) whether to add a question on
        top of it, or return "" so the caller's ack stands alone (Problem:
        'Anything on your mind?' repeating every single turn)."""
        prob = max(
            self.CASUAL_QUESTION_MIN_PROB,
            self.CASUAL_QUESTION_BASE_PROB - self.CASUAL_QUESTION_DECAY * tracker.consecutive_questions,
        )
        if random.random() >= prob:
            return ""
        category = self._pick_casual_category(tracker)
        return self._pick_casual(self.casual_followup_categories[category], tracker)

    def _generate_casual_chat_response(self, tracker: "UserContextTracker") -> str:
        """Shared continuation for open_chat/casual_ack -- decreasing
        question probability the longer the bot has kept asking questions
        in a row, rotating followup topics, and sometimes just a plain
        acknowledgment with no question at all (Problem: 'Anything on your
        mind?' repeating endlessly)."""
        followup = self._casual_followup_or_blank(tracker)
        if not followup:
            return self._pick_casual(self.casual_ack_only, tracker)
        opener = self._pick_casual(self.casual_openers, tracker)
        return f"{opener} {followup}"

    def _generate_casual_answer_response(self, state: Dict[str, str], tracker: "UserContextTracker") -> str:
        """casual_answer: reply to the TYPE of the bot's own last casual
        question (day_status/emotion/...) AND the SHAPE of the answer itself
        (answer_semantics: small_positive/neutral/uncertain/...), never an
        entity -- this is the fix for both 'so far okeeie' -> 'Chat is
        what's been keeping you busy.' and 'ya, but abit only' -> 'So ya is
        where most of this is coming from.'

        Priority: event_continuation detail (reacts to the specific
        condition/event named, e.g. "still raining") -> (type, semantic)
        specific bank -> type-only ack (keeps the existing day_status/
        emotion tone for plain/neutral replies) -> semantic-only generic
        ack -> flat default."""
        answer_type = state.get("answer_type", "open")
        semantic = state.get("answer_semantic")
        detail_ack = (
            self._event_continuation_ack(answer_type, state.get("clean_text", ""), tracker)
            if semantic == "event_continuation" else None
        )
        combo_bank = self.semantic_answer_banks.get((answer_type, semantic))
        if detail_ack:
            ack = detail_ack
        elif combo_bank:
            ack = self._pick_casual(combo_bank, tracker)
        elif answer_type in self.casual_answer_acks and semantic in (None, "neutral", "yes_no"):
            ack = self._pick_casual(self.casual_answer_acks[answer_type], tracker)
        elif semantic and semantic in self.generic_semantic_acks:
            ack = self._pick_casual(self.generic_semantic_acks[semantic], tracker)
        else:
            ack = self._pick_casual(self.casual_answer_default_ack, tracker)
        followup = self._casual_followup_or_blank(tracker)
        return f"{ack} {followup}" if followup else ack

    def _event_continuation_ack(
        self, answer_type: str, clean_text: str, tracker: "UserContextTracker"
    ) -> Optional[str]:
        """Reacts to the specific event/condition named in an
        event_continuation reply ("nope, still raining" -> the rain group
        under "weather") instead of a flat acknowledgment. Returns None
        when answer_type has no keyword groups, or none match, so the
        caller falls back through its normal ack chain."""
        for keywords, lines in self.event_continuation_kws.get(answer_type, []):
            if any(kw in clean_text for kw in keywords):
                return self._pick_casual(lines, tracker)
        return None

    def _generate_misunderstanding_repair_response(self, tracker: "UserContextTracker") -> str:
        """Acknowledge a misread before continuing -- humans acknowledge
        mistakes. Stays light if the prior thread was casual small talk
        (no clinical 'what's really going on' pivot for a mismatched 'how's
        your day' reply); otherwise asks what the user actually meant."""
        opener = self._pick_casual(self.misunderstanding_repair_openers, tracker)
        pending_type = tracker.pending_question.get("type")
        if pending_type and pending_type != "open":
            followup = self._casual_followup_or_blank(tracker)
            return f"{opener} {followup}" if followup else opener
        continuation = self._pick_casual(self.misunderstanding_repair_followups, tracker)
        return f"{opener} {continuation}"

    def _generate_topic_suggestion_response(self, tracker: "UserContextTracker") -> str:
        """conversation_leader_mode: the user ran out of things to say and
        explicitly handed the lead back ("anything to chat?", "up to you",
        "idk what to talk about") -- propose a topic ourselves instead of
        treating "anything"/"idk" as a real-world entity to elaborate on."""
        opener = self._pick_casual(self.conversation_leader_openers, tracker)
        category = self._pick_casual_category(tracker)
        question = self._pick_casual(self.casual_followup_categories[category], tracker)
        return f"{opener} {question}"

    # A bare, unqualified feeling word ("I'm tired", "I feel off") is
    # genuinely ambiguous -- ask which kind rather than guessing (confidence
    # scoring layer, see AdvancedNLUPipeline.AMBIGUOUS_EMOTION_EXACT and
    # state["confidence"] in _annotate_distress).
    AMBIGUOUS_EMOTION_CLARIFY_QUESTIONS = {
        "tired": "When you say you're tired, do you mean physically exhausted, stressed, or emotionally drained?",
        "exhausted": "When you say you're exhausted, do you mean physically worn out, stressed, or emotionally drained?",
        "drained": "When you say you feel drained, do you mean physically, mentally, or emotionally?",
        "off": "When you say you feel off, do you mean physically, mentally, or something else entirely?",
        "weird": "When you say you feel weird, what's that like for you -- more physical, or more in your head?",
        "not myself": "When you say you're not feeling like yourself, what's that like for you right now?",
        "blah": "When you say you feel blah, what's that like for you right now?",
        "meh": "When you say you feel meh, what's that like for you right now?",
    }

    def _generate_ambiguous_emotion_clarify_response(self, state: Dict[str, str]) -> str:
        term = state.get("ambiguous_emotion_term", "tired")
        return self.AMBIGUOUS_EMOTION_CLARIFY_QUESTIONS.get(
            term, "When you say that, what's that like for you right now -- more physical, or more emotional?"
        )

    def _pick_crisis(self, pool: List[str], tracker: "UserContextTracker", used_this_turn: List[str]) -> str:
        """Anti-repeat across the last several crisis turns
        (tracker.recent_crisis_phrases) AND within this single response
        (used_this_turn) -- mirrors ComponentNLGEngine's _pick_fresh."""
        recent = tracker.recent_crisis_phrases + used_this_turn
        fresh = [o for o in pool if o not in recent]
        choice = random.choice(fresh if fresh else pool)
        used_this_turn.append(choice)
        return choice

    def compose_crisis_response(self, state: Dict[str, str], tracker: "UserContextTracker") -> Tuple[str, bool]:
        """Adaptive, rotating, non-repetitive crisis continuation response.
        Used for crisis_followup turns and for emergency_crisis/crisis_risk
        re-triggers once their one-time canned first-contact message has
        already been shown this session. Returns (response_text, asked_question)."""
        clean = state.get("clean_text", "")
        core = clean.strip().rstrip(".!?,;:")
        stage = max(1, tracker.crisis_stage)
        used_this_turn: List[str] = []
        parts: List[str] = []

        if tracker.in_crisis_cooldown:
            # Problem 8: tapering, supportive, never interrogating.
            parts.append(self._pick_crisis(self.crisis_cooldown_statements, tracker, used_this_turn))
            asked = False
            if random.random() < 0.3:
                q = self._pick_crisis(self.crisis_cooldown_questions, tracker, used_this_turn)
                if q != tracker.last_crisis_question:
                    parts.append(q)
                    tracker.last_crisis_question = q
                    asked = True
            if not asked:
                tracker.last_crisis_question = None
        elif core in self.CRISIS_LOW_CONTENT_REPLIES:
            # Problem 6: "I don't know"/"whatever" -- stay present, no
            # interrogation, no repeated asks for info already known.
            parts.append(self._pick_crisis(self.crisis_presence_templates, tracker, used_this_turn))
            if tracker.recent_loneliness:
                parts.append(self._pick_crisis(self.crisis_connection_broadened_templates, tracker, used_this_turn))
            else:
                parts.append(self._pick_crisis(self.crisis_grounding_statements, tracker, used_this_turn))
            tracker.last_crisis_question = None
        elif any(p in clean for p in self.CRISIS_SLEEP_CUES):
            # Problem 6: "Maybe I'll sleep" -- encourage getting through tonight.
            parts.append(self._pick_crisis(self.crisis_presence_templates, tracker, used_this_turn))
            parts.append(self._pick_crisis(self.crisis_tonight_statements, tracker, used_this_turn))
            tracker.last_crisis_question = None
        elif state.get("mentions_loneliness_now"):
            # Problem 3/6: address loneliness directly, broadened beyond
            # "friends" -- never just "talk to someone you trust" alone.
            parts.append(self._pick_crisis(self.crisis_connection_templates, tracker, used_this_turn))
            parts.append(self._pick_crisis(self.crisis_connection_broadened_templates, tracker, used_this_turn))
            tracker.last_crisis_question = None
        else:
            # Generic stage-aware continuation -- presence/validation opener,
            # then a throttled, stage-appropriate question (or a grounding/
            # resource statement when the question roll doesn't hit).
            opener_pool = self.crisis_presence_templates + self.crisis_validation_templates
            parts.append(self._pick_crisis(opener_pool, tracker, used_this_turn))
            # Loneliness already established -- reinforce occasionally rather
            # than every single turn (that would feel repetitive/lecturing,
            # not calm and present); the dedicated branch above already
            # handles it fully the turn it's freshly mentioned.
            if tracker.recent_loneliness and random.random() < 0.35:
                parts.append(self._pick_crisis(self.crisis_connection_broadened_templates, tracker, used_this_turn))

            question_prob = self.CRISIS_QUESTION_PROBABILITY.get(stage, 0.5)
            ask_question = random.random() < question_prob
            question_bank = {
                1: self.crisis_clarify_questions,
                2: self.crisis_safety_questions,
                3: self.crisis_immediacy_questions,
                4: self.crisis_safety_questions,
            }.get(stage, self.crisis_clarify_questions)

            chosen_question = None
            if ask_question:
                candidate = self._pick_crisis(question_bank, tracker, used_this_turn)
                # Problem 1/5: never repeat the exact same question twice in a row.
                if candidate != tracker.last_crisis_question:
                    chosen_question = candidate

            if chosen_question:
                parts.append(chosen_question)
                tracker.last_crisis_question = chosen_question
            else:
                tracker.last_crisis_question = None
                fallback_pool = self.crisis_grounding_statements
                if stage >= 4:
                    fallback_pool = self.crisis_grounding_statements + self.crisis_resource_reminders
                parts.append(self._pick_crisis(fallback_pool, tracker, used_this_turn))

        response = " ".join(p.strip() for p in parts if p)
        tracker.recent_crisis_phrases.extend(used_this_turn)
        if len(tracker.recent_crisis_phrases) > 5:
            tracker.recent_crisis_phrases = tracker.recent_crisis_phrases[-5:]
        return response, "?" in response

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
            # ── Safety Override Layer: ambiguous risk language ("I want to
            # jump", "I can't do this anymore") gets a direct, caring
            # clarifying question rather than either being ignored or
            # assumed to be definite suicidal intent. [phrase] is replaced
            # with a second-person echo of what the user actually said
            # (see AdvancedNLUPipeline.CRISIS_RISK_ECHO). ──────────────────
            "crisis_risk_check": [
                (
                    "Thank you for telling me that. Hearing you say that makes me want to understand a little more. "
                    "When you say [phrase], are you having thoughts about hurting yourself, or are you feeling "
                    "overwhelmed in another way? I'm here with you."
                )
            ],
            "crisis_risk_followup": [
                (
                    "Thank you for telling me. I just wanted to check in, because what you said worried me and your "
                    "safety matters to me. It still sounds like things feel really heavy right now — can you tell me "
                    "more about what's been overwhelming you?"
                ),
            ],
            # NOTE: Persistent Crisis Mode continuation ("crisis_continuation"
            # strategy) is no longer a static template bank -- it's composed
            # adaptively by HumanResponseGenerator.compose_crisis_response()
            # (rotating templates, stage/content-aware, contradiction-aware,
            # question-throttled -- see Problems 1/4/5/6).
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
                "Glad to hear it. Anything on your mind, or just dropping by?",
                "Nice. Want to chat about something, or just checking in?",
            ],
            "gentle_pivot": [
                "That's okay, a quiet day counts too.",
                "Fair enough, not every day needs to be a big one.",
            ],
            # ── casual companion mode: short, breezy acknowledgments
            # ("okeie", "lol", "kk") -- no validation, no emotional
            # assumptions, no "I'm here with you" -- just stay light and
            # natural, the way a friend would respond to a one-word reply.
            "casual_ack_strategy": [
                "Sounds good 😊.",
                "Fair enough, haha.",
                "Nice.",
                "Glad to hear that.",
                "Nothing wrong with that.",
                "Cool, cool.",
                "Haha alright. Anything interesting happen today?",
                "All good. What have you been up to recently?",
                "Gotcha 😄.",
            ],
            # ── accomplishment: the user reported finishing/completing
            # something with no distress language attached -- acknowledge the
            # achievement plainly, do not validate a struggle that was never
            # expressed (Topic != Emotion).
            "accomplishment_ack": [
                "Sounds like you managed to get quite a bit done today.",
                "It's nice to hear you made some progress.",
                "A fairly normal day can sometimes be a welcome thing.",
                "Good to hear you got through what you needed to today.",
                "Nice, sounds like you checked off what you set out to do.",
                "That's a solid way to spend the day, glad it went smoothly.",
            ],
            # ── new_topic: a bare trailing-off pivot ("by the way...",
            # "actually...") -- invite the new content, don't guess at it.
            "new_topic_strategy": [
                "Sure, what's up?",
                "Go ahead, I'm listening.",
                "What's on your mind?",
                "Oh? What's up?",
            ],
            "low_engagement_strategy": [
                "That's okay, you don't need to find the right words right now. I'm still here whenever you're ready.",
                "No worries. Sometimes there isn't a clear answer, and that's fine — I'm not going anywhere.",
                "That's alright. We can just sit with this for a moment if that feels easier.",
                "It's okay not to know. Take your time — I'll be here when you want to say more.",
            ],
            # repair_statement: the user is re-explaining/apologizing for
            # their OWN earlier wording ("sorry again", "i mean", "let me
            # explain again") -- no apology is actually needed, and nothing
            # here should read as advancing the topic or asking a new
            # question (see NO_STAGE_CHANGE_STRATEGIES in stage_engine.py).
            "repair_statement_strategy": [
                "No need to apologize 😊. It's okay to revisit the same thoughts.",
                "No need to apologize — sometimes we need to say things more than once to understand them ourselves.",
                "That's okay, take your time. It's okay to revisit the same thoughts as many times as you need.",
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
                "Sounds good 😊. Happy to just chat. How's your day been so far?",
                "Glad you came by. What's been going on lately?",
                "Nice, anything interesting happen today?",
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
            # NOTE: deliberately named without "support" so it routes through
            # the static _pick() bank below instead of ComponentNLGEngine --
            # mixed-feelings ambivalence needs this specific validating shape
            # ("it sounds confusing...torn") rather than the generic
            # topic/event-category-driven composition the other "_support"
            # keys get.
            "relationship_uncertainty_response": [
                "It sounds confusing -- part of you can see that they care, but another part of you still doesn't feel loved. What's been happening that makes it feel that way?",
                "Having mixed feelings like that can leave you feeling really torn. What's weighing on you most about it?",
                "That sounds hard to sit with -- feeling cared for sometimes, but not always feeling loved. When do you notice that doubt the most?",
                "It makes sense to feel torn when the good moments and the doubt are both real at the same time. What's been on your mind about it?",
            ],
            # Synthesis stage (Problem 3): recap the pattern across the last
            # few turns and show understanding -- deliberately no trailing
            # question, since synthesis's whole point is to summarize before
            # moving on, not to keep exploring.
            "relationship_synthesis_response": [
                "It sounds like you appreciate how he treats you and the care he shows, but emotionally something still feels missing. That's leaving you feeling torn about whether breaking up would solve the pain or create a different kind of pain.",
                "Putting it together, there's real care here, but also a quieter sense that something isn't being met -- and that mix is exactly what makes this so hard to sit with.",
                "It sounds like this isn't really about whether he's a good person -- it's about whether what you're getting is enough for what you actually need.",
            ],
            # NOTE: deliberately named without "support" so it routes
            # through the static _pick() bank below instead of
            # ComponentNLGEngine -- same reasoning as
            # relationship_uncertainty_response above.
            "fear_of_breakup_response": [
                "It sounds like part of this pain comes from not knowing what life would feel like after letting go. What scares you most about that?",
                "It makes sense to be afraid of what comes after -- the unknown of being on your own can feel just as heavy as the relationship itself. What feels scariest about being alone?",
                "Some of this fear might not be about him at all -- it could be about facing life without him. Does that feel true for you?",
            ],
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

        # ── [phrase] placeholder: echoes back the risk language that
        # triggered the Safety Override Layer's crisis_risk_check response. ──
        if "[phrase]" in choice:
            phrase = tracker.last_crisis_phrase or "that"
            choice = choice.replace("[phrase]", phrase)

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

        # Attention Lock System: while locked, the locked domain/entity/event
        # take priority over whatever event_category/entity resolution would
        # otherwise apply -- this is what stops a stale persisted event (e.g.
        # an old "10 modules to go") from outranking a fresher, more specific
        # focus (e.g. "backend") that the user is actually talking about now.
        attention_active = (
            tracker.attention.lock_turns_remaining > 0 and bool(tracker.attention.focus_domain)
        )
        if attention_active:
            event_category = tracker.attention.focus_domain
            entity = tracker.attention.focus_entity or entity
            event_phrase = tracker.attention.focus_event
        else:
            event_category = state.get("event_category") or tracker.current_event_category
            event_phrase = tracker.current_event

        attention_shift = None
        if state.get("attention_shifted"):
            labels = state.get("attention_domain_labels", {})
            prev_label = labels.get(state.get("attention_previous_domain"), "what we were just discussing")
            new_label = labels.get(tracker.attention.focus_domain, "this")
            attention_shift = (prev_label, new_label)

        response, used_phrases, used_categories = self.component_engine.generate_response(
            emotion_intent=state.get("intent", ""),
            topic_entity=entity,
            stage=stage,
            meaning_shift=state.get("meaning_shift"),
            event_category=event_category,
            action_options=action_options,
            event_phrase=event_phrase,
            repetition_cue=state.get("repetition_cue", False),
            progress_detail=state.get("progress_detail") or tracker.current_progress_detail,
            choice_options=choice_options,
            has_evidence=tracker.technical_failure_evidence,
            has_emotional_evidence=tracker.emotional_evidence,
            new_info=state.get("new_info", False),
            new_entity_this_turn=state.get("new_entity_this_turn", False),
            attention_shift=attention_shift,
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

        # ── Persistent Crisis Mode's ongoing, adaptive continuation
        # (Problems 1/4/5/6) -- dispatched first/separately since it's
        # composed dynamically, not looked up from a static template bank. ──
        if strategy == "crisis_continuation":
            response, has_question = self.compose_crisis_response(state, tracker)
            return response, ("open_emotion" if has_question else None)

        # ── Casual Companion Mode: dynamic, diverse continuation (Problem:
        # answer-type binding + endless "Anything on your mind?" loops) --
        # dispatched before the static STRATEGY_MAP lookup below, same
        # pattern as crisis_continuation above. ────────────────────────────
        if strategy in ("open_chat", "casual_ack_strategy"):
            response = self._generate_casual_chat_response(tracker)
            return response, ("open_emotion" if "?" in response else None)
        if strategy == "casual_answer_strategy":
            response = self._generate_casual_answer_response(state, tracker)
            return response, ("open_emotion" if "?" in response else None)
        if strategy == "misunderstanding_repair_strategy":
            response = self._generate_misunderstanding_repair_response(tracker)
            return response, ("open_emotion" if "?" in response else None)
        if strategy == "conversation_leader_strategy":
            response = self._generate_topic_suggestion_response(tracker)
            return response, ("open_emotion" if "?" in response else None)
        if strategy == "ambiguous_emotion_clarify_strategy":
            response = self._generate_ambiguous_emotion_clarify_response(state)
            return response, "clarify"

        # strategy → (response_key, question_type)
        STRATEGY_MAP: Dict[str, Tuple[str, Optional[str]]] = {
            # session
            "escalation":                       ("crisis",                          None),
            # Safety Override Layer (note: response-bank keys deliberately
            # avoid the substring "support" so they are NOT routed through
            # ComponentNLGEngine below -- this wording must stay exact/fixed).
            "crisis_support":                   ("crisis_risk_check",               "open_emotion"),
            "crisis_followup_support":          ("crisis_risk_followup",            "open_emotion"),
            # NOTE: "crisis_continuation" (Persistent Crisis Mode's ongoing,
            # adaptive multi-turn response -- Problems 1/4/5/6) is handled as
            # a special case below, via compose_crisis_response(), not through
            # this static key->bank lookup.
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
            "relationship_uncertainty_response":("relationship_uncertainty_response","open_emotion"),
            "fear_of_breakup_response":         ("fear_of_breakup_response",        "open_emotion"),
            "relationship_synthesis_response":  ("relationship_synthesis_response", None),
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
            "accomplishment_ack":               ("accomplishment_ack",              None),
            "new_topic_strategy":                ("new_topic_strategy",              "open_emotion"),
            "open_chat":                        ("open_chat",                       "open_emotion"),
            "casual_ack_strategy":              ("casual_ack_strategy",             None),
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
            "repair_statement_strategy":        ("repair_statement_strategy",       None),
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
    "escalation", "crisis_support", "crisis_continuation",
    "close", "greeting", "graceful_close_or_continue",
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

        # ── Pending-Question Type Binding: only casual-tier strategies tag
        # tracker.pending_question -- the deep clinical flows already have
        # their own awaiting_* mechanisms and must be left untouched. ──────
        CASUAL_STRATEGIES = {
            "open_chat", "casual_ack_strategy", "explore_checkin", "greeting",
            "casual_answer_strategy", "misunderstanding_repair_strategy",
            "conversation_leader_strategy", "new_topic_strategy",
        }
        if strategy in CASUAL_STRATEGIES and "?" in response:
            tracker.pending_question = {
                "type": self.nlu._classify_casual_question_type(response),
                "topic": state.get("topic"),
                "text": response,
                "answered": False,
            }
        else:
            tracker.pending_question["answered"] = True

        # Attention Lock decay: a turn that didn't freshly re-mention the
        # locked domain spends one turn of the lock's remaining budget. A
        # fresh mention already reset it to 3 in analyze(), so skip decaying
        # the very turn that just set/refreshed it.
        if not state.get("attention_fresh_match") and tracker.attention.lock_turns_remaining > 0:
            tracker.attention.lock_turns_remaining -= 1
            if tracker.attention.lock_turns_remaining <= 0:
                tracker.attention.lock_strength = 0.0

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