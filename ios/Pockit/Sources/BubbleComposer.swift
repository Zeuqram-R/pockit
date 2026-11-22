import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// Caja de escribir estilo iMessage: tu burbuja rosa a la derecha, al lado del botón de enviar,
/// que crece hacia la izquierda mientras escribís y baja de renglón cuando se llena. El "+" va debajo.
struct BubbleComposer: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @Binding var text: String
    var sending: Bool
    let onSend: () -> Void

    @State private var available: CGFloat = 300
    @State private var attachments: [String] = []
    @State private var attachError: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showFiles = false
    @FocusState private var focused: Bool

    private static let font = UIFont(name: Theme.TextWeight.regular.rawValue, size: 17) ?? .systemFont(ofSize: 17)

    var body: some View {
        let t = settings.t
        VStack(alignment: .leading, spacing: 6) {
            if !attachments.isEmpty || attachError != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachments, id: \.self) { name in
                            Label(name, systemImage: "paperclip")
                                .font(Theme.text(12, .medium)).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(Theme.purple))
                        }
                        if let attachError { Text(attachError).font(Theme.text(12)).foregroundStyle(Theme.coral) }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 0)
                TextField("", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .font(Theme.text(17))
                    .foregroundStyle(Theme.nightDeep)
                    .tint(Theme.nightDeep)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(width: bubbleWidth)
                    .background(BubbleShape().fill(Theme.switchPink))
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }
                    .accessibilityLabel(t.s("Mensaje pa' Marisol", "Message to Marisol"))
                    .animation(.easeOut(duration: 0.12), value: bubbleWidth)

                sendOrStop(t)
            }
            .background(GeometryReader { g in Color.clear.onAppear { available = g.size.width }.onChange(of: g.size.width) { _, w in available = w } })

            Menu {
                Button { showPhotos = true } label: { Label(t.s("Foto", "Photo"), systemImage: "photo") }
                Button { showFiles = true } label: { Label(t.s("Archivo", "File"), systemImage: "doc") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 34)
            }
            .accessibilityLabel(t.s("Adjuntar", "Attach"))
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { attachFile(url) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await attach(data, name: "foto-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg")
                }
                photoItem = nil
            }
        }
        .onChange(of: sending) { _, now in if !now && text.isEmpty { attachments = []; attachError = nil } }
    }

    /// Ancho de la burbuja: lo que mide el renglón más largo, hasta el máximo (luego baja de renglón).
    private var bubbleWidth: CGFloat {
        let maxW = max(120, available - 52)
        let longest = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { (String($0) as NSString).size(withAttributes: [.font: Self.font]).width }
            .max() ?? 0
        // Padding (28) + margen pa' el cursor y el redondeo de la letra (18): así la palabra no salta de renglón.
        return min(max(ceil(longest) + 46, 64), maxW)
    }

    @ViewBuilder private func sendOrStop(_ t: L10n) -> some View {
        if web.isStreaming {
            Button { web.stopReply() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.nightDeep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t.s("Detener a Marisol", "Stop Marisol"))
        } else {
            let can = !sending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button {
                guard can else { return }
                focused = false
                onSend()
            } label: {
                Image(systemName: sending ? "ellipsis" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.nightDeep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(can ? Color.white : Theme.lilac.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .disabled(!can)
            .accessibilityLabel(t.s("Enviar", "Send"))
        }
    }

    private func attachFile(_ url: URL) {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { attachError = settings.t.s("No pude leer el archivo.", "Couldn't read the file."); return }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        Task { await attach(data, name: url.lastPathComponent, mime: mime) }
    }

    private func attach(_ data: Data, name: String, mime: String) async {
        let r = await web.attach(data: data, name: name, mime: mime)
        if r == "ok" { attachments.append(name); attachError = nil }
        else { attachError = settings.t.s("No se pudo adjuntar (\(r)).", "Couldn't attach (\(r)).") }
    }
}

/// Burbuja con la colita abajo a la derecha (como tus mensajes).
struct BubbleShape: Shape {
    func path(in r: CGRect) -> Path {
        Path(roundedRect: r, cornerRadii: RectangleCornerRadii(topLeading: 20, bottomLeading: 20, bottomTrailing: 6, topTrailing: 20), style: .continuous)
    }
}

/// Caja nativa encima de la conversación (la de claude.ai queda invisible).
struct ChatComposerBar: View {
    @EnvironmentObject private var web: WebModel
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        BubbleComposer(text: $text, sending: sending) {
            let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
            sending = true
            text = ""
            web.send(msg)
            Task { try? await Task.sleep(for: .seconds(2)); sending = false }
        }
        .background(LinearGradient(colors: [Theme.night.opacity(0), Theme.night.opacity(0.92), Theme.night], startPoint: .top, endPoint: .bottom).padding(.top, -14))
    }
}
