import SwiftUI

/// Ícono de una sección: uno de nuestros íconos (en el estilo elegido) o un símbolo mientras se diseña el suyo.
enum SegIcon {
    case tab(PockitTab)
    case symbol(String)
}

/// Selector de secciones con el ícono arriba de la palabra (Progress y Portfolio).
struct IconSegments<T: Hashable>: View {
    let items: [(value: T, title: String, icon: SegIcon)]
    @Binding var selection: T
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.value) { item in
                let active = selection == item.value
                Button {
                    if !active { UISelectionFeedbackGenerator().selectionChanged() }
                    withAnimation(.easeOut(duration: 0.2)) { selection = item.value }
                } label: {
                    VStack(spacing: 4) {
                        icon(item.icon, active: active).frame(width: 34, height: 34)
                        Text(item.title)
                            .font(Theme.text(12, active ? .semibold : .regular, relativeTo: .caption))
                            .foregroundStyle(active ? Theme.switchPink : Theme.lilac)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(active ? Theme.switchPink.opacity(0.16) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(active ? Theme.switchPink.opacity(0.55) : Color.clear, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.nightDeep.opacity(0.55)))
    }

    @ViewBuilder private func icon(_ i: SegIcon, active: Bool) -> some View {
        switch i {
        case .tab(let tab):
            TabItemView(tab: tab, active: active, style: settings.tabIconStyle, title: "")
                .frame(width: 40, height: 40)
                .scaleEffect(0.85)
                .clipped()
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(active ? Theme.switchPink : .white.opacity(0.85))
        }
    }
}

/// Barra de arriba que se oscurece poco a poco al bajar. Arriba del todo es del mismo color que el fondo.
/// Con `largeTitle`, el título grande va dentro del contenido (LargeTitleRow) y se difumina al subir,
/// mientras el título chiquito aparece poco a poco en la barra (nada de títulos cortados).
struct FadingNavBar: ViewModifier {
    var title: String? = nil
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    g.contentOffset.y + g.contentInsets.top
                } action: { _, y in
                    // y = 0 es arriba del todo (el rebote hacia abajo da negativo y se ignora).
                    progress = min(max(y / 90, 0), 1)
                }
                .environment(\.navFade, progress)
                // La barra del sistema queda siempre transparente (si le pasamos un color transparente, iOS pone
                // su barra gris por defecto). El fondo que se oscurece lo dibujamos nosotros, debajo de los títulos.
                .toolbarBackground(.hidden, for: .navigationBar)
                .overlay(alignment: .top) { NavFadeBackground(progress: progress) }
                .modifier(InlineFadingTitle(title: title, progress: progress))
        } else {
            if let title { content.navigationTitle(title) } else { content }
        }
    }
}

private struct NavFadeBackground: View {
    let progress: CGFloat
    var body: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                Rectangle().fill(Theme.nightDeep.opacity(0.88 * progress))
                    .frame(height: g.safeAreaInsets.top)
                Rectangle().fill(Color.white.opacity(0.12 * progress))
                    .frame(height: 0.5)
                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct InlineFadingTitle: ViewModifier {
    let title: String?
    let progress: CGFloat
    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title.uppercased())
                            .font(Theme.display(22))
                            .foregroundStyle(.white)
                            .opacity(Double(min(max((progress - 0.35) / 0.5, 0), 1)))
                            .offset(y: (1 - min(max((progress - 0.35) / 0.5, 0), 1)) * 6)
                    }
                }
        } else {
            content
        }
    }
}

/// Título grande dentro de la lista: se desvanece (y se encoge un pelín) a medida que sube hacia la barra.
struct LargeTitleRow: View {
    let text: String
    @Environment(\.navFade) private var navFade

    var body: some View {
        if #available(iOS 18.0, *) {
            // navFade va de 0 a 1 en 90 pt de scroll; el título grande se va en los primeros ~40 pt.
            let fade = 1 - min(max(navFade * 90 / 40, 0), 1)
            DisplayTitle(text: text, size: 36)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(Double(fade))
                .scaleEffect(0.94 + 0.06 * fade, anchor: .leading)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        }
    }
}

private struct NavFadeKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var navFade: CGFloat {
        get { self[NavFadeKey.self] }
        set { self[NavFadeKey.self] = newValue }
    }
}

extension View {
    func fadingNavBar(title: String? = nil) -> some View { modifier(FadingNavBar(title: title)) }
}
