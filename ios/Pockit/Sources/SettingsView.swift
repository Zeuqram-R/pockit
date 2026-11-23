import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var skin: SkinManager
    @Environment(\.dismiss) private var dismiss
    @State private var diagnoseDone = false
    @State private var confirmSignOut = false
    @State private var linkError = false

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    Picker(t.language, selection: Binding(
                        get: { settings.language },
                        set: { settings.language = $0 })) {
                        ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .menuRow()
                } header: {
                    SectionTitle(text: t.language)
                } footer: {
                    Text(t.languageFooter).font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }

                Section {
                    HStack(spacing: 20) {
                        iconOption(.pin, title: t.iconPin)
                        iconOption(.marisol, title: t.iconMarisol)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .menuRow()
                } header: {
                    SectionTitle(text: t.icon)
                } footer: {
                    Text(t.iconFooter).font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }

                Section {
                    HStack(spacing: 16) {
                        tabStyleOption(.color, t)
                        tabStyleOption(.game, t)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .menuRow()
                } header: {
                    SectionTitle(text: t.s("Íconos de pestañas", "Tab icons"))
                } footer: {
                    Text(t.s("Cambia los íconos de la barra de abajo. Marisol sale con su cara en los dos.", "Changes the icons in the bottom bar. Marisol keeps her face in both.")).font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }

                Section {
                    Toggle(t.skinToggle, isOn: Binding(
                        get: { skin.localEnabled },
                        set: { skin.localEnabled = $0 }))
                        .tint(Theme.switchPink)
                        .menuRow()
                    Toggle(t.s("Chat estilo iMessage", "iMessage-style chat"), isOn: Binding(
                        get: { skin.chatLocalEnabled },
                        set: { skin.chatLocalEnabled = $0 }))
                        .tint(Theme.switchPink)
                        .disabled(!skin.localEnabled)
                        .menuRow()
                    if skin.remoteSaysOff {
                        Label(t.skinRemoteOff, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.sunset)
                            .menuRow()
                    }
                    LabeledContent(t.skinStatus, value: skin.lastStatus.isEmpty ? "…" : skin.lastStatus)
                        .menuRow()
                    Button {
                        Task {
                            UIPasteboard.general.string = await web.diagnose()
                            diagnoseDone = true
                        }
                    } label: {
                        Label(t.diagnose, systemImage: "stethoscope")
                    }
                    .menuRow()
                } header: {
                    SectionTitle(text: t.skin)
                } footer: {
                    Text(t.skinFooter).font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }

                Section {
                    Button {
                        let text = UIPasteboard.general.string ?? ""
                        if web.openSignInLink(text) { dismiss() } else { linkError = true }
                    } label: {
                        Label(t.pasteLink, systemImage: "link")
                    }
                    .menuRow()
                    Button {
                        web.loadHome(); dismiss()
                    } label: {
                        Label(t.goHome, systemImage: "house")
                    }
                    .menuRow()
                    Button {
                        web.reload(); dismiss()
                    } label: {
                        Label(t.reload, systemImage: "arrow.clockwise")
                    }
                    .menuRow()
                    Button(role: .destructive) {
                        confirmSignOut = true
                    } label: {
                        Label(t.signOut, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .menuRow()
                } header: {
                    SectionTitle(text: t.session)
                } footer: {
                    Text(t.pasteLinkFooter).font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }

                Section {
                    Button {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    } label: {
                        Label(t.s("Permitir pegar sin preguntar", "Allow pasting without asking"), systemImage: "doc.on.clipboard")
                    }
                    .menuRow()
                } header: {
                    SectionTitle(text: t.s("PEGAR", "PASTE"))
                } footer: {
                    Text(t.s("iOS no deja que una app cambie esto sola. Te abre los ajustes de Pockit: tocá \"Pegar de otras apps\" y elegí \"Permitir\". Así no vuelve a salir la confirmación.",
                             "iOS doesn't let an app change this itself. This opens Pockit's settings: tap \"Paste from Other Apps\" and choose \"Allow\". The prompt won't show again."))
                        .font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }

                SyncSection()
                    .environmentObject(settings)

                Section {
                    LabeledContent(t.version, value: Self.versionString)
                        .menuRow()
                    Link(destination: URL(string: "https://www.gtabase.com/gta-6/map/")!) {
                        LabeledContent(t.s("Mapa", "Map"), value: "GTABase.com")
                    }
                    .menuRow()
                } header: {
                    SectionTitle(text: t.about)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .fadingNavBar()
            .navigationTitle(t.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.done) { dismiss() }
                }
            }
            .alert(t.iconFailed, isPresented: Binding(
                get: { settings.iconError != nil },
                set: { if !$0 { settings.iconError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(settings.iconError ?? "")
            }
            .alert(t.diagnoseCopied, isPresented: $diagnoseDone) {
                Button("OK", role: .cancel) {}
            }
            .alert(t.pasteLinkInvalid, isPresented: $linkError) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog(t.signOutConfirm, isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button(t.signOut, role: .destructive) {
                    Task { await web.clearSession(); dismiss() }
                }
                Button(t.cancel, role: .cancel) {}
            }
        }
        .presentationBackground(Theme.nightDeep)
    }

    private func tabStyleOption(_ style: TabIconStyle, _ t: L10n) -> some View {
        let selected = settings.tabIconStyle == style
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            settings.tabIconStyle = style
        } label: {
            VStack(spacing: 8) {
                TabStylePreview(style: style)
                    .overlay(Capsule().stroke(selected ? Theme.switchPink : Color.clear, lineWidth: 3).padding(-4))
                Text(style.title(t))
                    .font(Theme.text(13, selected ? .semibold : .regular, relativeTo: .footnote))
                    .foregroundStyle(selected ? Color.white : Theme.lilac)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func iconOption(_ choice: AppIconChoice, title: String) -> some View {
        let selected = settings.currentIcon == choice
        return Button {
            settings.setIcon(choice)
        } label: {
            VStack(spacing: 8) {
                Image(choice.preview)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(selected ? Theme.switchPink : Color.clear, lineWidth: 3)
                            .padding(-4))
                Text(title)
                    .font(Theme.text(13, selected ? .semibold : .regular, relativeTo: .footnote))
                    .foregroundStyle(selected ? Color.white : Theme.lilac)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}


/// Ajustes → Sincronizar (iPhone, iPad y Mac con pockit-datos).
struct SyncSection: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var sync = SyncManager.shared
    @State private var editing = false
    @State private var token = ""

    var body: some View {
        let t = settings.t
        Section {
            if sync.hasToken {
                HStack {
                    Label(statusText(t), systemImage: statusIcon).foregroundStyle(.white)
                    Spacer()
                    if case .syncing = sync.status { ProgressView().tint(.white) }
                }
                .menuRow()
                Button { Task { await sync.sync() } } label: { Label(t.s("Sincronizar ahora", "Sync now"), systemImage: "arrow.triangle.2.circlepath") }
                    .menuRow()
                Button(role: .destructive) { sync.setToken(nil) } label: { Label(t.s("Quitar token de este dispositivo", "Remove token from this device"), systemImage: "key.slash") }
                    .menuRow()
            } else {
                // Se abre como página (no como ventana encima): las ventanas dentro de la lista se cerraban solas.
                NavigationLink {
                    TokenSheet(token: $token) { sync.setToken(token); editing = false } cancel: { editing = false }
                        .environmentObject(settings)
                } label: { Label(t.s("Conectar con pockit-datos", "Connect to pockit-datos"), systemImage: "key.fill") }
                    .menuRow()
            }
        } header: {
            SectionTitle(text: t.s("SINCRONIZAR", "SYNC"))
        } footer: {
            Text(t.s("Pasa tu tracker, pines y lugares entre iPhone, iPad y Mac por tu repo privado pockit-datos. El token se guarda solo en el llavero de este dispositivo. Usá un token fine-grained con permiso Contents: Read and write solo para pockit-datos.",
                     "Moves your tracker, pins and places between iPhone, iPad and Mac through your private pockit-datos repo. The token stays in this device's keychain. Use a fine-grained token with Contents: Read and write for pockit-datos only."))
                .font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
        }
    }

    private var statusIcon: String {
        switch sync.status {
        case .error: return "exclamationmark.triangle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        default: return "checkmark.icloud.fill"
        }
    }

    private func statusText(_ t: L10n) -> String {
        switch sync.status {
        case .off: return t.s("Apagado", "Off")
        case .idle: return t.s("Conectado", "Connected")
        case .syncing: return t.s("Sincronizando…", "Syncing…")
        case .ok(let d): return t.s("Al día · ", "Up to date · ") + Fmt.relative(d, lang: settings.language)
        case .error(let e): return e
        }
    }
}


/// Pegar el token de GitHub (hoja en vez de alerta: la alerta se cerraba al tocar el campo).
struct TokenSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Binding var token: String
    let save: () -> Void
    let cancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let t = settings.t
        VStack(alignment: .leading, spacing: 16) {
                Text(t.s("Pegalo aquí, no en el chat. Se guarda solo en el llavero de este dispositivo.",
                         "Paste it here, not in the chat. It's stored only in this device's keychain."))
                    .font(Theme.text(14)).foregroundStyle(Theme.lilac)
                SecureField("github_pat_…", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
                    .foregroundStyle(.white)
                PasteButton(payloadType: String.self) { items in
                    if let s = items.first { token = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                .tint(Theme.purple)
                .labelStyle(.titleAndIcon)
                if !token.isEmpty {
                    Text(t.s("Token listo (\(token.count) caracteres)", "Token ready (\(token.count) characters)"))
                        .font(Theme.text(13)).foregroundStyle(Theme.teal)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("Token de GitHub", "GitHub token"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(t.s("Guardar", "Save")) { save(); dismiss() }.disabled(token.isEmpty) }
            }
    }
}
