from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import traceback

# ── Configure Logging ─────────────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("backend_monitor.log", encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ── Load chatbot ─────────────────────────────────────────────
try:
    from chatbot import ProfessionalFYPBot
    bot = ProfessionalFYPBot()
except Exception as e:
    print(f"WARNING: Failed to load chatbot: {e}")
    bot = None

# ── Load emotion classifier ──────────────────────────────────
try:
    from emotion_classifier import EmotionClassifier
    emotion_clf = EmotionClassifier("emotion_model_data.pth")
except Exception as e:
    print(f"WARNING: Failed to load emotion classifier: {e}")
    print("Run emotion_train.py first to generate emotion_model_data.pth")
    emotion_clf = None

# ── Load topic extractor ─────────────────────────────────────
try:
    from topic_extractor import TopicExtractor
    topic_ext = TopicExtractor()
except Exception as e:
    print(f"WARNING: Failed to load topic extractor: {e}")
    topic_ext = None

app = Flask(__name__)
CORS(app)


# ── /chat ────────────────────────────────────────────────────
@app.route('/chat', methods=['POST'])
def chat():
    if bot is None:
        return jsonify({
            "response": "The bot failed to load. Please ensure your Python files and .pth model are in the chatbot_backend folder and try restarting the server."
        }), 500

    data = request.json
    user_input = data.get("message", "").strip()
    user_id = data.get("user_id", "default_user")

    if not user_input:
        return jsonify({"response": "Please say something."}), 400

    logger.info(f"Received message from {user_id}: {user_input}")

    try:
        response, state, strategy = bot._handle_turn(user_id, user_input)
        logger.info(f"Bot response: {response}")
        return jsonify({
            "response": response,
            "intent":   state.get("intent", ""),
            "topic":    state.get("topic", ""),
            "strategy": strategy,
            "distress_score":     state.get("distress_score", 0),
            "achievement_flag":   state.get("achievement_flag", False),
            "conversation_mode":  state.get("conversation_mode", "validation"),
            # Coarse topic/emotion/intent/strategy/confidence taxonomy --
            # see AdvancedNLUPipeline.classify_meta() in chatbot.py.
            "topic_category":     state.get("topic_category", "general"),
            "emotion":            state.get("emotion", "neutral"),
            "primary_emotion":    state.get("primary_emotion"),
            "secondary_emotion":  state.get("secondary_emotion"),
            "meta_intent":        state.get("meta_intent", ""),
            "meta_strategy":      state.get("meta_strategy", ""),
            "confidence":         state.get("confidence", 0.0),
        })
    except Exception as e:
        logger.error(f"Error handling turn: {e}\n{traceback.format_exc()}")
        return jsonify({"error": str(e), "response": "Sorry, I encountered an internal error."}), 500


# ── /predict_emotion ─────────────────────────────────────────
@app.route('/predict_emotion', methods=['POST'])
def predict_emotion():
    """
    POST body: { "text": "I feel so happy today..." }
    Response:  {
        "emotion":    "joy",
        "title":      "Joyful & Bright",
        "confidence": 0.94,
        "summary":    "Your writing radiates...",
        "is_crisis":  false
    }
    """
    if emotion_clf is None:
        return jsonify({
            "error":   "Emotion classifier not loaded. Run emotion_train.py first.",
            "emotion": "neutral",
            "title":   "Reflection Captured",
            "summary": "Your thoughts have been logged securely.",
            "is_crisis": False,
            "confidence": 0.0,
            "emotion_percentages": [],
            "hashtags": [],
        }), 500

    data = request.json
    if not data or "text" not in data:
        return jsonify({"error": "Missing 'text' field in request body."}), 400

    text = data["text"].strip()
    if not text:
        return jsonify({"error": "Text cannot be empty."}), 400

    try:
        result = emotion_clf.predict(text)
        
        # Add semantic hashtags and highlighted phrase
        if topic_ext:
            semantic_data = topic_ext.generate_semantic_tags(text, result.get('emotion', 'neutral'))
            result["hashtags"] = semantic_data["hashtags"]
            result["highlightedPhrase"] = semantic_data["highlightedPhrase"]
        else:
            result["hashtags"] = []
            result["highlightedPhrase"] = text
            
        logger.info(f"Emotion predicted: {result.get('emotion')} for text: {text[:30]}...")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error in predict_emotion: {e}\n{traceback.format_exc()}")
        return jsonify({
            "error":      str(e),
            "emotion":    "neutral",
            "title":      "Reflection Captured",
            "summary":    "Your thoughts have been logged securely.",
            "is_crisis":  False,
            "confidence": 0.0,
            "emotion_percentages": [],
            "hashtags": [],
        }), 500


# ── /summarize_chat ──────────────────────────────────────────
@app.route('/summarize_chat', methods=['POST'])
def summarize_chat():
    data = request.json
    messages = data.get("messages", [])
    if not messages:
        return jsonify({"summary": "No chat content to summarize."})
        
    full_text = " ".join([m.get("text", "") for m in messages if m.get("text")])
    
    try:
        if topic_ext and topic_ext.summarizer:
            summarizer = topic_ext.summarizer
        else:
            from summarizer import ExtractiveSummarizer
            summarizer = ExtractiveSummarizer()
        num_sentences = max(3, min(6, len(messages) // 3))
        summary = summarizer.summarize(full_text, top_n=num_sentences)
        if not summary:
            summary = "A mindfulness chat session."
        return jsonify({"summary": summary})
    except Exception as e:
        logger.error(f"Summarizer error: {e}")
        return jsonify({"summary": "A mindfulness chat session."}), 500


import socket
import os
import re

def auto_update_flutter_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        local_ip = "127.0.0.1"

    target_url = f"http://{local_ip}:5000"
    config_path = os.path.join(os.path.dirname(__file__), '..', 'lib', 'services', 'backend_config.dart')
    
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                content = f.read()
                
            if target_url not in content:
                pattern = r"(static final List<String> _baseUrlsToTry = \[)"
                replacement = f"\\1\n    '{target_url}', // [AUTO-INJECTED] Active IP"
                new_content = re.sub(pattern, replacement, content, count=1)
                
                with open(config_path, 'w') as f:
                    f.write(new_content)
                print(f"[INFO] Auto-injected {target_url} into Flutter config!")
            else:
                print(f"[INFO] Flutter config already has the active IP ({target_url})")
        except Exception as e:
            print(f"[ERROR] Failed to auto-update Flutter config: {e}")

auto_update_flutter_ip()

if __name__ == '__main__':
    print("[START] Starting Eunoia Backend API on port 5000...")
    print("   /chat             -> Chatbot endpoint")
    print("   /predict_emotion  -> Diary emotion detection endpoint")
    print("   /summarize_chat   -> Chat summary endpoint")
    app.run(host='0.0.0.0', port=5000, debug=True)
