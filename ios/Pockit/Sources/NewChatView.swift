import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Conversación nueva con Marisol (tapa la página del proyecto de claude.ai).
/// Lo que escribís aquí se manda por la caja de escribir de claude.ai, y al mandarlo claude.ai abre la conversación.
struct NewChatView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @State private var text = ""
    @State private var sending = false
    @State private var attachments: [String] = []
    @State private var attachError: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showFiles = false
    @FocusState private var focused: Bool

    var body: some View {
        let t = settings.t
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.switchPink)
                Text(t.s("Conversación nueva con Marisol", "New chat with Marisol"))
                    .font(Theme.text(20, .semibold))
                    .foregroundStyle(.white)
                Text(t.s("Tus conversaciones viejas están en ☰ arriba a la izquierda.", "Your old chats are under ☰ at the top left."))
                    .font(Theme.text(13))
                    .foregroundStyle(Theme.lilac)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .onTapGesture { focused = false }
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                if !attachments.isEmpty || attachError != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(attachments, id: \.self) { name in
                                Label(name, systemImage: "paperclip")
                                    .font(Theme.text(12, .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.purple))
                            }
                            if let attachError {
                                Text(attachError).font(Theme.text(12)).foregroundStyle(Theme.coral)
                            }
                        }
                    }
                }

                // Caja de escribir estilo iMessage.
                HStack(alignment: .bottom, spacing: 6) {
                    TextField(t.s("Mensaje pa' Marisol", "Message Marisol"), text: $text, axis: .vertical)
                        .lineLimit(1...6)
                        .font(Theme.text(17))
                        .foregroundStyle(.white)
                        .tint(Theme.switchPink)
                        .focused($focused)
                        .padding(.vertical, 9)
                    Button(action: send) {
                        Image(systemName: sending ? "ellipsis" : "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.nightDeep)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(canSend ? Theme.switchPink : Theme.lilac.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .padding(.bottom, 4)
                    .accessibilityLabel(t.s("Enviar", "Send"))
                }
                .padding(.leading, 16)
                .padding(.trailing, 5)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.nightDeep.opacity(0.85)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))

                // "+" debajo, como en el chat (adjuntar foto o archivo).
                Menu {
                    Button { showPhotos = true } label: { Label(t.s("Foto", "Photo"), systemImage: "photo") }
                    Button { showFiles = true } label: { Label(t.s("Archivo", "File"), systemImage: "doc") }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 36)
                }
                .accessibilityLabel(t.s("Adjuntar", "Attach"))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Theme.night)
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
        .onChange(of: web.currentPath) { _, _ in
            if !web.isNewChat { sending = false; text = ""; attachments = []; attachError = nil }
        }
        .onChange(of: web.sendProblem) { _, problem in if problem != nil { sending = false } }
    }

    private var canSend: Bool { !sending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send() {
        guard canSend else { return }
        sending = true
        focused = false
        web.send(text.trimmingCharacters(in: .whitespacesAndNewlines))
        // Si a los 12 s claude.ai no abrió la conversación, se puede reintentar.
        Task {
            try? await Task.sleep(for: .seconds(12))
            if web.isNewChat { sending = false }
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
