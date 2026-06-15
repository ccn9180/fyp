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
            "strategy": strategy
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
        }), 500

    data = request.json
    if not data or "text" not in data:
        return jsonify({"error": "Missing 'text' field in request body."}), 400

    text = data["text"].strip()
    if not text:
        return jsonify({"error": "Text cannot be empty."}), 400

    try:
        result = emotion_clf.predict(text)
        logger.info(f"Emotion predicted: {result.get('emotion')} for text: {text[:30]}...")
        return jsonify(result)
    except Exception as e:
        return jsonify({
            "error":      str(e),
            "emotion":    "neutral",
            "title":      "Reflection Captured",
            "summary":    "Your thoughts have been logged securely.",
            "is_crisis":  False,
            "confidence": 0.0,
            "emotion_percentages": [],
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


if __name__ == '__main__':
    print("[START] Starting Eunoia Backend API on port 5000...")
    print("   /chat             -> Chatbot endpoint")
    print("   /predict_emotion  -> Diary emotion detection endpoint")
    print("   /summarize_chat   -> Chat summary endpoint")
    app.run(host='0.0.0.0', port=5000, debug=True)
