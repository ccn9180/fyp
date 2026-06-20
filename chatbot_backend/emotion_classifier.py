import os
import re
import sys
import warnings
import torch
import nltk
from nltk.stem import WordNetLemmatizer

nltk.download('wordnet', quiet=True)
nltk.download('omw-1.4', quiet=True)

from custom_model import CustomNeuralNet
from nltk.sentiment.vader import SentimentIntensityAnalyzer

warnings.filterwarnings('ignore')

CORE_MAPPING = {
    # Joy: strong positive emotions — personal achievement, warmth, happiness
    'joy': 'joy', 'amusement': 'joy', 'excitement': 'joy', 'happiness': 'joy',
    'enthusiasm': 'joy', 'fun': 'joy', 'pride': 'joy',
    'admiration': 'joy', 'gratitude': 'joy', 'love': 'joy',

    # Calm: peaceful, grounded, relieved
    'calm': 'calm', 'relief': 'calm',

    # Sadness: loss, grief, regret
    'sadness': 'sadness', 'grief': 'sadness', 'empty': 'sadness',
    'remorse': 'sadness', 'disappointment': 'sadness',

    # Anxiety: fear, worry, nervousness
    'anxiety': 'anxiety', 'fear': 'anxiety', 'nervousness': 'anxiety',
    'worry': 'anxiety', 'panic': 'anxiety',

    # Anger: hostility, frustration, moral disapproval
    'anger': 'anger', 'hate': 'anger', 'disgust': 'anger',
    'annoyance': 'anger', 'disapproval': 'anger',

    # Hopeful: forward-looking, supportive, aspirational (Mapped to Joy)
    'optimism': 'joy', 'hopeful': 'joy',
    'approval': 'joy', 'caring': 'joy', 'desire': 'joy',

    # Overwhelmed: self-conscious, distressing internal emotions
    'overwhelmed': 'overwhelmed', 'confusion': 'overwhelmed',
    'embarrassment': 'overwhelmed', 'guilt': 'overwhelmed', 'shame': 'overwhelmed',

    # Neutral: observational, cognitive, everyday states
    'neutral': 'neutral', 'boredom': 'neutral', 'curiosity': 'neutral',
    'realization': 'neutral', 'surprise': 'neutral',
}

EMOTION_META = {
    'joy': {
        'title': 'Joyful and Bright',
        'summary': 'Your writing radiates warmth and positivity. Whatever sparked this today, hold onto it.'
    },
    'calm': {
        'title': 'Reflective and Calm',
        'summary': 'There is a steady, peaceful energy flowing through your words today. You seem grounded.'
    },
    'sadness': {
        'title': 'Pensive and Melancholic',
        'summary': 'It sounds like you are carrying some weight today. Sadness is a valid emotion, be gentle with yourself.'
    },
    'anxiety': {
        'title': 'Tense and Overwhelmed',
        'summary': 'Your entry reflects a mind under pressure. Acknowledging this stress is important, take it one step at a time.'
    },
    'anger': {
        'title': 'Resentful and Angry',
        'summary': 'Your words carry a strong sense of anger today. Giving yourself space to process it is healthy.'
    },
    'neutral': {
        'title': 'Steady and Balanced',
        'summary': 'Your entry feels grounded and even-keeled today. There is real value in stable, ordinary days.'
    },
    'hopeful': {
        'title': 'Optimistic and Hopeful',
        'summary': 'There is a beautiful sense of forward-looking optimism in your words. Nurture this hopeful mindset!'
    },
    'overwhelmed': {
        'title': 'Tangled and Overwhelmed',
        'summary': 'Your entry hints at feelings of confusion or self-consciousness. These are heavy emotions to carry — be patient with yourself.'
    }
}

HIGH_RISK = [
    "kill myself", "suicide", "end my life", "take my own life",
    "want to die", "don't want to live", "better off dead", "end it all",
    "commit suicide", "planning to kill myself", "thinking of suicide",
    "thinking about killing myself", "want to end my life", "i should die",
    "wish i was dead", "i am going to kill myself"
]

MODERATE_RISK = [
    "no reason to live", "life is meaningless", "life is pointless",
    "can't go on", "can't do this anymore", "i'm done", "nothing matters",
    "everything is hopeless", "there is no point", "wish i could disappear",
    "wish i never existed", "don't want to wake up", "i hate being alive",
    "tired of living", "want everything to stop", "feel trapped",
    # indirect "I can't continue" phrasing -- people rarely say "can't go on"
    # verbatim; they say it in roundabout ways like these.
    "how long i can keep doing this", "how long i can keep this up",
    "can't keep doing this", "can't keep this up", "cant keep doing this",
    "cant keep this up", "don't know how much longer i can",
    "dont know how much longer i can", "how much more i can take",
    "losing control", "can't take this anymore", "cant take this anymore",
    "can't handle this anymore", "cant handle this anymore",
]

WARNING_SIGNS = [
    "hopeless", "worthless", "empty", "emptiness", "broken", "numb",
    "nobody cares", "alone", "abandoned", "burden", "failure", "failing",
    "giving up", "given up", "exhausted", "exhausting",
    "can't cope", "cant cope", "overwhelm",
    # social withdrawal/isolation is a recognized risk factor, not just sadness
    "don't feel like talking to anyone", "dont feel like talking to anyone",
    "no one would understand", "nobody would understand",
    "they wouldn't understand", "they wouldnt understand",
    "no point talking to anyone", "don't want to talk to anyone",
    "dont want to talk to anyone",
]

class EmotionClassifier:
    def __init__(self, model_path: str = 'emotion_model_data.pth'):
        print('[INFO] Loading Emotion Classifier...')
        if not os.path.exists(model_path):
            print(f'[ERROR] {model_path} not found! Run emotion_train.py first.')
            sys.exit(1)

        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        data = torch.load(model_path, map_location=self.device, weights_only=False)

        self.vocab = data['vocab']
        self.tags = data['tags']
        self.vocab_size = data['vocab_size']
        self.embed_dim = data['embedding_dim']
        self.hidden_size = data['hidden_size']
        self.num_classes = data['output_size']
        self.num_layers = data['num_layers']
        self.dropout = data['dropout']
        self.pad_idx = data['pad_idx']
        self.unk_idx = data['unk_idx']
        self.max_seq_len = data['max_seq_len']

        self.model = CustomNeuralNet(
            vocab_size=self.vocab_size,
            embedding_dim=self.embed_dim,
            hidden_size=self.hidden_size,
            num_classes=self.num_classes,
            pad_idx=self.pad_idx,
            num_layers=self.num_layers,
            dropout=self.dropout,
        ).to(self.device)

        self.model.load_state_dict(data['model_state'])
        self.model.eval()
        self.sia = SentimentIntensityAnalyzer()
        self.lemmatizer = WordNetLemmatizer()
        # Force WordNet's lazy corpus load to finish now, while we're still
        # single-threaded at startup. Triggering it lazily on the first real
        # Flask request instead races with that request's own thread and
        # intermittently raises "WordNetCorpusReader object has no attribute
        # '_LazyCorpusLoader__args'" -- a known NLTK thread-safety gap.
        self.lemmatizer.lemmatize("warmup")

        # Load summarizer once
        try:
            from summarizer import ExtractiveSummarizer
            self.summarizer = ExtractiveSummarizer()
        except Exception as e:
            print(f"[WARNING] Could not load summarizer: {e}")
            self.summarizer = None
            
        print(f'[OK] Emotion Classifier ready | Classes: {len(self.tags)} sub-emotions')

    def _preprocess(self, text: str):
        clean = text.lower().strip()
        if len(clean) > 500: clean = clean[:500]
        return clean

    def _tokenize(self, text: str):
        words = re.findall(r'\b\w+\b', self._preprocess(text))
        return [self.lemmatizer.lemmatize(w) for w in words]

    def _encode(self, tokens):
        seq = [self.vocab.get(t, self.unk_idx) for t in tokens]
        if not seq: seq = [self.unk_idx]
        if len(seq) < self.max_seq_len:
            seq = seq + [self.pad_idx] * (self.max_seq_len - len(seq))
        else:
            seq = seq[: self.max_seq_len]
        return seq

    def predict(self, text: str) -> dict:

        # Split into sentences (simple punctuation split)
        sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if s.strip()]
        if not sentences:
            sentences = [text]
            
        valid_sentences = []
        encoded_sentences = []
        for s in sentences:
            tokens = self._tokenize(s)
            if not tokens: continue
            encoded_sentences.append(self._encode(tokens))
            valid_sentences.append(s)
            
        if not encoded_sentences:
            encoded_sentences = [self._encode(self._tokenize(text))]
            valid_sentences = [text]
            
        x = torch.tensor(encoded_sentences, dtype=torch.long).to(self.device)

        with torch.no_grad():
            logits = self.model(x)
            probs = torch.softmax(logits, dim=1)
            
            # --- HYBRID HEURISTIC ADJUSTMENT WITH VADER ---
            joy_indices = [i for i, t in enumerate(self.tags) if CORE_MAPPING.get(t.lower(), 'neutral') in ['joy', 'hopeful']]
            calm_indices = [i for i, t in enumerate(self.tags) if CORE_MAPPING.get(t.lower(), 'neutral') == 'calm']
            anxiety_indices = [i for i, t in enumerate(self.tags) if CORE_MAPPING.get(t.lower(), 'neutral') == 'anxiety']
            sadness_indices = [i for i, t in enumerate(self.tags) if CORE_MAPPING.get(t.lower(), 'neutral') == 'sadness']
            anger_indices = [i for i, t in enumerate(self.tags) if CORE_MAPPING.get(t.lower(), 'neutral') == 'anger']
            
            for i, s in enumerate(valid_sentences):
                s_lower = s.lower()
                tension_words = ['worried', 'wrong', 'imagining', 'panicking', 'panic', 'fear', 'anxious', 'stress', 'overwhelmed', 'pressure', 'deadlines', 'assignment', 'assignments', 'struggle', 'struggling', 'hard', 'remaining tasks', 'wonder how', 'how i\'m going to fit', 'work left', 'back of my mind', 'on my mind', 'in my mind', 'state of mind', 'never enough time', 'endless cycle', 'future', 'falling behind', 'comparing', 'graduation', 'expectations', 'barely slept', 'barely sleep', 'can\'t sleep', 'cannot sleep', 'unable to sleep', 'keeps replaying', 'brain keeps replaying', 'racing thoughts', 'overthinking', 'can\'t turn my brain off', 'everything slow', 'slow down', 'piling up', 'pile up', 'good enough', 'not enough', 'figured out', 'have it all', 'keep up', 'stay positive', 'try to be positive', 'trying to be positive']
                has_tension = any(w in s_lower for w in tension_words)
                
                sadness_words = [
                    # Classic sadness
                    'upset', 'sad', 'lonely', 'miss', 'heartbroken', 'cry', 'crying',
                    'depressed', 'moving away', "won't be the same", 'disconnected',
                    'going through the motions', 'same effect anymore', 'numb', 'empty',
                    'burnout', 'exhausted',
                    # Self-worth sadness
                    'not good enough', 'am i good', "whether i'm good",
                    # Interpersonal hurt / disappointment (missing before)
                    'hurt me', 'hurt by', 'really hurt', 'it hurt', 'hurts',
                    'disappointed', 'disappointment', 'let me down', 'let down',
                    'question everything', 'questioning everything',
                    'argument', 'conflict', 'fight with', 'falling out',
                    'i do care', 'honestly i do', 'i care',
                    'go back to normal', 'things were normal', 'hope things',
                    'don\'t know if', 'don\'t know how',
                    'i hate that', 'hate that i',
                    'wish i could feel', 'wish i was', 'wish i were', 'wish i could be',
                ]
                has_sadness = any(w in s_lower for w in sadness_words)
                
                # Get VADER compound score for the sentence
                vader_score = self.sia.polarity_scores(s)["compound"]
                
                # Check for resolving/positive context that overrides tension
                resolving_words = ['done', 'relieved', 'proud', 'hope', 'hanging in there', 'finally']
                has_resolution = any(w in s_lower for w in resolving_words)
                
                # If the sentence is overwhelmingly positive OR has resolving words, ignore tension keywords
                if vader_score >= 0.6 or has_resolution:
                    has_tension = False
                
                if vader_score > 0.4 and not (has_tension or has_sadness):
                    # Strongly positive AND no tension/sadness keywords: boost joy and calm
                    for idx in joy_indices:
                        probs[i, idx] += vader_score * 1.5
                    for idx in calm_indices:
                        probs[i, idx] += vader_score * 0.6
                        
                if vader_score < -0.2:
                    # Negative sentence: boost anxiety and sadness generally, but anger less so
                    for idx in anxiety_indices + sadness_indices:
                        probs[i, idx] += abs(vader_score) * 0.8
                    for idx in anger_indices:
                        probs[i, idx] += abs(vader_score) * 0.3
                        
                if has_tension:
                    # Explicit tension keywords: boost anxiety strongly
                    penalty = 0.6 if vader_score >= -0.4 else abs(vader_score)
                    for idx in anxiety_indices:
                        probs[i, idx] += penalty * 2.0
                        
                if has_sadness:
                    # Explicit sadness keywords: boost sadness strongly
                    penalty = 0.6 if vader_score >= -0.2 else abs(vader_score)
                    for idx in sadness_indices:
                        probs[i, idx] += penalty * 2.0
                
                probs[i] = probs[i] / probs[i].sum()
            # -----------------------------------
            
            # Average probabilities across all sentences for the final score
            # Give exponentially more weight to sentences at the end of the text
            num_sentences = probs.size(0)
            if num_sentences > 1:
                # Use 1.2 (not 1.5) — prevents the final sentence from dominating
                # when earlier sentences carry the core emotional weight
                weights = torch.tensor([1.2 ** i for i in range(num_sentences)], dtype=torch.float32, device=self.device).unsqueeze(1)
                weighted_probs = probs * weights
                avg_probs = (weighted_probs.sum(dim=0) / weights.sum()).unsqueeze(0)
            else:
                avg_probs = probs.mean(dim=0).unsqueeze(0)

        top_probs, top_indices = torch.topk(avg_probs, k=min(3, avg_probs.size(1)), dim=1)
        
        primary_prob = top_probs[0][0].item()
        sub_emotion = self.tags[top_indices[0][0].item()]
        
        # Map sub-emotion to Core Emotion
        core_emotion = CORE_MAPPING.get(sub_emotion.lower(), 'neutral')
        
        meta = EMOTION_META.get(core_emotion, {
            'title': 'Reflection Captured'
        })
        
        # Aggregate probabilities by core emotion from top predictions
        core_probs = {}
        for i in range(top_probs.size(1)):
            prob = top_probs[0][i].item()
            tag = self.tags[top_indices[0][i].item()]
            mapped_core = CORE_MAPPING.get(tag.lower(), 'neutral')
            
            if mapped_core not in core_probs:
                core_probs[mapped_core] = {'prob': 0.0, 'sub_emotion': tag}
            core_probs[mapped_core]['prob'] += prob
            
        # Sort by aggregated probability
        sorted_cores = sorted(core_probs.items(), key=lambda x: x[1]['prob'], reverse=True)
        
        emotion_percentages = []
        for core, data in sorted_cores[:3]:
            emotion_percentages.append({
                'emotion': core,
                'sub_emotion': data['sub_emotion'],
                'confidence': round(data['prob'] * 100, 1)
            })
        
        # Ensure we always have at least 1, even if all mapped to same core
        if not emotion_percentages:
             emotion_percentages.append({
                 'emotion': core_emotion,
                 'sub_emotion': sub_emotion,
                 'confidence': round(primary_prob * 100, 1)
             })
             
        # Update the top-level emotion fields to use the properly aggregated highest emotion
        core_emotion = emotion_percentages[0]['emotion']
        sub_emotion = emotion_percentages[0]['sub_emotion']
        primary_prob = emotion_percentages[0]['confidence'] / 100.0

        # Hybrid Summarization & Keywords
        keywords = []
        smart_title = meta['title']
        try:
            if self.summarizer:
                ext_summary = self.summarizer.summarize(text, top_n=4)
                keywords = self.summarizer.extract_keywords(text, top_n=5)
            else:
                ext_summary = ""
                keywords = []
                
            
            secondary_core = emotion_percentages[1]['emotion'] if len(emotion_percentages) > 1 else None
            
            if secondary_core and secondary_core != core_emotion:
                prefix = f"The diary entry reflects a mixture of {core_emotion.capitalize()} and {secondary_core.capitalize()}."
            else:
                prefix = f"The diary entry reflects a primary feeling of {core_emotion.capitalize()}."
                
            if ext_summary:
                summary_text = f"{prefix} {ext_summary}"
            else:
                summary_text = prefix
                
            # Smart Title Generation using Keywords
            if keywords:
                top_keyword = keywords[0].capitalize()
                if core_emotion in ['joy', 'hopeful', 'calm']:
                    smart_title = f"Reflections on {top_keyword}"
                elif core_emotion in ['anxiety', 'sadness', 'anger', 'overwhelmed']:
                    smart_title = f"Processing {top_keyword}"
                else:
                    smart_title = f"Thoughts on {top_keyword}"
                    
        except Exception as e:
            # Fallback to old behavior if summarizer fails
            summary_text = meta.get('summary', 'Your thoughts have been logged securely.')
            if core_emotion != sub_emotion.lower():
                summary_text = f"{summary_text} Specifically, we noticed undertones of {sub_emotion}."

        # Multi-Level Crisis Detection
        text_lower = text.lower()
        keyword_score = 0
        
        for phrase in HIGH_RISK:
            if phrase in text_lower:
                keyword_score += 10
        for phrase in MODERATE_RISK:
            if phrase in text_lower:
                keyword_score += 5
        for phrase in WARNING_SIGNS:
            if phrase in text_lower:
                keyword_score += 1

        sadness_prob = next((e['confidence'] for e in emotion_percentages if e['emotion'] == 'sadness'), 0)
        anxiety_prob = next((e['confidence'] for e in emotion_percentages if e['emotion'] == 'anxiety'), 0)

        risk_level = "LOW_RISK"
        if keyword_score >= 10:
            risk_level = "HIGH_RISK"
        elif keyword_score >= 5 and sadness_prob > 40:
            risk_level = "MODERATE_RISK"
        elif sadness_prob > 60 and anxiety_prob > 30:
            risk_level = "MODERATE_RISK"

        return {
            'emotion': core_emotion,
            'sub_emotion': sub_emotion,
            'title': smart_title,
            'confidence': round(primary_prob, 4),
            'summary': summary_text,
            'emotion_percentages': emotion_percentages,
            'keywords': keywords,
            'is_crisis': risk_level in ["HIGH_RISK", "MODERATE_RISK"],
            'risk_level': risk_level
        }
