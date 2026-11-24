import SwiftUI

/// Niveles de BuckMe con sus límites y beneficios (los que Jose pasó).
enum BuckmeTier: String, CaseIterable, Identifiable {
    case regular, silver, gold, premium
    var id: String { rawValue }

    var name: String { rawValue.capitalized }
    var asset: String { "Tier_" + rawValue }
    var personalLimit: Int {
        switch self { case .regular: return 15_000; case .silver: return 100_000; case .gold: return 500_000; case .premium: return 2_000_000 }
    }
    var familyLimit: Int {
        switch self { case .regular: return 5_000; case .silver: return 100_000; case .gold: return 500_000; case .premium: return 2_000_000 }
    }
    var totalLimit: Int { personalLimit + familyLimit }
    var color: Color {
        switch self {
        case .regular: return Color(red: 0.16, green: 0.78, blue: 0.50)
        case .silver: return Color(red: 0.80, green: 0.82, blue: 0.88)
        case .gold: return Color(red: 1.0, green: 0.78, blue: 0.22)
        case .premium: return Color(red: 0.86, green: 0.40, blue: 1.0)
        }
    }
    func perks(_ t: L10n) -> [String] {
        var p = [t.s("Cuenta personal: hasta ", "Personal account: up to ") + Fmt.money(personalLimit),
                 t.s("Family savings: hasta ", "Family savings: up to ") + Fmt.money(familyLimit)]
        switch self {
        case .regular: break
        case .silver: p.append(t.s("20% de descuento en RydeMe rides", "20% off RydeMe rides"))
        case .gold: p.append(t.s("20% de descuento en garage purchases", "20% off garage purchases"))
        case .premium: p.append(t.s("Descuento en liveries", "Discount on liveries"))
        }
        return p
    }
    static func from(_ raw: String) -> BuckmeTier { BuckmeTier(rawValue: raw) ?? .regular }
    static let stashLimit = 20_000
}

/// Ícono dentro de un anillo que se llena con el porcentaje (BuckMe y Stash).
struct ProgressRingIcon: View {
    let image: String
    let progress: Double
    let color: Color
    var size: CGFloat = 40
    var line: CGFloat = 3.5

    var body: some View {
        ZStack {
            Circle().fill(Theme.nightDeep.opacity(0.55))
            Circle().stroke(color.opacity(0.18), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: 3)
                .animation(.easeOut(duration: 0.6), value: progress)
            Image(image).resizable().scaledToFit().padding(size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

/// Barrita de una cuenta contra su límite.
struct LimitBar: View {
    let value: Int
    let limit: Int
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(color).frame(width: g.size.width * CGFloat(min(1, max(0, Double(value) / Double(max(limit, 1))))))
            }
        }
        .frame(height: 6)
    }
}
