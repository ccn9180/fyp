async function main() {
  try {
    const listRes = await fetch('http://localhost:9222/json');
    const tabs = await listRes.json();
    const adminTab = tabs.find(t => t.title.includes("Eunoia Admin") || t.url.includes("5173"));
    if (!adminTab) {
      console.error("Tab not found.");
      return;
    }

    const wsUrl = adminTab.webSocketDebuggerUrl;
    const ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
      ws.send(JSON.stringify({
        id: 1,
        method: "Runtime.evaluate",
        params: {
          expression: "document.body.innerHTML"
        }
      }));
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.id === 1) {
        console.log("DOM HTML content:\n", data.result?.result?.value);
        ws.close();
      }
    };
  } catch (e) {
    console.error("Error inspecting DOM:", e);
  }
}

main();
