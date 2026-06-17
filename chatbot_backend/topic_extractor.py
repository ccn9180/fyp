import re
import joblib
import spacy
import os

REPETITION_CUES = [
    "again", "another time", "once more", "still", "keep having to",
    "keeps happening", "every time", "over and over", "yet again",
    "once again", "keep getting", "keep being asked", "keep ", "keeps ",
    "always", "every time",
]

# Leading conversational fillers -- stripped before noun-phrase/event parsing so
# they never get mistaken for the actual answer (e.g. "ermm, my core tech").
FILLER_PATTERN = re.compile(r'^(?:(?:erm+|umm?|uhh?|hmm+|well|actually|maybe)[\s,.]*)+', re.IGNORECASE)


class TopicExtractor:
    def __init__(self, model_path="topic_model.pkl"):
        print("[SYS] Loading Topic Extraction Models...")
        
        # Load spaCy for Noun Phrase extraction
        try:
            self.nlp = spacy.load("en_core_web_sm")
        except OSError:
            print("⚠️ en_core_web_sm not found. Run: python -m spacy download en_core_web_sm")
            self.nlp = None
            
        # Load the custom TF-IDF + Logistic Regression model
        if os.path.exists(model_path):
            self.topic_model = joblib.load(model_path)
        else:
            print(f"[WARNING] Topic model {model_path} not found. Run topic_train.py first.")
            self.topic_model = None

    def extract(self, text: str) -> dict:
        result = {
            "topic_category": "general",
            "topic_entity": None,
            "event_phrase": None,
            "repetition_cue": False,
        }

        if not text or not text.strip():
            return result

        result["repetition_cue"] = any(cue in text.lower() for cue in REPETITION_CUES)

        # 1. Predict Topic Category using ML model
        if self.topic_model:
            pred = self.topic_model.predict([text])[0]
            probs = self.topic_model.predict_proba([text])[0]
            max_prob = max(probs)
            
            # Confidence threshold
            if max_prob > 0.4:
                result["topic_category"] = pred
                
        # 2. Extract specific Noun Phrase using spaCy
        if self.nlp:
            parse_text = self._strip_fillers(text)
            doc = self.nlp(parse_text)
            
            # Simple heuristic: find the main object or subject of the sentence
            # We want phrases like "my supervisor", "my final year project", "my boyfriend"
            candidate_phrases = []
            
            for chunk in doc.noun_chunks:
                # Filter out basic pronouns and bare WH-words ("what"/"how" parsed
                # as a pronoun in fragments like "I don't know what to do") --
                # neither makes a meaningful topic entity.
                if chunk.text.lower() in [
                    "i", "me", "you", "he", "she", "it", "they", "we",
                    "what", "who", "whom", "which", "where", "when", "why", "how",
                ]:
                    continue
                    
                # Store the root dependency for scoring
                root_dep = chunk.root.dep_
                
                score = 0
                if root_dep in ("dobj", "pobj"): # Direct object or object of preposition often represents the topic
                    score += 2
                elif root_dep == "nsubj" and chunk.root.head.lemma_ != "be": # subject of an action verb
                    score += 1
                    
                # Penalize very long chunks which might be whole sentences
                if len(chunk.text.split()) > 5:
                    score -= 1
                    
                candidate_phrases.append((score, chunk.text))
                
            if candidate_phrases:
                # Sort by score descending
                candidate_phrases.sort(key=lambda x: x[0], reverse=True)
                
                # Take the highest scoring phrase and do basic pronoun flipping
                best_phrase = candidate_phrases[0][1]
                
                # Basic flip: "my supervisor" -> "your supervisor"
                # This will be passed to NLG templates
                best_phrase_lower = best_phrase.lower()
                if best_phrase_lower.startswith("my "):
                    best_phrase = "your " + best_phrase[3:]
                elif best_phrase_lower.startswith("i am "):
                    best_phrase = "you are " + best_phrase[5:]
                    
                result["topic_entity"] = best_phrase

            result["event_phrase"] = self._extract_event_phrase(doc)

        return result

    def _strip_fillers(self, text: str) -> str:
        match = FILLER_PATTERN.match(text)
        if not match:
            return text
        stripped = text[match.end():].strip()
        return stripped if stripped else text

    def _flip_pronoun(self, phrase: str) -> str:
        phrase_lower = phrase.lower()
        if phrase_lower.startswith("my "):
            return "your " + phrase[3:]
        if phrase_lower.startswith("i am "):
            return "you are " + phrase[5:]
        return phrase

    def _extract_event_phrase(self, doc):
        """Lightweight verb+object extraction, e.g. 'revise your proposal'.
        Rule/dependency-parse based -- no training data, no new model."""
        root = next((t for t in doc if t.dep_ == "ROOT" and t.pos_ in ("VERB", "AUX")), None)
        if root is None or root.lemma_ == "be":
            return None

        # Prefer a controlled embedded clause ("asked me to revise...", "need to
        # finish...") over the outer verb -- it usually names the actual action
        # more specifically than a generic reporting/modal verb like "ask"/"need".
        xcomp = next(
            (c for c in root.children if c.dep_ in ("xcomp", "ccomp") and c.pos_ in ("VERB", "AUX")),
            None,
        )
        action_verb = xcomp if xcomp is not None else root

        complement = next(
            (c for c in action_verb.children if c.dep_ in ("dobj", "attr", "oprd")),
            None,
        )
        if complement is None:
            prep = next((c for c in action_verb.children if c.dep_ == "prep"), None)
            if prep is not None:
                pobj = next((c for c in prep.children if c.dep_ == "pobj"), None)
                if pobj is not None:
                    span = doc[pobj.left_edge.i: pobj.right_edge.i + 1]
                    return f"{action_verb.lemma_} {prep.text} {self._flip_pronoun(span.text)}"
            return None

        span = doc[complement.left_edge.i: complement.right_edge.i + 1]
        # Skip overly long spans, or ones that are themselves a verb clause --
        # both read badly when slotted into "having to {event}" templates.
        if len(span.text.split()) > 6 or span.root.pos_ in ("VERB", "AUX"):
            return None
        return f"{action_verb.lemma_} {self._flip_pronoun(span.text)}"

# Quick test if run directly
if __name__ == "__main__":
    extractor = TopicExtractor()
    tests = [
        "My supervisor rejected my proposal.",
        "I feel like my boyfriend is drifting away.",
        "I don't have enough money for rent."
    ]
    for t in tests:
        print(f"Text: '{t}' -> {extractor.extract(t)}")
