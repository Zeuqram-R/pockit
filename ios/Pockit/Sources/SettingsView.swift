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
                    Toggle(t.skinToggle, isOn: Binding(
                        get: { skin.localEnabled },
                        set: { skin.localEnabled = $0 }))
                        .tint(Theme.switchPink)
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
                    LabeledContent(t.version, value: Self.versionString)
                        .menuRow()
                } header: {
                    SectionTitle(text: t.about)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
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
