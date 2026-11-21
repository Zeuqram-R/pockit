// Puente entre Pockit y claude.ai.
// - Envía mensajes desde los botones rápidos.
// - Agrega ⟦device:…⟧ ⟦lang:…⟧ a los mensajes que escribís a mano.
// - Lee las etiquetas ⟦pockit …⟧ de Marisol, se las pasa a la app y las esconde.
(() => {
  if (window.__pockitLoaded) return;
  window.__pockitLoaded = true;

  const POCKIT_RE = /⟦pockit\s+([^⟧]*)⟧/g;
  const ANY_TAG_RE = /[ \t]*⟦(?:pockit|device|lang)[^⟧]*⟧/g;

  const post = (msg) => {
    try { window.webkit.messageHandlers.pockit.postMessage(msg); } catch (e) {}
  };

  const prefix = () => window.__pockitPrefix || "";

  // ---------- Composer ----------
  function composer() {
    return document.querySelector('div.ProseMirror[contenteditable="true"]')
      || document.querySelector('[contenteditable="true"][role="textbox"]')
      || document.querySelector('[contenteditable="true"]')
      || document.querySelector('textarea');
  }

  function composerText(c) {
    if (!c) return "";
    return c.tagName === "TEXTAREA" ? c.value : (c.innerText || "");
  }

  function sendButton() {
    const selectors = [
      'button[aria-label="Send message"]', 'button[aria-label="Send Message"]',
      'button[aria-label="Enviar mensaje"]', 'button[aria-label*="Send"]',
      'button[aria-label*="Enviar"]', 'fieldset button[type="submit"]', 'button[type="submit"]'
    ];
    for (const s of selectors) {
      const b = document.querySelector(s);
      if (b && !b.disabled && b.getAttribute("aria-disabled") !== "true") return b;
    }
    return null;
  }

  function setTextareaValue(t, value) {
    const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value").set;
    setter.call(t, value);
    t.dispatchEvent(new Event("input", { bubbles: true }));
  }

  // Pone el cursor al inicio del composer.
  function caretToStart(c) {
    const sel = window.getSelection();
    const range = document.createRange();
    const first = c.firstElementChild || c;
    range.setStart(first, 0);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  }

  function isSendButton(b) {
    if (!b) return false;
    const label = (b.getAttribute("aria-label") || "").toLowerCase();
    return label.includes("send") || label.includes("enviar") || (b.type === "submit" && !!b.closest("fieldset, form"));
  }

  let addingPrefix = false;
  function ensurePrefix() {
    const p = prefix();
    if (!p || addingPrefix) return;
    const c = composer();
    if (!c) return;
    const text = composerText(c);
    if (!text.trim() || text.includes("⟦device:")) return;
    addingPrefix = true;
    try {
      if (c.tagName === "TEXTAREA") {
        setTextareaValue(c, p + c.value);
      } else {
        c.focus();
        caretToStart(c);
        document.execCommand("insertText", false, p);
      }
    } catch (e) {
      post({ type: "log", message: "prefix: " + e });
    }
    addingPrefix = false;
  }

  // Antes de que claude.ai procese el envío, agregamos el prefijo.
  document.addEventListener("click", (e) => {
    const b = e.target && e.target.closest ? e.target.closest("button") : null;
    if (isSendButton(b)) ensurePrefix();
  }, true);
  document.addEventListener("pointerdown", (e) => {
    const b = e.target && e.target.closest ? e.target.closest("button") : null;
    if (isSendButton(b)) ensurePrefix();
  }, true);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey && !e.isComposing) {
      const c = composer();
      if (c && (c === e.target || c.contains(e.target))) ensurePrefix();
    }
  }, true);

  // Lo usan los botones rápidos de la app.
  window.pockitSend = async (text) => {
    const c = composer();
    if (!c) { post({ type: "sendResult", ok: false, reason: "no-composer" }); return false; }
    const full = prefix() + text;
    try {
      if (c.tagName === "TEXTAREA") {
        setTextareaValue(c, full);
      } else {
        c.focus();
        document.execCommand("selectAll", false, null);
        document.execCommand("insertText", false, full);
      }
    } catch (e) {
      post({ type: "sendResult", ok: false, reason: "insert: " + e });
      return false;
    }
    for (let i = 0; i < 30; i++) {
      await new Promise((r) => setTimeout(r, 100));
      const b = sendButton();
      if (b) {
        addingPrefix = true; // ya trae el prefijo
        b.click();
        addingPrefix = false;
        post({ type: "sendResult", ok: true });
        return true;
      }
    }
    post({ type: "sendResult", ok: false, reason: "no-send-button" });
    return false;
  };

  // ---------- Etiquetas ----------
  function hash(str) {
    let h = 5381;
    for (let i = 0; i < str.length; i++) h = ((h << 5) + h + str.charCodeAt(i)) | 0;
    return (h >>> 0).toString(36);
  }

  function messageContainer(node) {
    let el = node.parentElement;
    for (let i = 0; i < 8 && el && el.parentElement; i++) {
      if ((el.innerText || "").length > 160) return el;
      el = el.parentElement;
    }
    return node.parentElement;
  }

  function parseAttrs(body) {
    const out = {};
    const re = /(\w+)=("([^"]*)"|\S+)/g;
    let m;
    while ((m = re.exec(body))) out[m[1]] = m[3] !== undefined ? m[3] : m[2];
    return out;
  }

  function isEditable(node) {
    const el = node.parentElement;
    return !!(el && el.closest('[contenteditable="true"], textarea, input'));
  }

  function scan() {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) => (n.nodeValue && n.nodeValue.indexOf("⟦") !== -1 && !isEditable(n))
        ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT
    });
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    if (!nodes.length) return;

    const items = [];
    for (const n of nodes) {
      const value = n.nodeValue;
      const found = [];
      let m;
      POCKIT_RE.lastIndex = 0;
      while ((m = POCKIT_RE.exec(value))) found.push(parseAttrs(m[1]));
      if (found.length) {
        const ctx = (messageContainer(n).innerText || "").replace(ANY_TAG_RE, "").slice(0, 200);
        const raw = (value.match(POCKIT_RE) || []).join(" ");
        items.push({ key: hash(raw + "|" + ctx), tags: found });
      }
      const cleaned = value.replace(ANY_TAG_RE, "");
      if (cleaned !== value) n.nodeValue = cleaned;
    }
    if (items.length) post({ type: "tags", items });
  }

  let timer = null;
  const schedule = () => {
    clearTimeout(timer);
    timer = setTimeout(scan, 700);
  };
  new MutationObserver(schedule).observe(document.documentElement, {
    childList: true, subtree: true, characterData: true
  });
  schedule();

  // ---------- Diagnóstico del skin ----------
  window.pockitDiagnose = () => {
    const names = new Set();
    for (const sheet of Array.from(document.styleSheets)) {
      let rules;
      try { rules = sheet.cssRules; } catch (e) { continue; }
      for (const r of Array.from(rules || [])) {
        const style = r.style;
        if (!style) continue;
        for (let i = 0; i < style.length; i++) {
          const p = style[i];
          if (p.startsWith("--")) names.add(p);
        }
      }
    }
    const cs = getComputedStyle(document.documentElement);
    const bodyCs = getComputedStyle(document.body);
    const out = {};
    Array.from(names).sort().forEach((n) => {
      const v = (cs.getPropertyValue(n) || bodyCs.getPropertyValue(n)).trim();
      if (v && v.length < 80 && /(bg|text|accent|border|brand|surface|color|always|on-)/i.test(n)) out[n] = v;
    });
    return JSON.stringify({
      url: location.pathname,
      htmlClass: document.documentElement.className,
      htmlAttrs: Array.from(document.documentElement.attributes).map((a) => a.name + "=" + a.value).join(" "),
      bodyClass: document.body.className.slice(0, 200),
      vars: out
    }, null, 1);
  };

  post({ type: "ready" });
})();
