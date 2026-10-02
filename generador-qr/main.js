(function () {
  "use strict";

  const brand = window.__BRAND__ || {};
  const STYLES = brand.styles || {
    clasico: { dots: "square", corners: "square", cornerDot: "square" }
  };
  const SAMPLE = brand.sampleData || "https://ejemplo.com";
  const MAX_LOGO = brand.maxLogoBytes || 5 * 1024 * 1024;

  const $ = (sel, scope) => (scope || document).querySelector(sel);
  const $$ = (sel, scope) => Array.from((scope || document).querySelectorAll(sel));

  function safe(fn, name) {
    try { fn(); } catch (e) { console.warn("[" + name + "] failed:", e); }
  }

  // ---------------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------------
  const state = {
    type: "url",
    center: null,        // dataURL del logo o emoji
    centerKind: null,    // "emoji" | "logo" | null
    payload: "",
    qr: null,            // instancia de la vista previa
    timer: 0
  };

  let card, form, previewEl, warningsEl, errorEl;

  // ---------------------------------------------------------------------------
  // Construcción del contenido del QR según el tipo
  // ---------------------------------------------------------------------------
  const val = (name) => {
    const el = form.elements[name];
    return el ? String(el.value || "").trim() : "";
  };

  function normalizeUrl(s) {
    if (!s) return "";
    if (/^[a-z][a-z0-9+.-]*:/i.test(s)) return s;              // ya tiene esquema
    if (!/\s/.test(s) && /\.[a-z]{2,}/i.test(s)) return "https://" + s.replace(/^\/+/, "");
    return s;                                                   // texto libre: se respeta
  }

  function wifiEscape(s) { return s.replace(/([\\;,:"])/g, "\\$1"); }

  function digits(s) { return s.replace(/[^\d]/g, ""); }

  const BUILDERS = {
    url: () => normalizeUrl(val("url")),
    text: () => val("text"),
    wifi: () => {
      const ssid = val("ssid");
      if (!ssid) return "";
      const sec = val("wifisec") || "WPA";
      const pass = val("wifipass");
      const hidden = form.elements.wifihidden.checked ? "H:true;" : "";
      return "WIFI:T:" + sec + ";S:" + wifiEscape(ssid) + ";" +
        (sec === "nopass" ? "" : "P:" + wifiEscape(pass) + ";") + hidden + ";";
    },
    whatsapp: () => {
      const num = digits(val("wanum"));
      if (!num) return "";
      const msg = val("wamsg");
      return "https://wa.me/" + num + (msg ? "?text=" + encodeURIComponent(msg) : "");
    },
    email: () => {
      const to = val("mailto");
      if (!to) return "";
      const sub = val("mailsub");
      return "mailto:" + to + (sub ? "?subject=" + encodeURIComponent(sub) : "");
    },
    tel: () => {
      const raw = val("tel");
      if (!raw) return "";
      const plus = raw.trim().charAt(0) === "+" ? "+" : "";
      return "tel:" + plus + digits(raw);
    }
  };

  // ---------------------------------------------------------------------------
  // Opciones de qr-code-styling
  // ---------------------------------------------------------------------------
  function currentDesign() {
    const styleKey = (form.querySelector('input[name="style"]:checked') || {}).value || "clasico";
    return {
      style: STYLES[styleKey] || STYLES.clasico,
      fg: form.elements.fg.value || "#000000",
      bg: form.elements.bg.value || "#ffffff",
      transparent: form.elements.transparent.checked
    };
  }

  function qrOptions(data, size, type) {
    const d = currentDesign();
    return {
      width: size,
      height: size,
      type: type,
      data: data,
      margin: Math.round(size * 0.04),
      image: state.center || undefined,
      qrOptions: { errorCorrectionLevel: state.center ? "H" : "M" },
      dotsOptions: { type: d.style.dots, color: d.fg },
      cornersSquareOptions: { type: d.style.corners, color: d.fg },
      cornersDotOptions: { type: d.style.cornerDot, color: d.fg },
      backgroundOptions: { color: d.transparent ? "rgba(0,0,0,0)" : d.bg },
      imageOptions: { hideBackgroundDots: true, imageSize: 0.32, margin: Math.round(size * 0.008), crossOrigin: "anonymous" }
    };
  }

  // ---------------------------------------------------------------------------
  // Avisos de calidad (contraste, longitud, logo)
  // ---------------------------------------------------------------------------
  function luminance(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex);
    if (!m) return 1;
    const n = parseInt(m[1], 16);
    const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
      v /= 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
  }

  function contrast(a, b) {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }

  function updateWarnings() {
    const out = [];
    const d = currentDesign();
    const bg = d.transparent ? "#ffffff" : d.bg;
    const ratio = contrast(d.fg, bg);

    if (ratio < 3) {
      out.push({ bad: true, text: "Poco contraste entre el código y el fondo: muchos móviles no podrán leerlo. Usa un código oscuro sobre un fondo claro." });
    } else if (luminance(d.fg) > luminance(bg)) {
      out.push({ text: "Código claro sobre fondo oscuro: la mayoría de móviles lo leen, pero algunos antiguos no. Pruébalo antes de imprimir." });
    }
    if (d.transparent && luminance(d.fg) > 0.4) {
      out.push({ text: "Con fondo transparente, un código claro puede perderse si lo pones sobre un fondo claro." });
    }
    if (state.center && state.payload) {
      out.push({ text: "Con logo en el centro, escanéalo con tu móvil antes de imprimir muchas copias." });
    }
    if (state.payload.length > 300) {
      out.push({ text: "Contenido largo: el código tendrá muchos puntos pequeños. Imprímelo grande o usa un enlace más corto." });
    }
    if (state.type === "whatsapp" && state.payload && digits(val("wanum")).length < 8) {
      out.push({ text: "Revisa el número: debe incluir el código de país (por ejemplo +52 o +34)." });
    }
    if (state.type === "email" && state.payload && val("mailto").indexOf("@") < 0) {
      out.push({ text: "Ese correo no parece completo (falta la @)." });
    }

    warningsEl.innerHTML = "";
    out.forEach((w) => {
      const li = document.createElement("li");
      if (w.bad) li.className = "bad";
      li.textContent = w.text;
      warningsEl.appendChild(li);
    });
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------
  function setDownloadsEnabled(on) {
    $$("[data-download], [data-copy]").forEach((b) => { b.disabled = !on; });
  }

  function render() {
    state.payload = (BUILDERS[state.type] || BUILDERS.url)();
    const empty = !state.payload;
    card.setAttribute("data-state", empty ? "idle" : "done");
    setDownloadsEnabled(!empty);

    const opts = qrOptions(empty ? SAMPLE : state.payload, 600, "canvas");
    try {
      if (!state.qr) {
        state.qr = new window.QRCodeStyling(opts);
        state.qr.append(previewEl);
      } else {
        state.qr.update(opts);
      }
      previewEl.setAttribute("aria-label", empty
        ? "Código QR de ejemplo"
        : "Vista previa del código QR con: " + state.payload.slice(0, 120));
      errorEl.hidden = true;
    } catch (e) {
      console.warn("[render] failed:", e);
      showError("No pudimos crear el código con ese contenido. Prueba con un texto más corto.");
    }
    updateWarnings();
  }

  function scheduleRender() {
    clearTimeout(state.timer);
    state.timer = setTimeout(render, 130);
  }

  function showError(msg) {
    card.setAttribute("data-state", "error");
    errorEl.textContent = msg;
    errorEl.hidden = false;
    setDownloadsEnabled(false);
  }

  // ---------------------------------------------------------------------------
  // Descargas
  // ---------------------------------------------------------------------------
  function fileSlug() {
    let base = state.payload
      .replace(/^(https?:\/\/|mailto:|tel:)/i, "")
      .replace(/^www\./i, "");
    if (state.type === "wifi") base = "wifi-" + val("ssid");
    if (state.type === "whatsapp") base = "whatsapp-" + digits(val("wanum"));
    base = base.normalize("NFD").replace(/[̀-ͯ]/g, "")
      .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40);
    return "qr-" + (base || "codigo");
  }

  function saveBlob(blob, name) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
  }

  function flash(btn, text) {
    // Guarda el contenido original una sola vez: dos clics seguidos no deben dejar «✓» pegado
    if (!btn._label) btn._label = btn.innerHTML;
    clearTimeout(btn._flashTimer);
    btn.classList.add("is-done");
    btn.textContent = text;
    btn._flashTimer = setTimeout(() => { btn.classList.remove("is-done"); btn.innerHTML = btn._label; }, 1600);
  }

  async function buildBlob(ext) {
    const size = ext === "svg" ? 1024 : parseInt($("[data-size]").value, 10) || 1024;
    const inst = new window.QRCodeStyling(qrOptions(state.payload, size, ext === "svg" ? "svg" : "canvas"));
    const raw = await inst.getRawData(ext);
    if (!raw) throw new Error("sin datos");
    return raw instanceof Blob ? raw : new Blob([raw], { type: ext === "svg" ? "image/svg+xml" : "image/png" });
  }

  async function onDownload(e) {
    const btn = e.currentTarget;
    const ext = btn.getAttribute("data-download");
    if (!state.payload) return;
    btn.disabled = true;
    try {
      const blob = await buildBlob(ext);
      saveBlob(blob, fileSlug() + "." + ext);
      btn.disabled = false;
      flash(btn, "✓ Descargado");
      document.dispatchEvent(new CustomEvent("qr:downloaded", { detail: { ext: ext } }));
    } catch (err) {
      console.warn("[download] failed:", err);
      btn.disabled = false;
      showError("No se pudo preparar la descarga. Vuelve a intentarlo.");
    }
  }

  async function onCopy(e) {
    const btn = e.currentTarget;
    try {
      const blob = await buildBlob("png");
      await navigator.clipboard.write([new window.ClipboardItem({ "image/png": blob })]);
      flash(btn, "✓ Copiado");
    } catch (err) {
      console.warn("[copy] failed:", err);
      flash(btn, "No se pudo copiar");
    }
  }

  // ---------------------------------------------------------------------------
  // Centro: emoji o logo (uno excluye al otro)
  // ---------------------------------------------------------------------------
  function emojiToDataUrl(emoji) {
    const c = document.createElement("canvas");
    c.width = c.height = 160;
    const ctx = c.getContext("2d");
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = '120px "Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
    ctx.fillText(emoji, 80, 90);
    return c.toDataURL("image/png");
  }

  function setCenter(dataUrl, kind) {
    state.center = dataUrl;
    state.centerKind = kind;
    $("[data-clear-center]").hidden = !dataUrl;
    $(".logo-row .btn-ghost").classList.toggle("is-active", kind === "logo");
    scheduleRender();
  }

  function initCenter() {
    $$("[data-emoji]").forEach((b) => {
      b.setAttribute("aria-pressed", "false");
      b.addEventListener("click", () => {
        const already = b.getAttribute("aria-pressed") === "true";
        $$("[data-emoji]").forEach((x) => x.setAttribute("aria-pressed", "false"));
        form.elements.logo.value = "";
        if (already) { setCenter(null, null); return; }
        b.setAttribute("aria-pressed", "true");
        setCenter(emojiToDataUrl(b.getAttribute("data-emoji")), "emoji");
      });
    });

    form.elements.logo.addEventListener("change", (e) => {
      const file = e.target.files && e.target.files[0];
      if (!file) return;
      if (!/^image\//.test(file.type)) { showError("Ese archivo no es una imagen. Usa PNG, JPG, WEBP o SVG."); return; }
      if (file.size > MAX_LOGO) { showError("El logo pesa demasiado (máximo 5 MB)."); return; }
      const reader = new FileReader();
      reader.onload = () => {
        $$("[data-emoji]").forEach((x) => x.setAttribute("aria-pressed", "false"));
        setCenter(String(reader.result), "logo");
      };
      reader.onerror = () => showError("No pudimos leer esa imagen. Prueba con otra.");
      reader.readAsDataURL(file);
    });

    $("[data-clear-center]").addEventListener("click", () => {
      $$("[data-emoji]").forEach((x) => x.setAttribute("aria-pressed", "false"));
      form.elements.logo.value = "";
      setCenter(null, null);
    });
  }

  // ---------------------------------------------------------------------------
  // Pestañas de tipo
  // ---------------------------------------------------------------------------
  function selectType(type, focus) {
    state.type = type;
    $$(".tab").forEach((t) => t.setAttribute("aria-selected", String(t.getAttribute("data-type") === type)));
    $$(".panel").forEach((p) => { p.hidden = p.getAttribute("data-panel") !== type; });
    if (focus) {
      const first = $('.panel[data-panel="' + type + '"] input, .panel[data-panel="' + type + '"] textarea');
      if (first) first.focus({ preventScroll: true });
    }
    render();
  }

  function initTabs() {
    $$(".tab").forEach((t) => {
      t.addEventListener("click", () => selectType(t.getAttribute("data-type"), true));
    });
  }

  // ---------------------------------------------------------------------------
  // Arranque
  // ---------------------------------------------------------------------------
  function boot() {
    card = $(".tool-card");
    form = $("#qr-form");
    previewEl = $("[data-qr]");
    warningsEl = $("[data-warnings]");
    errorEl = $("[data-error]");
    if (!card || !form) return;

    safe(() => { const y = $("[data-year]"); if (y) y.textContent = new Date().getFullYear(); }, "year");

    if (typeof window.QRCodeStyling !== "function") {
      showError("No se pudo cargar el generador. Recarga la página o prueba con otro navegador.");
      return;
    }

    safe(initTabs, "initTabs");
    safe(initCenter, "initCenter");

    safe(() => {
      form.addEventListener("input", (e) => {
        if (e.target && e.target.name === "logo") return;
        scheduleRender();
      });
      form.addEventListener("change", (e) => {
        if (e.target && e.target.name === "logo") return;
        scheduleRender();
      });
      $$("[data-download]").forEach((b) => b.addEventListener("click", onDownload));
    }, "initForm");

    safe(() => {
      const copyBtn = $("[data-copy]");
      if (copyBtn && navigator.clipboard && navigator.clipboard.write && window.ClipboardItem && window.isSecureContext) {
        copyBtn.hidden = false;
        copyBtn.addEventListener("click", onCopy);
      }
    }, "initCopy");

    safe(render, "render");
    document.documentElement.classList.add("is-ready");
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
