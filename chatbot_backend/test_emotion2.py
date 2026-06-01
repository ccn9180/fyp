import json
import urllib.request

data = json.dumps({"text": "I spent almost the entire day working on my FYP. There are bugs in the system, and the deadline is getting closer. Every time I solve one problem, another appears. I'm trying my best, but the workload feels overwhelming."}).encode('utf-8')
req = urllib.request.Request("http://127.0.0.1:5000/predict_emotion", data=data, headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req) as response:
        print(response.read().decode('utf-8'))
except Exception as e:
    print(e)
