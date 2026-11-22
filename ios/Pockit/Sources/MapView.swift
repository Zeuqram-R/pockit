import SwiftUI
import UIKit
import PhotosUI

// MARK: - Mapa propio
// Jose importa una captura de SU mapa (del PS5); la imagen se queda solo en el teléfono
// (Application Support), nunca en el repo. Encima van sus pines, y desde cada pin le pide
// a Marisol una pista sin spoilers con el recorte del mapa adjunto.

enum PinKind: String, CaseIterable, Identifiable {
    case pin, secreto, coleccionable, foto, negocio
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pin: return "mappin.circle.fill"
        case .secreto: return "questionmark.circle.fill"
        case .coleccionable: return "star.circle.fill"
        case .foto: return "camera.circle.fill"
        case .negocio: return "dollarsign.circle.fill"
        }
    }
    var color: UIColor {
        switch self {
        case .pin: return UIColor(Theme.pink)
        case .secreto: return UIColor(Theme.teal)
        case .coleccionable: return UIColor(Theme.sunset)
        case .foto: return UIColor(Theme.switchPink)
        case .negocio: return UIColor(Theme.coral)
        }
    }
    func title(_ t: L10n) -> String {
        switch self {
        case .pin: return t.s("Lugar", "Place")
        case .secreto: return t.s("Secreto", "Secret")
        case .coleccionable: return t.s("Coleccionable", "Collectible")
        case .foto: return t.s("Foto / vista", "Photo spot")
        case .negocio: return t.s("Negocio / dinero", "Business / money")
        }
    }
}

enum MapImageStore {
    static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pockit-map.jpg")
    }()
    static func load() -> UIImage? { UIImage(contentsOfFile: url.path) }
    static func save(_ data: Data) -> UIImage? {
        guard let img = UIImage(data: data) else { return nil }
        // Se guarda como JPEG de hasta 4096 px pa' que no pese de más.
        let maxSide: CGFloat = 4096
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        try? out.jpegData(compressionQuality: 0.88)?.write(to: url, options: .atomic)
        return out
    }
    static func remove() { try? FileManager.default.removeItem(at: url) }

    /// Recorte alrededor del pin con un círculo rosa, pa' mandárselo a Marisol.
    static func crop(_ img: UIImage, at p: CGPoint) -> Data? {
        let W = img.size.width, H = img.size.height
        let side = max(240, min(W, H) * 0.28)
        let cx = p.x * W, cy = p.y * H
        let rect = CGRect(x: min(max(0, cx - side / 2), max(0, W - side)), y: min(max(0, cy - side / 2), max(0, H - side)),
                          width: min(side, W), height: min(side, H))
        let outSide: CGFloat = 900
        let k = outSide / rect.width
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: CGSize(width: outSide, height: rect.height * k), format: fmt).image { ctx in
            img.draw(in: CGRect(x: -rect.minX * k, y: -rect.minY * k, width: W * k, height: H * k))
            let c = CGPoint(x: (cx - rect.minX) * k, y: (cy - rect.minY) * k)
            let ring = UIBezierPath(ovalIn: CGRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68))
            ring.lineWidth = 7
            UIColor(Theme.pink).setStroke(); ring.stroke()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)).fill()
        }
        return out.jpegData(compressionQuality: 0.85)
    }
}

struct MapaView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel

    @State private var image: UIImage? = MapImageStore.load()
    @State private var photoItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var editing: MapPin?
    @State private var filter: PinKind?
    @State private var showList = false
    @State private var confirmReplace = false

    var body: some View {
        let t = settings.t
        NavigationStack {
            Group {
                if let image {
                    ZoomableMap(image: image, pins: visiblePins, onLongPress: { p in
                        editing = MapPin(x: p.x, y: p.y, name: "", kind: (filter ?? .pin).rawValue)
                    }, onTapPin: { pin in editing = pin })
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) { filterBar(t) }
                    .overlay(alignment: .bottom) {
                        if store.data.pins.isEmpty {
                            Text(t.s("Mantené presionado en el mapa pa' poner un pin", "Long-press the map to drop a pin"))
                                .font(Theme.text(13, .medium)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .padding(.bottom, 100)
                        }
                    }
                } else {
                    emptyState(t)
                }
            }
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("MAPA", "MAP"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if image != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showList = true } label: { Image(systemName: "list.bullet") }
                            .accessibilityLabel(t.s("Lista de pines", "Pin list"))
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button { confirmReplace = true } label: { Label(t.s("Cambiar imagen del mapa", "Replace map image"), systemImage: "photo") }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .photosPicker(isPresented: $showPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { image = MapImageStore.save(data) }
                    photoItem = nil
                }
            }
            .confirmationDialog(t.s("¿Cambiar la imagen? Los pines se quedan donde están.", "Replace the image? Pins stay where they are."),
                                isPresented: $confirmReplace, titleVisibility: .visible) {
                Button(t.s("Elegir otra imagen", "Choose another image")) { showPicker = true }
                Button(t.cancel, role: .cancel) {}
            }
            .sheet(item: $editing) { pin in
                PinSheet(pin: pin, image: image) { editing = nil }
                    .environmentObject(settings).environmentObject(store).environmentObject(state).environmentObject(web)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showList) {
                PinListSheet { pin in showList = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { editing = pin } }
                    .environmentObject(settings).environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var visiblePins: [MapPin] {
        store.data.pins.filter { filter == nil || $0.kind == filter!.rawValue }
    }

    private func filterBar(_ t: L10n) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(t.s("Todos", "All"), on: filter == nil) { filter = nil }
                ForEach(PinKind.allCases) { k in
                    chip(k.title(t), symbol: k.symbol, color: Color(k.color), on: filter == k) { filter = filter == k ? nil : k }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, symbol: String? = nil, color: Color = .white, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).foregroundStyle(color) }
                Text(title)
            }
            .font(Theme.text(13, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Capsule().fill(on ? Theme.purple : Theme.nightDeep.opacity(0.55)))
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(on ? Theme.switchPink : Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ t: L10n) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image("TabColor_mapa").resizable().scaledToFit().frame(width: 110, height: 110)
            Text(t.s("TU MAPA DE LEONIDA", "YOUR LEONIDA MAP")).font(Theme.display(28)).foregroundStyle(.white)
            Text(t.s("Tomale un screenshot al mapa en el PS5 (o una foto a la tele) y subilo. Después mantené presionado pa' poner pines, y desde cada pin le pedís a Marisol una pista sin spoilers.",
                     "Take a screenshot of the map on your PS5 (or a photo of the TV) and import it. Then long-press to drop pins, and ask Marisol for a spoiler-free hint from any pin."))
                .font(Theme.text(15)).foregroundStyle(Theme.lilac).multilineTextAlignment(.center).padding(.horizontal, 36)
            Button { showPicker = true } label: {
                Label(t.s("Importar mi mapa", "Import my map"), systemImage: "photo.on.rectangle")
                    .font(Theme.text(17, .semibold)).foregroundStyle(Theme.nightDeep)
                    .padding(.horizontal, 22).frame(height: 48)
                    .background(Capsule().fill(Theme.switchPink))
            }
            .buttonStyle(.plain)
            Text(t.s("La imagen se queda solo en este teléfono.", "The image stays on this phone only."))
                .font(Theme.text(12)).foregroundStyle(Theme.lilac.opacity(0.7))
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hoja de un pin
struct PinSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel
    @State var pin: MapPin
    let image: UIImage?
    let close: () -> Void
    @State private var asking = false

    private var isNew: Bool { !store.data.pins.contains { $0.id == pin.id } }

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    TextField(t.s("Nombre (ej. muelle de Port Gellhorn)", "Name (e.g. the old pier)"), text: $pin.name)
                    TextField(t.s("Nota", "Note"), text: $pin.note, axis: .vertical).lineLimit(1...4)
                    Picker(t.s("Tipo", "Type"), selection: $pin.kind) {
                        ForEach(PinKind.allCases) { k in Label(k.title(t), systemImage: k.symbol).tag(k.rawValue) }
                    }
                    Toggle(t.s("Ya lo hice", "Done"), isOn: $pin.done)
                }
                .listRowBackground(Theme.panel)

                Section {
                    Button { ask(hint: true) } label: {
                        Label(t.s("Pista sin spoilers", "Spoiler-free hint"), systemImage: "sparkles")
                    }
                    Button { ask(hint: false) } label: {
                        Label(t.s("¿Qué hay por aquí?", "What's around here?"), systemImage: "binoculars.fill")
                    }
                } footer: {
                    Text(t.s("Le mando a Marisol un recorte del mapa con el punto marcado.", "Marisol gets a crop of your map with the spot marked."))
                }
                .listRowBackground(Theme.panel)
                .disabled(asking)

                if !isNew {
                    Section {
                        Button(role: .destructive) { store.delete(pin); close() } label: { Label(t.s("Borrar pin", "Delete pin"), systemImage: "trash") }
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(isNew ? t.s("Nuevo pin", "New pin") : (pin.name.isEmpty ? t.s("Pin", "Pin") : pin.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { close() } }
                ToolbarItem(placement: .confirmationAction) { Button(t.s("Guardar", "Save")) { save(); close() } }
            }
        }
    }

    private func save() {
        if pin.name.trimmingCharacters(in: .whitespaces).isEmpty { pin.name = PinKind(rawValue: pin.kind)?.title(settings.t) ?? "Pin" }
        store.savePin(pin)
    }

    private func ask(hint: Bool) {
        let t = settings.t
        save()
        asking = true
        let place = pin.name + (pin.note.isEmpty ? "" : " (\(pin.note))")
        let kind = PinKind(rawValue: pin.kind) ?? .pin
        let msg: String
        if hint {
            switch kind {
            case .secreto:
                msg = t.s("📍 Mapa: ¿hay algún secreto cerca de este punto (\(place))? Dame solo la Pista 1, sin spoilers. Te adjunto el recorte de mi mapa con el punto en rosa.",
                          "📍 Map: is there a secret near this spot (\(place))? Just Pista 1, no spoilers. Attached is a crop of my map with the spot in pink.")
            case .coleccionable:
                msg = t.s("📍 Mapa: ¿hay coleccionables cerca de este punto (\(place))? Primero solo una pista, sin spoilers. Te adjunto el recorte de mi mapa con el punto en rosa.",
                          "📍 Map: any collectibles near this spot (\(place))? Just a hint first, no spoilers. Attached is a crop of my map with the spot in pink.")
            default:
                msg = t.s("📍 Mapa: dame una pista sin spoilers de algo que valga la pena cerca de este punto (\(place)). Te adjunto el recorte de mi mapa con el punto en rosa.",
                          "📍 Map: give me a spoiler-free hint about something worth it near this spot (\(place)). Attached is a crop of my map with the spot in pink.")
            }
        } else {
            msg = t.s("📍 Mapa: ¿qué hay por aquí (\(place))? Actividades, negocios, vistas, lo que valga la pena, sin spoilers. Te adjunto el recorte de mi mapa con el punto en rosa.",
                      "📍 Map: what's around here (\(place))? Activities, businesses, views, anything worth it, no spoilers. Attached is a crop of my map with the spot in pink.")
        }
        Task {
            if let image, let data = MapImageStore.crop(image, at: CGPoint(x: pin.x, y: pin.y)) {
                _ = await web.attach(data: data, name: "mapa-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg")
                try? await Task.sleep(for: .milliseconds(900))
            }
            state.tab = .marisol
            web.send(msg)
            asking = false
            close()
        }
    }
}

// MARK: - Lista de pines
struct PinListSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    let open: (MapPin) -> Void
    @State private var query = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                ForEach(PinKind.allCases) { k in
                    let pins = store.data.pins.filter { $0.kind == k.rawValue && (query.isEmpty || ($0.name + " " + $0.note).localizedCaseInsensitiveContains(query)) }
                    if !pins.isEmpty {
                        Section(k.title(t)) {
                            ForEach(pins) { p in
                                Button { open(p) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: p.done ? "checkmark.circle.fill" : k.symbol).foregroundStyle(Color(k.color)).font(.system(size: 22))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name).foregroundStyle(.white).strikethrough(p.done)
                                            if !p.note.isEmpty { Text(p.note).font(Theme.text(13)).foregroundStyle(Theme.lilac).lineLimit(1) }
                                        }
                                    }
                                }
                                .swipeActions { Button(role: .destructive) { store.delete(p) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                            }
                        }
                        .listRowBackground(Theme.panel)
                    }
                }
                if store.data.pins.isEmpty {
                    Text(t.s("Todavía no hay pines.", "No pins yet.")).foregroundStyle(Theme.lilac).listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .searchable(text: $query, prompt: t.s("Buscar", "Search"))
            .navigationTitle(t.s("Pines", "Pins"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Mapa con zoom (UIKit)
struct ZoomableMap: UIViewRepresentable {
    let image: UIImage
    let pins: [MapPin]
    let onLongPress: (CGPoint) -> Void
    let onTapPin: (MapPin) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.backgroundColor = UIColor(Theme.nightDeep)
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.bouncesZoom = true
        sv.contentInsetAdjustmentBehavior = .never
        let iv = UIImageView(image: image)
        iv.isUserInteractionEnabled = true
        iv.frame = CGRect(origin: .zero, size: image.size)
        sv.addSubview(iv)
        sv.contentSize = image.size
        context.coordinator.scroll = sv
        context.coordinator.imageView = iv
        let lp = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPress(_:)))
        lp.minimumPressDuration = 0.45
        iv.addGestureRecognizer(lp)
        let dbl = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        iv.addGestureRecognizer(dbl)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if c.imageView?.image !== image {
            c.imageView?.image = image
            c.imageView?.frame = CGRect(origin: .zero, size: image.size)
            sv.contentSize = image.size
            c.fitted = false
        }
        DispatchQueue.main.async { c.fitIfNeeded(); c.syncPins() }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableMap?
        weak var scroll: UIScrollView?
        weak var imageView: UIImageView?
        var fitted = false
        var views: [UUID: UIButton] = [:]

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func fitIfNeeded() {
            guard !fitted, let sv = scroll, let iv = imageView, let img = iv.image, sv.bounds.width > 0 else { return }
            let fit = min(sv.bounds.width / img.size.width, sv.bounds.height / img.size.height)
            sv.minimumZoomScale = fit
            sv.maximumZoomScale = max(fit * 8, 1.5)
            sv.zoomScale = max(fit, min(1, sv.bounds.height / img.size.height))
            fitted = true
            center()
        }

        func center() {
            guard let sv = scroll, let iv = imageView else { return }
            let w = iv.frame.width, h = iv.frame.height
            sv.contentInset = UIEdgeInsets(top: max(0, (sv.bounds.height - h) / 2), left: max(0, (sv.bounds.width - w) / 2),
                                           bottom: max(0, (sv.bounds.height - h) / 2), right: max(0, (sv.bounds.width - w) / 2))
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) { center(); scalePins() }

        func syncPins() {
            guard let iv = imageView, let parent else { return }
            let ids = Set(parent.pins.map(\.id))
            for (id, v) in views where !ids.contains(id) { v.removeFromSuperview(); views[id] = nil }
            for p in parent.pins {
                let b = views[p.id] ?? {
                    let nb = UIButton(type: .system)
                    nb.addTarget(self, action: #selector(tapPin(_:)), for: .touchUpInside)
                    iv.addSubview(nb)
                    views[p.id] = nb
                    return nb
                }()
                let kind = PinKind(rawValue: p.kind) ?? .pin
                let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
                b.setImage(UIImage(systemName: p.done ? "checkmark.circle.fill" : kind.symbol, withConfiguration: cfg), for: .normal)
                b.tintColor = kind.color
                b.backgroundColor = .white
                b.layer.cornerRadius = 17
                b.layer.shadowColor = UIColor.black.cgColor
                b.layer.shadowOpacity = 0.35
                b.layer.shadowRadius = 4
                b.layer.shadowOffset = CGSize(width: 0, height: 2)
                b.alpha = p.done ? 0.7 : 1
                b.accessibilityLabel = p.name
                b.tag = p.id.hashValue
                b.layer.setValue(p.id.uuidString, forKey: "pinID")
                b.bounds = CGRect(x: 0, y: 0, width: 34, height: 34)
                b.center = CGPoint(x: p.x * (iv.image?.size.width ?? 0), y: p.y * (iv.image?.size.height ?? 0))
            }
            scalePins()
        }

        /// Los pines mantienen su tamaño en pantalla aunque hagás zoom.
        func scalePins() {
            guard let sv = scroll else { return }
            let k = 1 / max(sv.zoomScale, 0.0001)
            for v in views.values { v.transform = CGAffineTransform(scaleX: k, y: k) }
        }

        @objc func tapPin(_ b: UIButton) {
            guard let s = b.layer.value(forKey: "pinID") as? String, let id = UUID(uuidString: s),
                  let pin = parent?.pins.first(where: { $0.id == id }) else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            parent?.onTapPin(pin)
        }

        @objc func longPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let iv = imageView, let img = iv.image else { return }
            let p = g.location(in: iv)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            parent?.onLongPress(CGPoint(x: p.x / img.size.width, y: p.y / img.size.height))
        }

        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let sv = scroll, let iv = imageView else { return }
            if sv.zoomScale > sv.minimumZoomScale * 1.5 { sv.setZoomScale(sv.minimumZoomScale, animated: true); return }
            let p = g.location(in: iv)
            let target = min(sv.maximumZoomScale, sv.zoomScale * 2.5)
            let w = sv.bounds.width / target, h = sv.bounds.height / target
            sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
        }
    }
}
