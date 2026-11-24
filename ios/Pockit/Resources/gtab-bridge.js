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
    ".pk-zone{position:absolute;transform:translate(-50%,14px);white-space:nowrap;padding:3px 9px;border-radius:11px;background:rgba(27,16,48,.82);border:1.5px solid #FF3E8A;color:#FFF4E6;font:700 12px -apple-system,system-ui,sans-serif;box-shadow:0 2px 8px rgba(0,0,0,.35)}",
    ".pk-zone-done{border-color:#2EE6A8;color:#2EE6A8}",
    ".pk-stop{position:absolute;transform:translate(-50%,-50%);width:28px;height:28px;border-radius:14px;background:#FF3E8A;border:2.5px solid #FFF4E6;color:#fff;font:800 14px -apple-system,system-ui,sans-serif;display:flex;align-items:center;justify-content:center;box-shadow:0 3px 10px rgba(0,0,0,.45)}",
    ".pk-pin{width:34px!important;height:34px!important;margin:-17px 0 0 -17px!important;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:0 2px 6px rgba(0,0,0,.35);font-size:18px;line-height:1;border:3px solid var(--c,#FF3E8A)}",
    ".pk-place{width:30px!important;height:30px!important;margin:-15px 0 0 -15px!important;border-radius:50%;background:var(--c,#333);display:grid;place-items:center;box-shadow:0 2px 6px rgba(0,0,0,.4);border:2px solid #fff;overflow:hidden}",
    ".pk-place img{width:100%;height:100%;object-fit:contain}",
    ".pk-place svg{width:18px;height:18px;fill:#fff}",
    ".pk-pin.pk-done{opacity:.6;filter:saturate(.4)}",
    ".pk-pin.pk-new{animation:pkDrop .35s cubic-bezier(.3,1.5,.5,1)}",
    "@keyframes pkDrop{0%{transform:translateY(-20px) scale(.6);opacity:0}100%{transform:none;opacity:1}}"
  ].join("\n");
  // v3: el mapa llena hasta abajo (sin la franja azul): la página usa toda la pantalla, también la zona de la rayita
  try {
    var vp = document.querySelector("meta[name=viewport]");
    if (!vp) { vp = document.createElement("meta"); vp.name = "viewport"; (document.head || document.documentElement).appendChild(vp); }
    vp.content = "width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover";
  } catch (e) {}
  var st = document.createElement("style");
  st.id = "pk-map-css";
  st.textContent = css;
  (document.head || document.documentElement).appendChild(st);

  var map = null, layer = null, pins = [], lastIds = {};
  // v5: la página le pone al mapa "alto de pantalla menos su menú" con fuerza; se lo cambiamos a toda la pantalla
  // (eso era la franja azul de abajo)
  function fullHeight() {
    var el = document.getElementById("gtab-map");
    if (!el) return;
    if (el.style.getPropertyValue("height") !== "100%" || el.style.getPropertyPriority("height") !== "important") {
      el.style.setProperty("height", "100%", "important");
      el.style.setProperty("min-height", "0", "important");
      try { map && map.invalidateSize({ pan: false }); } catch (e) {}
    }
  }
  function ready() {
    map = window.GTAB && window.GTAB.map;
    if (!map || !window.L) return false;
    fullHeight();
    try {
      var gm = document.getElementById("gtab-map");
      if (gm) new MutationObserver(fullHeight).observe(gm, { attributes: true, attributeFilter: ["style"] });
    } catch (e) {}
    window.addEventListener("resize", fullHeight);
    try { map.invalidateSize(); } catch (e) {}
    if (!map.getPane("pkpins")) map.createPane("pkpins");
    map.on("zoomend", function () { try { zoneZoom(); } catch (e) {} });
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
    // v4: el mapa nunca deja ver la orilla (la franja azul lisa): no se puede alejar ni mover más allá de las imágenes
    var origMin = null;
    function lockToTiles() {
      var tb = null;
      map.eachLayer(function (l) { if (!tb && l instanceof L.TileLayer && l.options.bounds) tb = L.latLngBounds(l.options.bounds); });
      if (!tb) return;
      map.options.maxBoundsViscosity = 1;
      map.setMaxBounds(tb);
      // zoom mínimo: el que llena la pantalla (si le falta muy poquito, se deja el de abajo y queda centrado,
      // con una orillita que queda tapada por los filtros y la barra de abajo)
      // v6: ya no se limita el zoom de lejos (la franja era el alto del mapa, no esto): se puede alejar hasta ver todo
      if (origMin == null) origMin = map.getMinZoom();
      map.setMinZoom(Math.min(origMin, -1));
    }
    try { lockToTiles(); } catch (e) {}
    window.addEventListener("resize", function () { try { lockToTiles(); } catch (e) {} });
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
    var chosen = [], seen = {};
    places.forEach(function (name) { var e = findEntry(name); if (e && !seen[e.data.id]) { seen[e.data.id] = 1; chosen.push(e); } });
    if (placeCats.length) allEntries().forEach(function (e) { if (placeCats.indexOf(e.data.category) >= 0 && !seen[e.data.id]) { seen[e.data.id] = 1; chosen.push(e); } });
    // v2: los que caen en el mismo punto (ej. Jason's House y su Meditation) se ponen uno al lado del otro
    var groups = [];
    chosen.forEach(function (e) {
      var g = groups.find(function (gr) { return Math.abs(gr.x - e.data.x) < 12 && Math.abs(gr.y - e.data.y) < 12; });
      if (g) g.items.push(e); else groups.push({ x: e.data.x, y: e.data.y, items: [e] });
    });
    var offset = new Map();
    groups.forEach(function (g) { var n = g.items.length; g.items.forEach(function (e, i) { offset.set(e, (i - (n - 1) / 2) * 34); }); });
    chosen.forEach(function (e) {
      var c = catOf(e.data.category);
      var ll = window.GTAB.worldToLatLng(e.data.x, e.data.y);
      var dx = offset.get(e) || 0;
      var icon = L.divIcon({ className: "", html: "<div class='pk-place' style='--c:" + (c.color || "#333") + ";transform:translateX(" + dx + "px)'>" + iconHtml(e.data.category) + "</div>", iconSize: [30, 30], iconAnchor: [0, 0] });
      var m = L.marker(ll, { icon: icon, pane: "pkpins", keyboard: false });
      m.on("click", function () { post({ type: "placeTap", name: e.data.name, cat: c.name || e.data.category, lat: ll.lat, lng: ll.lng, near: nearby(ll) }); });
      placeLayer.addLayer(m);
    });
  }
  window.pkSetPlaces = function (list) { places = list || []; drawPlaces(); };
  // categorías completas (ej. todas las gasolineras) — pa' meter lugares en bloque
  var placeCats = [];
  window.pkSetPlaceCats = function (list) { placeCats = list || []; drawPlaces(); };
  window.pkCategories = function () {
    var count = {};
    allEntries().forEach(function (e) { count[e.data.category] = (count[e.data.category] || 0) + 1; });
    return Object.keys(count).map(function (id) { var c = catOf(id); return { id: id, name: c.name || id, group: c.group || "", count: count[id] }; })
      .sort(function (a, b) { return (a.group + a.name).localeCompare(b.group + b.name); });
  };
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
  // Copia pa' usar sin internet: lugares, categorías, íconos y nombres de zonas, como los decodifica la página.
  // v7: coleccionables por zona: "llevás / total" en cada condado, ciudad o barrio según el zoom.
  // Solo números (nunca pines de lo que falta: eso sería spoiler).
  var zoneCfg = null, zoneLayer = null, zoneStats = null;
  function zNorm(s) { return String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]/g, ""); }
  function zoneLevel(z) { return z < 0.5 ? "county" : (z < 2.5 ? "city" : "district"); }
  function computeZones() {
    zoneStats = { county: {}, city: {}, district: {} };
    if (!zoneCfg) return;
    var labs = { county: [], city: [], district: [] };
    (zoneCfg.labels || []).forEach(function (l) {
      if (l.kind === "county") labs.county.push(l);
      else if (l.sub === "district") labs.district.push(l);
      else labs.city.push(l);
    });
    if (!labs.district.length) labs.district = labs.city;
    var cats = {}; (zoneCfg.cats || []).forEach(function (c) { cats[c.id] = c.name || c.id; });
    var found = {}; Object.keys(zoneCfg.found || {}).forEach(function (k) { found[k] = (zoneCfg.found[k] || []).map(zNorm).filter(function (x) { return x.length > 2; }); });
    function nearest(list, ll) {
      var best = null, bd = Infinity;
      for (var i = 0; i < list.length; i++) { var dx = list[i].lng - ll.lng, dy = list[i].lat - ll.lat, d = dx * dx + dy * dy; if (d < bd) { bd = d; best = list[i]; } }
      return best;
    }
    allEntries().forEach(function (e) {
      var d = e.data, cn = cats[d.category];
      if (!cn) return;
      var ll = window.GTAB.worldToLatLng(d.x, d.y);
      var n = zNorm(d.name), fl = found[d.category] || [];
      var got = fl.some(function (f) { return f === n || (f.length > 4 && (n.indexOf(f) >= 0 || f.indexOf(n) >= 0)); });
      ["county", "city", "district"].forEach(function (lv) {
        var lab = nearest(labs[lv], ll); if (!lab) return;
        var k = lab.t + "@" + lab.lat.toFixed(1) + "," + lab.lng.toFixed(1);
        var st = zoneStats[lv][k] || (zoneStats[lv][k] = { name: lab.t, lat: lab.lat, lng: lab.lng, found: 0, total: 0, byCat: {} });
        st.total++; if (got) st.found++;
        var bc = st.byCat[cn] || (st.byCat[cn] = { found: 0, total: 0 });
        bc.total++; if (got) bc.found++;
      });
    });
  }
  function drawZones() {
    if (!map) return;
    if (!zoneLayer) zoneLayer = L.layerGroup().addTo(map);
    zoneLayer.clearLayers();
    if (!zoneCfg || !zoneCfg.on || !zoneStats) return;
    var lv = zoneLevel(map.getZoom()), all = zoneStats[lv];
    Object.keys(all).forEach(function (k) {
      var st = all[k];
      var done = st.total > 0 && st.found >= st.total;
      var icon = L.divIcon({ className: "", iconSize: [0, 0], iconAnchor: [0, 0],
        html: "<div class='pk-zone" + (done ? " pk-zone-done" : "") + "'>" + st.found + " / " + st.total + "</div>" });
      var m = L.marker([st.lat, st.lng], { icon: icon, pane: "pkpins", keyboard: false });
      m.on("click", function () {
        var by = Object.keys(st.byCat).map(function (c) { return { cat: c, found: st.byCat[c].found, total: st.byCat[c].total }; })
          .sort(function (a, b) { return b.total - a.total; });
        post({ type: "zoneTap", name: st.name, level: lv, found: st.found, total: st.total, byCat: by });
      });
      zoneLayer.addLayer(m);
    });
  }
  window.pkSetZones = function (cfg) { zoneCfg = cfg; computeZones(); drawZones(); };
  var zoneLv = null;
  function zoneZoom() { if (!zoneCfg || !zoneCfg.on) return; var lv = zoneLevel(map.getZoom()); if (lv !== zoneLv) { zoneLv = lv; drawZones(); } }

  // v7: ruta del día (la arma Marisol): paradas numeradas unidas con una línea punteada
  var routeLayer = null, routePts = [];
  window.pkSetRoute = function (names) {
    if (!map) return [];
    if (!routeLayer) routeLayer = L.layerGroup().addTo(map);
    routeLayer.clearLayers(); routePts = [];
    var missing = [];
    (names || []).forEach(function (n, i) {
      var e = findEntry(n);
      if (!e) { missing.push(n); return; }
      var ll = window.GTAB.worldToLatLng(e.data.x, e.data.y);
      routePts.push(ll);
      var icon = L.divIcon({ className: "", iconSize: [0, 0], iconAnchor: [0, 0], html: "<div class='pk-stop'>" + (routePts.length) + "</div>" });
      var m = L.marker(ll, { icon: icon, pane: "pkpins", keyboard: false, zIndexOffset: 1000 });
      var c = catOf(e.data.category);
      m.on("click", function () { post({ type: "placeTap", name: e.data.name, cat: c.name || e.data.category, lat: ll.lat, lng: ll.lng, near: nearby(ll) }); });
      routeLayer.addLayer(m);
    });
    if (routePts.length > 1) routeLayer.addLayer(L.polyline(routePts, { color: "#FF3E8A", weight: 4, opacity: 0.9, dashArray: "8 8", pane: "pkpins", interactive: false }));
    return missing;
  };
  window.pkFitRoute = function () { if (map && routePts.length) map.flyToBounds(L.latLngBounds(routePts).pad(0.25), { duration: 0.7, maxZoom: 4 }); };

  window.pkSnapshot = function () {
    if (!map || (window.GTAB && window.GTAB.offline)) return null;
    var cats = {}, icons = {}, labels = [], tile = null;
    var byId = (window.GTAB && window.GTAB.categoryById) || {};
    Object.keys(byId).forEach(function (id) {
      var c = byId[id] || {};
      cats[id] = { id: id, name: c.name || id, color: c.color || "", icon: c.icon || "", group: c.group || "" };
      if (c.icon && !/^game-blip/.test(c.icon) && window.GTAB_ICONS && window.GTAB_ICONS[c.icon]) icons[c.icon] = window.GTAB_ICONS[c.icon];
    });
    map.eachLayer(function (l) {
      if (l instanceof L.TileLayer && !tile) {
        var o = l.options, b = o.bounds ? L.latLngBounds(o.bounds) : null;
        tile = { url: l._url, tileSize: o.tileSize, zoomOffset: o.zoomOffset, maxNativeZoom: o.maxNativeZoom,
                 bounds: b ? [[b.getSouth(), b.getWest()], [b.getNorth(), b.getEast()]] : null };
      }
      if (!l._icon || !l.getLatLng) return;
      var cls = l._icon.className || "", txt = (l._icon.textContent || "").trim();
      if (!txt) return;
      if (cls.indexOf("gtab-county-label") >= 0) labels.push({ kind: "county", t: txt, lat: l.getLatLng().lat, lng: l.getLatLng().lng });
      else if (cls.indexOf("gtab-place-label") >= 0) {
        var sub = (cls.match(/gtab-place-(region|city|town|district)/) || [])[1] || "town";
        labels.push({ kind: "place", sub: sub, t: txt, lat: l.getLatLng().lat, lng: l.getLatLng().lng });
      }
    });
    var tr = map.options.crs.transformation, ib = window.GTAB.islandBounds;
    return JSON.stringify({
      v: 2,
      savedAt: Date.now(),
      crs: tr ? [tr._a, tr._b, tr._c, tr._d] : null,
      island: ib ? [[ib.getSouth(), ib.getWest()], [ib.getNorth(), ib.getEast()]] : null,
      sea: (window.GTAB_CONFIG && window.GTAB_CONFIG.sea) || "#2F90B0",
      assetPath: (window.GTAB_CONFIG && window.GTAB_CONFIG.assetPath) || "/images/gta-6/maps/gtab-map/",
      tile: tile, cats: cats, icons: icons, labels: labels,
      entries: allEntries().map(function (e) { var d = e.data; return { id: d.id, name: d.name, category: d.category, x: d.x, y: d.y }; })
    });
  };
  window.addEventListener("resize", function () { try { map && map.invalidateSize(); } catch (e) {} });
  window.pkFit = function () { try { map && map.invalidateSize({ pan: false }); } catch (e) {} };
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
