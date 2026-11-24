import UIKit
import QuickLook
import WebKit

/// Abre fotos y archivos del chat en pantalla completa (vista nativa de iOS, con botón de compartir/guardar).
@MainActor
final class FilePreviewer: NSObject, QLPreviewControllerDataSource {
    static let shared = FilePreviewer()
    private var items: [URL] = []

    func show(_ url: URL) {
        items = [url]
        let ql = QLPreviewController()
        ql.dataSource = self
        ql.modalPresentationStyle = .fullScreen
        guard let top = Self.topController() else { return }
        top.present(ql, animated: true)
    }

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
