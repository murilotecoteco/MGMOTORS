const CONSENT_KEY = "mg_termos_aceitos";
const CHATLING_ID = "3965249523";

function carregarChatling() {
  if (document.getElementById("chtl-script")) return;
  window.chtlConfig = { chatbotId: CHATLING_ID };
  const script = document.createElement("script");
  script.id = "chtl-script";
  script.async = true;
  script.dataset.id = CHATLING_ID;
  script.src = "https://chatling.ai/js/embed.js";
  document.head.appendChild(script);
}

if (localStorage.getItem(CONSENT_KEY) === "1") carregarChatling();
window.addEventListener("mg:consent-accepted", carregarChatling, { once: true });
