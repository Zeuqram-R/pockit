// Pockit · mapa de GTABase limpio: solo el mapa (con condados y nombres de zonas), sin sus pines ni la página.
// Encima van los pines de Pockit. Se comunica con la app por window.webkit.messageHandlers.pockitMap.
(function () {
  if (window.__pkMap) return;
  window.__pkMap = true;
  var post = function (o) { try { window.webkit.messageHandlers.pockitMap.postMessage(o); } catch (e) {} };

  var css = [
    "html,body{overflow:hidden!important;background:#2F90B0!important;-webkit-touch-callout:none!important;-webkit-user-select:none!important;user-select:none!important}",
    "body{visibility:hidden!important}",
    "#gtab-map,#gtab-map *{visibility:visible}",
    "#gtab-map{position:fixed!important;top:0!important;left:0!important;right:0!important;bottom:0!important;width:auto!important;height:auto!important;min-height:0!important;z-index:2147483000!important;margin:0!important;max-width:none!important;border-radius:0!important}",
    "#gtab-map .gtab-view{position:absolute!important;inset:0!important;width:100%!important;height:100%!important;background:#2F90B0!important}",
    ".gtab-sidebar,#gtab-map-intro,.leaflet-marker-pane,.leaflet-shadow-pane,.leaflet-popup-pane,.leaflet-tooltip-pane,.leaflet-gtabBlips-pane,.leaflet-gtabPopTop-pane,.leaflet-control-container,#gtab-map [class*=gtab-]:not(.gtab-view):not(.gtab-root):not(.leaflet-pane):not(.leaflet-pane *){display:none!important}",
    "#cmpbox,#cmpbox2,.cmpboxBG,#cmpwrapper{display:none!important}",
    ".leaflet-pkpins-pane{z-index:660}",
    ".pk-pin{width:34px!important;height:34px!important;margin:-17px 0 0 -17px!important;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:0 2px 6px rgba(0,0,0,.35);font-size:18px;line-height:1;border:3px solid var(--c,#FF3E8A)}",
    ".pk-place{width:30px!important;height:30px!important;margin:-15px 0 0 -15px!important;border-radius:50%;background:var(--c,#333);display:grid;place-items:center;box-shadow:0 2px 6px rgba(0,0,0,.4);border:2px solid #fff;overflow:hidden}",
    ".pk-place img{width:100%;height:100%;object-fit:contain}",
    ".pk-place svg{width:18px;height:18px;fill:#fff}",
    ".pk-pin.pk-done{opacity:.6;filter:saturate(.4)}",
    ".pk-pin.pk-new{animation:pkDrop .35s cubic-bezier(.3,1.5,.5,1)}",
    "@keyframes pkDrop{0%{transform:translateY(-20px) scale(.6);opacity:0}100%{transform:none;opacity:1}}"
  ].join("\n");
  var st = document.createElement("style");
  st.id = "pk-map-css";
  st.textContent = css;
  (document.head || document.documentElement).appendChild(st);

  var map = null, layer = null, pins = [], lastIds = {};
  function ready() {
    map = window.GTAB && window.GTAB.map;
    if (!map || !window.L) return false;
    try { map.invalidateSize(); } catch (e) {}
    if (!map.getPane("pkpins")) map.createPane("pkpins");
    layer = L.layerGroup().addTo(map);
    // tocar y mantener = poner pin (también con el mouse en la Mac)
    var timer = null, start = null;
    var c = map.getContainer();
    c.addEventListener("touchstart", function (e) {
      if (e.touches.length !== 1 || (e.target.closest && e.target.closest(".pk-pin"))) { clearTimeout(timer); return; }
      var t = e.touches[0]; start = { x: t.clientX, y: t.clientY };
      clearTimeout(timer);
      timer = setTimeout(function () {
        var r = c.getBoundingClientRect();
        var ll = map.containerPointToLatLng(L.point(start.x - r.left, start.y - r.top));
        post({ type: "longPress", lat: ll.lat, lng: ll.lng, near: nearby(ll) });
      }, 480);
    }, { passive: true });
    c.addEventListener("touchmove", function (e) {
      if (!start || !e.touches[0]) return;
      var t = e.touches[0];
      if (Math.abs(t.clientX - start.x) > 8 || Math.abs(t.clientY - start.y) > 8) clearTimeout(timer);
    }, { passive: true });
    ["touchend", "touchcancel"].forEach(function (n) { c.addEventListener(n, function () { clearTimeout(timer); }, { passive: true }); });
    map.on("contextmenu", function (e) { if (!("ontouchstart" in window)) post({ type: "longPress", lat: e.latlng.lat, lng: e.latlng.lng, near: nearby(e.latlng) }); });
    try { map.fitBounds(window.GTAB.islandBounds || map.getBounds()); } catch (e) {}
    draw();
    drawPlaces();
    post({ type: "ready" });
    return true;
  }

  // la zona y el condado más cercanos (de las etiquetas del propio mapa)
  function nearby(ll) {
    var best = { place: null, pd: Infinity, county: null, cd: Infinity };
    if (!map) return {};
    map.eachLayer(function (l) {
      if (!l.getLatLng || !l._icon) return;
      var cls = l._icon.className || "", txt = (l._icon.textContent || "").trim();
      if (!txt) return;
      var d = map.distance ? Math.hypot(l.getLatLng().lat - ll.lat, l.getLatLng().lng - ll.lng) : 0;
      if (cls.indexOf("gtab-county-label") >= 0 && d < best.cd) { best.cd = d; best.county = txt; }
      else if (cls.indexOf("gtab-place-label") >= 0 && d < best.pd) { best.pd = d; best.place = txt; }
    });
    return { place: best.place, county: best.county };
  }

  function draw() {
    if (!layer) return;
    layer.clearLayers();
    pins.forEach(function (p) {
      var cls = "pk-pin" + (p.done ? " pk-done" : "") + (lastIds[p.id] ? "" : " pk-new");
      var icon = L.divIcon({ className: "", html: "<div class='" + cls + "' style='--c:" + p.color + "'>" + p.emoji + "</div>", iconSize: [34, 34], iconAnchor: [0, 0] });
      var m = L.marker([p.lat, p.lng], { icon: icon, pane: "pkpins", keyboard: false });
      m.on("click", function () { post({ type: "pinTap", id: p.id }); });
      layer.addLayer(m);
    });
    lastIds = {};
    pins.forEach(function (p) { lastIds[p.id] = 1; });
  }

  window.pkSetPins = function (list) { pins = list || []; draw(); };

  // ---- Lugares del juego (los de GTABase), pero solo los que Jose ya desbloqueó ----
  var places = [], placeLayer = null;
  function norm(t) { return String(t || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[’‘`´]/g, "'").replace(/\s+/g, " ").trim(); }
  function allEntries() { try { return Object.values(window.GTAB.entries || {}); } catch (e) { return []; } }
  function catOf(id) { var c = window.GTAB && window.GTAB.categoryById; return (c && c[id]) || {}; }
  function iconHtml(cat) {
    var c = catOf(cat), ic = c.icon || "", base = (window.GTAB_CONFIG && window.GTAB_CONFIG.assetPath) || "/images/gta-6/maps/gtab-map/";
    if (/^game-blip/.test(ic)) return "<img src='" + base + "icons/" + ic + ".webp' alt=''>";
    var g = window.GTAB_ICONS && window.GTAB_ICONS[ic];
    if (g && g.paths) return "<svg viewBox='" + g.viewBox + "'>" + g.paths.map(function (d) { return "<path d='" + d + "'/>"; }).join("") + "</svg>";
    return "📍";
  }
  function findEntry(name) {
    var n = norm(name), list = allEntries();
    var hit = list.find(function (e) { return norm(e.data.name) === n; });
    return hit || list.find(function (e) { var m = norm(e.data.name); return m.indexOf(n) === 0 || (n.length > 5 && m.indexOf(n) >= 0); });
  }
  function drawPlaces() {
    if (!map) return;
    if (!placeLayer) placeLayer = L.layerGroup().addTo(map);
    placeLayer.clearLayers();
    places.forEach(function (name) {
      var e = findEntry(name); if (!e) return;
      var c = catOf(e.data.category);
      var ll = window.GTAB.worldToLatLng(e.data.x, e.data.y);
      var icon = L.divIcon({ className: "", html: "<div class='pk-place' style='--c:" + (c.color || "#333") + "'>" + iconHtml(e.data.category) + "</div>", iconSize: [30, 30], iconAnchor: [0, 0] });
      var m = L.marker(ll, { icon: icon, pane: "pkpins", keyboard: false });
      m.on("click", function () { post({ type: "placeTap", name: e.data.name, cat: c.name || e.data.category, lat: ll.lat, lng: ll.lng, near: nearby(ll) }); });
      placeLayer.addLayer(m);
    });
  }
  window.pkSetPlaces = function (list) { places = list || []; drawPlaces(); };
  // búsqueda por nombre (desde 3 letras, máximo 25 resultados: no es pa' curiosear el mapa entero)
  window.pkSearch = function (q) {
    var n = norm(q); if (n.length < 3) return [];
    return allEntries().filter(function (e) { return norm(e.data.name).indexOf(n) >= 0; }).slice(0, 25).map(function (e) {
      var c = catOf(e.data.category); return { name: e.data.name, cat: c.name || e.data.category };
    });
  };
  window.pkFocusPlace = function (name) {
    var e = findEntry(name); if (!e || !map) return false;
    map.flyTo(window.GTAB.worldToLatLng(e.data.x, e.data.y), Math.max(map.getZoom(), 4), { duration: 0.6 });
    return true;
  };
  // centra, espera que carguen los cuadritos (máx. 2.5 s) y avisa
  window.pkFocusWait = function (lat, lng, zoom) {
    return new Promise(function (resolve) {
      if (!map) return resolve({});
      try { map.invalidateSize(); } catch (e) {}
      map.setView([lat, lng], zoom, { animate: false });
      var t0 = Date.now();
      (function check() {
        var pending = document.querySelectorAll(".leaflet-tile-pane img.leaflet-tile:not(.leaflet-tile-loaded)").length;
        if (pending === 0 && Date.now() - t0 > 250 || Date.now() - t0 > 2500) resolve(nearby(L.latLng(lat, lng)));
        else setTimeout(check, 120);
      })();
    });
  };
  window.addEventListener("resize", function () { try { map && map.invalidateSize(); } catch (e) {} });
  window.pkFocus = function (lat, lng, zoom) {
    if (!map) return {};
    map.setView([lat, lng], zoom == null ? Math.max(map.getZoom(), 4) : zoom, { animate: false });
    return nearby(L.latLng(lat, lng));
  };
  window.pkFlyTo = function (lat, lng) { if (map) map.flyTo([lat, lng], Math.max(map.getZoom(), 4), { duration: 0.6 }); };
  window.pkNearby = function (lat, lng) { return nearby(L.latLng(lat, lng)); };
  window.pkView = function () { return map ? { lat: map.getCenter().lat, lng: map.getCenter().lng, zoom: map.getZoom() } : null; };
  window.pkSetView = function (lat, lng, zoom) { if (map) map.setView([lat, lng], zoom, { animate: false }); };

  var tries = 0;
  (function wait() {
    if (ready()) return;
    if (++tries > 200) { post({ type: "error", reason: "no-map" }); return; }
    setTimeout(wait, 100);
  })();
})();
