import WidgetKit
import SwiftUI

private let night = Color(red: 0x2B/255, green: 0x1E/255, blue: 0x92/255)
private let deep = Color(red: 0x1A/255, green: 0x10/255, blue: 0x66/255)
private let pink = Color(red: 0xCB/255, green: 0x84/255, blue: 0xF8/255)
private let hot = Color(red: 0xFF/255, green: 0x3E/255, blue: 0x8A/255)
private let lilac = Color(red: 0xE5/255, green: 0xD6/255, blue: 0xF2/255)

struct Entry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snap: WidgetSnapshot(pct: 17, mission: "Clear Skies", money: 12500, pendientes: ["Probar jet ski en Key Lento"])) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: Date(), snap: WidgetSnapshot.load() ?? placeholder(in: context).snap)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: Date(), snap: WidgetSnapshot.load())], policy: .after(Date().addingTimeInterval(3600))))
    }
}

private func es(_ s: WidgetSnapshot?) -> Bool { (s?.lang ?? "es") == "es" }
private func money(_ n: Int) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0; f.locale = Locale(identifier: "en_US")
    return "$" + (f.string(from: NSNumber(value: n)) ?? "\(n)")
}

struct Face: View {
    let mood: String
    var body: some View {
        let img = UIImage(named: "WFace_\(mood).jpg") ?? UIImage(named: "WFace_neutral.jpg")
        Image(uiImage: img ?? UIImage())
            .resizable().scaledToFill()
            .clipShape(Circle())
            .overlay(Circle().stroke(LinearGradient(colors: [hot, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
    }
}

struct Ring: View {
    let pct: Int
    var body: some View {
        ZStack {
            Circle().stroke(deep.opacity(0.8), lineWidth: 6)
            Circle().trim(from: 0, to: CGFloat(max(0, pct)) / 100)
                .stroke(pink, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            Text(pct >= 0 ? "\(pct)%" : "—").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
    }
}

struct SmallView: View {
    let snap: WidgetSnapshot?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Face(mood: snap?.mood ?? "neutral").frame(width: 40, height: 40)
                Spacer()
                Ring(pct: snap?.pct ?? -1).frame(width: 46, height: 46)
            }
            Spacer(minLength: 0)
            Text(es(snap) ? "ÚLTIMA MISIÓN" : "LAST MISSION").font(.system(size: 9, weight: .bold)).foregroundStyle(lilac.opacity(0.8))
            Text(snap?.mission.isEmpty == false ? snap!.mission : (es(snap) ? "Abrí Pockit" : "Open Pockit"))
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
            if let m = snap?.money { Text(money(m)).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(pink) }
        }
    }
}

struct MediumView: View {
    let snap: WidgetSnapshot?
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 8) {
                Face(mood: snap?.mood ?? "neutral").frame(width: 54, height: 54)
                Ring(pct: snap?.pct ?? -1).frame(width: 50, height: 50)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(snap?.mission.isEmpty == false ? snap!.mission : (es(snap) ? "Abrí Pockit pa' empezar" : "Open Pockit to start"))
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 10) {
                    if let m = snap?.money { Label(money(m), systemImage: "dollarsign.circle.fill") }
                    if let c = snap?.collectibles, c > 0 { Label("\(c)", systemImage: "star.circle.fill") }
                }
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(pink)
                Divider().overlay(Color.white.opacity(0.2))
                let items = Array((snap?.pendientes ?? []).prefix(3))
                if items.isEmpty {
                    Text(es(snap) ? "Sin pendientes 🌴" : "Nothing pending 🌴").font(.system(size: 12)).foregroundStyle(lilac)
                } else {
                    ForEach(items, id: \.self) { p in
                        HStack(alignment: .top, spacing: 5) {
                            Circle().fill(hot).frame(width: 5, height: 5).padding(.top, 5)
                            Text(p).font(.system(size: 12)).foregroundStyle(lilac).lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct PockitWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry
    var body: some View {
        Group {
            if family == .systemSmall { SmallView(snap: entry.snap) } else { MediumView(snap: entry.snap) }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0x82/255, green: 0x48/255, blue: 0xE3/255), night, deep], startPoint: .topTrailing, endPoint: .bottomLeading)
        }
        .widgetURL(URL(string: "pockit://marisol"))
    }
}

struct PockitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PockitWidget", provider: Provider()) { PockitWidgetView(entry: $0) }
            .configurationDisplayName("Pockit")
            .description("Tu progreso, tu plata y lo pendiente en Leonida.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PockitWidgets: WidgetBundle {
    var body: some Widget { PockitWidget() }
}
