import SwiftUI
import UIKit

/// Conversación nueva con Marisol (tapa la página del proyecto de claude.ai).
/// Lo que escribís aquí se manda por la caja de escribir de claude.ai, y al mandarlo claude.ai abre la conversación.
/// 0.3.23: después de mandar, esta vista se queda encima (tu burbuja + puntitos) hasta que Marisol termina su
/// primera respuesta; ahí Pockit carga el chat limpio, así no se ve el layout roto de claude.ai ni se traba el scroll.
struct NewChatView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        let t = settings.t
        VStack(spacing: 0) {
            if let sent = web.pendingFirstMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Spacer(minLength: 12)
                        HStack {
                            Spacer(minLength: 60)
                            Text(sent)
                                .font(Theme.text(16))
                                .foregroundStyle(Theme.nightDeep)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20).fill(Theme.switchPink))
                        }
                        TypingBubble()
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.bottom)
            } else {
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
                .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                Spacer()
            }

            BubbleComposer(text: $text, sending: sending || web.pendingFirstMessage != nil, onSend: send)
        }
        .background(Theme.night)
        .onChange(of: web.sendProblem) { _, problem in
            if problem != nil { sending = false; web.cancelPendingNewChat() }
        }
    }

    private func send() {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, !sending, web.pendingFirstMessage == nil else { return }
        sending = true
        text = ""
        web.startNewChat(msg)
        // Si a los 12 s claude.ai no abrió la conversación, se puede reintentar.
        Task {
            try? await Task.sleep(for: .seconds(12))
            if web.isNewChat {
                sending = false
                if let pending = web.pendingFirstMessage { text = pending }
                web.cancelPendingNewChat()
            }
        }
    }
}

/// Burbuja de "escribiendo…" de Marisol (tres puntitos que saltan).
private struct TypingBubble: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.lilac)
                    .frame(width: 8, height: 8)
                    .opacity(phase % 3 == i ? 1 : 0.35)
                    .offset(y: phase % 3 == i ? -3 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20).fill(Theme.panel))
        .onReceive(timer) { _ in phase += 1 }
    }
}
