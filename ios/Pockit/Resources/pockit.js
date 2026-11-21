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

  // ---------- Spoilers que se tocan pa' ver ----------
  // Marisol los manda entre ⟦spoiler title="…"⟧ y ⟦/spoiler⟧ (o el viejo <details>…</details>,
  // que claude.ai muestra como texto). Aquí se esconden y se cambian por un botón.
  const SPOILER_START = /⟦spoiler(?:\s+title="([^"]*)")?[^⟧]*⟧|<details>/;
  const SPOILER_END = /⟦\/spoiler⟧|<\/details>/;
  const SPOILER_STRIP = /⟦spoiler[^⟧]*⟧|⟦\/spoiler⟧|<\/?details>|<summary>[\s\S]*?<\/summary>/g;
  let spoilerCount = 0;

  function blockOf(node) {
    const el = node.nodeType === 3 ? node.parentElement : node;
    return el ? el.closest("p, li, h1, h2, h3, h4, blockquote, pre, ul, ol, div") : null;
  }

  function stripText(el) {
    const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const list = [];
    while (w.nextNode()) list.push(w.currentNode);
    for (const t of list) {
      const v = t.nodeValue.replace(SPOILER_STRIP, "");
      if (v !== t.nodeValue) t.nodeValue = v;
    }
  }

  // Spoilers que todavía se están escribiendo: se esconden desde que aparece ⟦spoiler
  // (pa' que nunca se lean mientras Marisol escribe) y se van extendiendo hasta el cierre.
  const pending = new Map();

  function makeButton(id, title) {
    const en = (window.__pockitPrefix || "").includes("lang:en");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.dataset.pockitToggle = id;
    btn.textContent = "⚠️ SPOILER" + (title ? ": " + title : "") + (en ? " · tap to reveal" : " · tocá pa' ver");
    btn.style.cssText = "display:block;width:100%;text-align:left;margin:12px 0;padding:12px 14px;" +
      "border-radius:14px;border:1.5px solid #FFB547;background:rgba(255,181,71,0.12);" +
      "color:#FFF4E6;font:600 15px -apple-system,system-ui,sans-serif;";
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const open = btn.dataset.open === "1";
      document.querySelectorAll('[data-pockit-spoiler="' + id + '"]').forEach((b) => {
        b.style.display = open ? "none" : "";
      });
      btn.dataset.open = open ? "0" : "1";
      btn.style.opacity = open ? "1" : "0.7";
    });
    return btn;
  }

  function hideBlock(b, id, btn) {
    stripText(b);
    b.dataset.pockitSpoiler = id;
    b.style.display = btn && btn.dataset.open === "1" ? "" : "none";
  }

  // Esconde bloques desde `el` hasta el cierre. Devuelve true si encontró el cierre.
  function swallow(el, id, btn) {
    let cur = el;
    while (cur) {
      if (cur.dataset && cur.dataset.pockitToggle) { cur = cur.nextElementSibling; continue; }
      const closed = SPOILER_END.test(cur.textContent || "");
      hideBlock(cur, id, btn);
      pending.set(id, { last: cur, btn: btn });
      if (closed) { pending.delete(id); return true; }
      cur = cur.nextElementSibling;
    }
    return false;
  }

  function processSpoilers() {
    if (!document.body) return;
    // 1) Los que siguen abiertos: re-limpiar el último bloque y tragar los nuevos.
    for (const [id, p] of Array.from(pending)) {
      if (!p.last.isConnected) { pending.delete(id); continue; }
      if (SPOILER_END.test(p.last.textContent || "")) { hideBlock(p.last, id, p.btn); pending.delete(id); continue; }
      hideBlock(p.last, id, p.btn);
      if (p.last.nextElementSibling) swallow(p.last.nextElementSibling, id, p.btn);
    }
    // 2) Nuevos inicios.
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) => (n.nodeValue && SPOILER_START.test(n.nodeValue) && !isEditable(n))
        ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT
    });
    const starts = [];
    while (walker.nextNode()) starts.push(walker.currentNode);

    for (const startNode of starts) {
      const first = blockOf(startNode);
      if (!first || first.dataset.pockitSpoiler) continue;
      const m = startNode.nodeValue.match(SPOILER_START);
      // Si el bloque es un contenedor grande con texto antes del spoiler, no lo escondemos entero.
      if (first.tagName === "DIV" && (first.textContent || "").indexOf(m ? m[0] : "⟦spoiler") > 20) continue;
      let title = (m && m[1]) || "";
      if (!title) {
        const sm = (first.textContent || "").match(/<summary>([\s\S]*?)<\/summary>/);
        if (sm) title = sm[1].replace(/⚠️|SPOILER:?/gi, "").trim();
      }
      const id = "s" + (++spoilerCount);
      const btn = makeButton(id, title);
      first.parentNode.insertBefore(btn, first);
      swallow(first, id, btn);
    }
  }

  // Texto de una etiqueta a medio escribir al final de un nodo (mientras Marisol escribe).
  const PARTIAL_TAG_RE = /[ \t]*⟦[^⟧]*$/;

  function scan() {
    if (!document.body) return;
    try { processSpoilers(); } catch (e) { post({ type: "log", message: "spoiler: " + e }); }
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
      let m;
      POCKIT_RE.lastIndex = 0;
      const raws = [];
      while ((m = POCKIT_RE.exec(value))) raws.push({ raw: m[0], attrs: parseAttrs(m[1]) });
      if (raws.length) {
        // Una etiqueta = un aviso, con su propia llave (así no se repite mientras el texto sigue llegando).
        const ctx = (messageContainer(n).textContent || "").replace(ANY_TAG_RE, "").replace(PARTIAL_TAG_RE, "").slice(0, 200);
        const msg = hash(ctx);
        for (const r of raws) items.push({ key: hash(r.raw + "|" + ctx), msg: msg, tags: [r.attrs] });
      }
      const cleaned = value.replace(ANY_TAG_RE, "").replace(PARTIAL_TAG_RE, "");
      if (cleaned !== value) n.nodeValue = cleaned;
    }
    if (items.length) post({ type: "tags", items });
  }

  // Revisa la página como máximo cada 60 ms (no espera a que Marisol termine de escribir).
  let timer = null;
  const schedule = () => {
    if (timer) return;
    timer = setTimeout(() => { timer = null; scan(); }, 60);
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
