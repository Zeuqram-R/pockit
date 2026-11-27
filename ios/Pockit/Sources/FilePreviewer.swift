import UIKit
import QuickLook
import WebKit

/// Abre fotos y archivos del chat en pantalla completa (vista nativa de iOS, con botón de compartir/guardar).
@MainActor
final class FilePreviewer: NSObject, QLPreviewControllerDataSource, UIGestureRecognizerDelegate {
    static let shared = FilePreviewer()
    private var items: [URL] = []
    private weak var shown: QLPreviewController?

    func show(_ url: URL) {
        items = [url]
        let ql = QLPreviewController()
        ql.dataSource = self
        ql.modalPresentationStyle = .fullScreen
        guard let top = Self.topController() else { return }
        top.present(ql, animated: true)
        shown = ql
        // 0.8.2: deslizar hacia el centro (arriba o abajo) la cierra, siguiendo el dedo
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        ql.view.addGestureRecognizer(pan)
    }

    @objc private func panned(_ g: UIPanGestureRecognizer) {
        guard let v = shown?.view else { return }
        // 0.8.4: se mide contra la ventana (la vista se mueve con el dedo; medida contra sí misma daba casi 0 y nunca cerraba)
        let ref = v.window ?? v.superview
        let ty = g.translation(in: ref).y
        let progress = min(1, abs(ty) / 300)
        func scrolls(_ view: UIView) -> [UIScrollView] { ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap { scrolls($0) } }
        switch g.state {
        case .began:
            // la foto no se arrastra por dentro mientras se cierra
            scrolls(v).forEach { $0.panGestureRecognizer.isEnabled = false; $0.panGestureRecognizer.isEnabled = true; $0.isScrollEnabled = false }
        case .changed:
            v.transform = CGAffineTransform(translationX: 0, y: ty).scaledBy(x: 1 - progress * 0.12, y: 1 - progress * 0.12)
            v.alpha = 1 - progress * 0.5
        case .ended, .cancelled:
            scrolls(v).forEach { $0.isScrollEnabled = true }
            let vy = g.velocity(in: ref).y
            if abs(ty) > 110 || abs(vy) > 900 {
                UIView.animate(withDuration: 0.22, animations: {
                    v.transform = CGAffineTransform(translationX: 0, y: ty > 0 ? v.bounds.height : -v.bounds.height)
                    v.alpha = 0
                }, completion: { _ in self.shown?.dismiss(animated: false) })
            } else {
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
                    v.transform = .identity; v.alpha = 1
                }
            }
        default: break
        }
    }

    /// Solo arranca si el gesto es vertical (pa' no pelear con el zoom ni con pasar de página).
    nonisolated func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated {
            guard let p = g as? UIPanGestureRecognizer, let v = p.view else { return true }
            let vel = p.velocity(in: v)
            if abs(vel.y) <= abs(vel.x) * 1.2 { return false }
            // 0.8.3: solo si la foto de verdad se puede mover (con zoom, el contenido es más grande que la pantalla)
            func scrollable(_ view: UIView) -> Bool {
                if let sc = view as? UIScrollView, sc.isScrollEnabled,
                   sc.contentSize.height > sc.bounds.height + 2 || sc.contentSize.width > sc.bounds.width + 2,
                   sc.zoomScale > sc.minimumZoomScale + 0.01 { return true }
                return view.subviews.contains { scrollable($0) }
            }
            return !scrollable(v)
        }
    }
    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    /// Guarda bytes que mandó el chat (base64) en un archivo temporal y lo abre.
    func show(base64: String, name: String, mime: String) {
        guard let data = Data(base64Encoded: base64) else { return }
        var file = name.isEmpty ? "archivo" : name
        if (file as NSString).pathExtension.isEmpty {
            let ext = mime.contains("png") ? "png" : mime.contains("pdf") ? "pdf" : mime.contains("gif") ? "gif" : mime.contains("webp") ? "webp" : "jpg"
            file += "." + ext
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pk-preview-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(file)
        guard (try? data.write(to: url)) != nil else { return }
        show(url)
    }

    nonisolated func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        MainActor.assumeIsolated { items.count }
    }
    nonisolated func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        MainActor.assumeIsolated { items[index] as NSURL }
    }

    static func topController() -> UIViewController? {
        let win = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        var top = win?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}

/// Descargas del chat (botón de descargar archivo): se guardan en temporal y se abren en la vista completa.
@MainActor
final class DownloadKeeper: NSObject, WKDownloadDelegate {
    static let shared = DownloadKeeper()
    private var dest: [ObjectIdentifier: URL] = [:]

    nonisolated func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pk-dl-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(suggestedFilename.isEmpty ? "archivo" : suggestedFilename)
        await MainActor.run { dest[ObjectIdentifier(download)] = url }
        return url
    }
    nonisolated func downloadDidFinish(_ download: WKDownload) {
        Task { @MainActor in
            if let url = dest.removeValue(forKey: ObjectIdentifier(download)) { FilePreviewer.shared.show(url) }
        }
    }
    nonisolated func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        Task { @MainActor in _ = dest.removeValue(forKey: ObjectIdentifier(download)) }
    }
}
