import re
import joblib
import spacy
import os
from sentence_transformers import SentenceTransformer
from summarizer import ExtractiveSummarizer

# Must match the model name used in hashtag_train.py -- hashtag_model.pkl only
# stores the classifier head (see that file's comments for why), so inference
# has to re-create the exact same embedding space the classifier was fit on.
HASHTAG_EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"

REPETITION_CUES = [
    "again", "another time", "once more", "still", "keep having to",
    "keeps happening", "every time", "over and over", "yet again",
    "once again", "keep getting", "keep being asked", "keep ", "keeps ",
    "always", "every time", "every week", "repeatedly", "again and again",
]

# Leading conversational fillers -- stripped before noun-phrase/event parsing so
# they never get mistaken for the actual answer (e.g. "ermm, my core tech").
FILLER_PATTERN = re.compile(r'^(?:(?:erm+|umm?|uhh?|hmm+|well|actually|maybe)[\s,.]*)+', re.IGNORECASE)

# Trailing hedges ("my fyp i think", "my backend i guess") -- spaCy's parser
# attaches a short noun phrase as a dependent of the trailing verb instead of
# forming its own noun chunk (worse for domain jargon like "fyp", which it
# doesn't recognize as a noun), so the real answer never gets extracted as an
# entity at all. Stripping the hedge first gives the parser a clean NP.
TRAILING_HEDGE_PATTERN = re.compile(
    r'[\s,]+\b(i think|i guess|i suppose|i believe|i feel like|i reckon|probably|maybe)\.?\s*$',
    re.IGNORECASE,
)

# Conversational filler/particles/pronouns that must never be picked as a
# noun-chunk topic_entity (see the noun_chunks loop in extract() below) --
# kept at module level so both the exact list and its letter-collapsed
# variants (for catching elongated spellings like "nopee"/"yeaaa") are
# defined once.
FILLER_ENTITY_EXCLUSIONS = {
    "i", "me", "you", "he", "she", "it", "they", "we",
    "him", "her", "them", "us",
    "what", "who", "whom", "which", "where", "when", "why", "how",
    "anything", "something", "nothing", "everything", "idk",
    "whatever", "up to you", "you",
    "ya", "yeah", "yep", "yup", "yes", "yea", "no", "nah", "nope",
    "hmm", "erm", "uh", "um", "okay", "ok", "abit", "a bit",
    "maybe", "i guess", "sort of", "kind of", "not really",
    "today", "yesterday", "tomorrow", "tonight",
}


def _collapse_repeated_letters(word: str) -> str:
    """'nopee' -> 'nope', 'yeaaa' -> 'yea' -- collapses any run of the same
    letter down to one occurrence so an elongated/typo'd spelling of a
    short filler word still matches its canonical form."""
    return re.sub(r'(.)\1+', r'\1', word)


_FILLER_ENTITY_EXCLUSIONS_COLLAPSED = {
    _collapse_repeated_letters(w) for w in FILLER_ENTITY_EXCLUSIONS if " " not in w
}


def _is_filler_entity(chunk_text_lower: str) -> bool:
    if chunk_text_lower in FILLER_ENTITY_EXCLUSIONS:
        return True
    return (
        " " not in chunk_text_lower
        and _collapse_repeated_letters(chunk_text_lower) in _FILLER_ENTITY_EXCLUSIONS_COLLAPSED
    )


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

        # Load the Hashtag ML model -- hashtag_model.pkl is just the
        # classifier head (LogisticRegression), trained on sentence
        # embeddings rather than TF-IDF (see hashtag_train.py). The embedder
        # itself is loaded separately here, not pickled alongside the
        # classifier, so the saved model stays a small, version-stable
        # artifact instead of bundling the full transformer's weights.
        hashtag_model_path = "hashtag_model.pkl"
        if os.path.exists(hashtag_model_path):
            self.hashtag_model = joblib.load(hashtag_model_path)
            self.hashtag_embedder = SentenceTransformer(HASHTAG_EMBEDDING_MODEL_NAME)
        else:
            print(f"[WARNING] Hashtag model {hashtag_model_path} not found. Run hashtag_train.py first.")
            self.hashtag_model = None
            self.hashtag_embedder = None

        self.summarizer = ExtractiveSummarizer()
        
        # Semantic mapping dictionaries
        self.semantic_rules = {
            "academic": ["class", "assignment", "assignments", "exam", "exams", "test", "school", "college", "study", "studying", "homework", "grades", "project", "presentation", "essay", "module", "lecture", "tutorial", "university"],
            "social": ["friend", "friends", "people", "party", "gathering", "hangout", "meetup", "crowd", "social"],
            "friendshipConflict": ["argument", "fight", "disagreement", "ignored", "ghosted", "betrayed", "backstabbed"],
            "relationshipConflict": ["boyfriend", "girlfriend", "partner", "wife", "husband", "breakup", "ex", "date", "dating"],
            "family": ["mom", "dad", "parent", "brother", "sister", "family", "relative", "mother", "father"],
            "work": ["boss", "job", "manager", "shift", "colleague", "coworker", "meeting", "work", "office", "working"],
            "health": ["sick", "ill", "doctor", "hospital", "pain", "hurt", "injury", "sleep", "insomnia", "tired", "exhausted"],
            "finance": ["money", "rent", "broke", "pay", "bills", "expensive", "debt"],
        }
        
        self.cognitive_patterns = {
            "overwhelmed": ["overwhelmed", "too much", "drowning", "cope", "heavy", "pressure", "burden"],
            "anxiety": ["worry", "worried", "racing", "panic", "nervous", "anxious", "dread", "scared", "fear", "afraid"],
            "loneliness": ["lonely", "alone", "isolated", "no one", "empty"],
            "sadness": ["sad", "depressed", "down", "crying", "cry", "upset", "tears"],
            "burnout": ["exhausted", "done", "anymore", "drained", "burnt out", "tired"],
            "lowSelfEsteem": ["useless", "stupid", "failure", "hate myself", "not good enough", "worthless"],
        }
        
        self.positive_indicators = {
            "productiveDay": ["productive", "finished", "completed", "handled", "worked out"],
            "dailyCheckIn": ["normal", "okay", "fine", "routine", "usual", "today was"],
            "hopeful": ["hopeful", "optimistic", "looking forward", "excited", "good"],
            "grateful": ["grateful", "thankful", "blessed", "appreciate", "glad"],
        }

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
                result["topic_confidence"] = float(max_prob)
                
            # Manual heuristic override
            text_lower = text.lower()
            if any(w in text_lower for w in ["relationship", "breakup", "boyfriend", "girlfriend", "partner", "wife", "husband", "my ex"]):
                result["topic_category"] = "relationship_loss"
                result["topic_confidence"] = 1.0
                
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
                # neither makes a meaningful topic entity. Indefinite pronouns
                # ("anything", "idk", "up to you") are included too -- they show
                # up when the user hands conversational lead back to the bot
                # ("anything to chat?"), and spaCy can mis-tag them as the noun
                # object of a verb, producing nonsense like "Anything is what's
                # been keeping you busy."
                # Conversational filler/particles ("ya", "abit", "okay", "hmm")
                # are modifiers, not entities -- without this, a reply like
                # "ya, but abit only" gets "ya" extracted as the noun subject,
                # producing nonsense like "So ya is where most of this is
                # coming from." (see AdvancedNLUPipeline.answer_semantics(),
                # which is the primary fix and should normally intercept
                # these first; this list is the defense-in-depth backstop.)
                # Bare temporal nouns ("Today was pretty normal.") -- spaCy
                # parses "Today" as the grammatical subject, not a real
                # topic worth remembering as an entity -- are folded into
                # FILLER_ENTITY_EXCLUSIONS above. _is_filler_entity() also
                # catches letter-elongated spellings ("nopee", "yeaaa") that
                # an exact list match alone would miss.
                if _is_filler_entity(chunk.text.lower()):
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
        stripped = text[match.end():].strip() if match else text
        stripped = TRAILING_HEDGE_PATTERN.sub('', stripped).strip()
        return stripped if stripped else text

    def _flip_pronoun(self, phrase: str) -> str:
        phrase_lower = phrase.lower()
        if phrase_lower.startswith("my "):
            return "your " + phrase[3:]
        if phrase_lower.startswith("i am "):
            return "you are " + phrase[5:]
        return phrase

    # Bare possession verbs read fine on their own ("I have three
    # assignments") but every NLG template wraps event_phrase as "having to
    # {event}" -- "having to have three assignments" stutters on the
    # repeated verb. Swap in a neutral action verb so the wrapped form
    # ("having to deal with three assignments") stays grammatical.
    EVENT_VERB_LEMMA_OVERRIDES = {"have": "deal with", "has": "deal with"}

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
        verb_lemma = self.EVENT_VERB_LEMMA_OVERRIDES.get(action_verb.lemma_, action_verb.lemma_)

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
                    if _is_filler_entity(span.text.lower()):
                        return None
                    return f"{verb_lemma} {prep.text} {self._flip_pronoun(span.text)}"
            return None

        span = doc[complement.left_edge.i: complement.right_edge.i + 1]
        # Skip overly long spans, or ones that are themselves a verb clause --
        # both read badly when slotted into "having to {event}" templates.
        # A bare WH-word object ("What should I do?" -> dobj "what") is the
        # same kind of non-entity as a filler particle -- "having to do
        # what" reads as nonsense, so it's excluded via the same
        # _is_filler_entity() check the noun-chunk loop above uses.
        if (
            len(span.text.split()) > 6
            or span.root.pos_ in ("VERB", "AUX")
            or _is_filler_entity(span.text.lower())
        ):
            return None
        return f"{verb_lemma} {self._flip_pronoun(span.text)}"

    def extract_hashtags(self, text: str, top_n: int = 5) -> list:
        """Extract dynamic hashtags from text using spaCy."""
        if not self.nlp or not text or not text.strip():
            return []
        
        doc = self.nlp(text.lower())
        candidates = []
        
        # Expanded ignore list for mental health journaling context
        ignore_words = {
            "today", "tomorrow", "yesterday", "day", "week", "month", "year", "time", "thing", "things", 
            "people", "someone", "anyone", "everyone", "nobody", "something", "anything", "nothing", 
            "everything", "way", "lot", "bit", "kind", "sort", "type", "part", "half", "rest", "front", 
            "back", "top", "bottom", "side", "end", "beginning", "middle", "start", "point", "case", 
            "fact", "idea", "reason", "number", "group", "problem", "question", "answer", "example", 
            "place", "area", "line", "word", "name", "man", "woman", "person", "guy", "girl", "boy", 
            "much", "many", "more", "most", "less", "least", "other", "another", "some", "any", "all", 
            "good", "bad", "new", "old", "first", "last", "next", "previous", "early", "late", "high", 
            "low", "big", "small", "large", "little", "long", "short", "hard", "soft", "easy", "difficult", 
            "simple", "complex", "right", "wrong", "true", "false", "real", "fake", "full", "empty", "hours", "mins", "minutes"
        }

        # First extract noun chunks (e.g., "panic attack", "bad grade")
        for chunk in doc.noun_chunks:
            if len(chunk.text.split()) <= 3 and not chunk.root.is_stop and chunk.root.text not in ignore_words:
                # Remove stop words like determiners ("a", "the") from the chunk
                words = [w.text for w in chunk if not w.is_stop and not w.is_punct and w.text not in ignore_words]
                if words:
                    candidates.append(" ".join(words))

        # Fallback/complement with single meaningful nouns or adjectives
        for token in doc:
            if not token.is_stop and not token.is_punct and len(token.text) > 2:
                if token.pos_ in ("NOUN", "PROPN", "ADJ") and token.text not in ignore_words:
                    candidates.append(token.text)
                    
        # Count frequencies
        from collections import Counter
        counts = Counter(candidates)
        
        # Get most common, capitalized nicely
        top_words = [word.title() for word, count in counts.most_common(10)]
        
        # Deduplicate substrings (e.g., if we have "Panic Attack", we don't need "Panic")
        final_words = []
        for word in top_words:
            is_sub = False
            for i, fw in enumerate(final_words):
                if word.lower() in fw.lower():
                    is_sub = True
                    break
                elif fw.lower() in word.lower():
                    final_words[i] = word
                    is_sub = True
                    break
            if not is_sub:
                final_words.append(word)

        return final_words[:top_n]

    def generate_semantic_tags(self, text: str, predicted_emotion: str = "neutral", top_n: int = 5) -> dict:
        text_lower = text.lower()
        tags_scored = {}
        
        def add_tag(tag, score):
            if tag in tags_scored:
                tags_scored[tag] += score
            else:
                tags_scored[tag] = score

        found_topics = []
        for category, words in self.semantic_rules.items():
            if any(re.search(rf'\b{w}\b', text_lower) for w in words):
                found_topics.append(category)
                add_tag(category, 1)

        found_cognitive = []
        for pattern, phrases in self.cognitive_patterns.items():
            if any(re.search(rf'\b{p}\b', text_lower) for p in phrases):
                found_cognitive.append(pattern)
                add_tag(pattern, 3)

        for indicator, phrases in self.positive_indicators.items():
            if any(re.search(rf'\b{p}\b', text_lower) for p in phrases):
                add_tag(indicator, 2)

        # Upgrade tags based on emotion context
        if predicted_emotion in ["anxiety", "stress", "sadness", "frustration", "anger"] or any(c in found_cognitive for c in ["overwhelmed", "anxiety", "sadness", "burnout"]):
            if "academic" in found_topics:
                add_tag("academicStress", 5)
                add_tag("studyPressure", 4)
                if "overwhelmed" in found_cognitive or "too much" in text_lower:
                    add_tag("workload", 3)
                if "academic" in tags_scored: del tags_scored["academic"]
            
            if "work" in found_topics:
                add_tag("workStress", 5)
                add_tag("burnout", 3)
                if "work" in tags_scored: del tags_scored["work"]
                
            if "friendshipConflict" in found_topics or "social" in found_topics:
                add_tag("friendshipConflict", 5)
                if "loneliness" in found_cognitive:
                    add_tag("loneliness", 4)
                
            if "health" in found_topics and ("sleep" in text_lower or "tired" in text_lower):
                add_tag("sleepIssues", 4)
                if "health" in tags_scored: del tags_scored["health"]

        # Ensure emotion tag itself is present if significant
        if predicted_emotion not in ["neutral", "calm"]:
            add_tag(predicted_emotion, 2)

        # Sort tags by score
        sorted_tags = sorted(tags_scored.items(), key=lambda x: x[1], reverse=True)
        # Format tags nicely: from camelCase to Title Case, no # symbol
        final_tags = [re.sub(r'([a-z])([A-Z])', r'\1 \2', tag).title() for tag, score in sorted_tags][:top_n]
        
        # ML Model prediction (fallback or supplement)
        ml_tags = []
        if getattr(self, "hashtag_model", None) and getattr(self, "hashtag_embedder", None):
            try:
                embedding = self.hashtag_embedder.encode([text], normalize_embeddings=True)
                probs = self.hashtag_model.predict_proba(embedding)[0]
                classes = self.hashtag_model.classes_
                # Get tags with > 0.20 confidence to prevent noisy guesses
                top_indices = probs.argsort()[-3:][::-1]
                ml_tags = [classes[i].title() for i in top_indices if probs[i] > 0.20]
            except Exception as e:
                print(f"[ERROR] Hashtag ML prediction failed: {e}")
                
        # Merge semantic and ML tags
        for t in ml_tags:
            if t not in final_tags:
                final_tags.append(t)
        
        # Enforce limit
        final_tags = final_tags[:top_n]

        # Fallback to noun chunking if semantic mapper & ML found absolutely nothing
        if not final_tags:
            fallback = self.extract_hashtags(text, top_n)
            final_tags = [f.title() for f in fallback]
            
        # Extract Highlighted Phrase
        try:
            sentences = self.summarizer._split_sentences(text)
            if sentences:
                best_sentence = sentences[0]
                max_score = -1
                
                all_important_words = []
                for v in self.cognitive_patterns.values(): all_important_words.extend(v)
                for v in self.positive_indicators.values(): all_important_words.extend(v)
                all_important_words.extend(["sad", "angry", "mad", "stressed", "anxious", "panic", "cry", "overwhelmed"])
                
                for s in sentences:
                    s_lower = s.lower()
                    score = sum(1 for w in all_important_words if w in s_lower)
                    if "i feel" in s_lower or "i am" in s_lower or "i'm" in s_lower:
                        score += 1
                        
                    if score > max_score:
                        max_score = score
                        best_sentence = s
                        
                highlighted_phrase = best_sentence
            else:
                highlighted_phrase = text
        except Exception:
            highlighted_phrase = text

        return {
            "highlightedPhrase": highlighted_phrase,
            "hashtags": final_tags
        }

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
