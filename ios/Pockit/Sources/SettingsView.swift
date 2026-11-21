import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @Environment(\.dismiss) private var dismiss
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
                } header: {
                    Text(t.language)
                } footer: {
                    Text(t.languageFooter)
                }

                Section {
                    HStack(spacing: 20) {
                        iconOption(.pin, title: t.iconPin)
                        iconOption(.marisol, title: t.iconMarisol)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                } header: {
                    Text(t.icon)
                } footer: {
                    Text(t.iconFooter)
                }

                Section {
                    Button {
                        let text = UIPasteboard.general.string ?? ""
                        if web.openSignInLink(text) { dismiss() } else { linkError = true }
                    } label: {
                        Label(t.pasteLink, systemImage: "link")
                    }
                    Button {
                        web.loadHome(); dismiss()
                    } label: {
                        Label(t.goHome, systemImage: "house")
                    }
                    Button {
                        web.reload(); dismiss()
                    } label: {
                        Label(t.reload, systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        confirmSignOut = true
                    } label: {
                        Label(t.signOut, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text(t.session)
                } footer: {
                    Text(t.pasteLinkFooter)
                }

                Section(t.about) {
                    LabeledContent(t.version, value: Self.versionString)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.night)
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
        .presentationBackground(Theme.night)
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
                            .stroke(selected ? Theme.pink : Color.clear, lineWidth: 3)
                            .padding(-4))
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(selected ? Theme.cream : Theme.lilac)
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
