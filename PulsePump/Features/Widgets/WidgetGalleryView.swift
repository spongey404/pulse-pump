import SwiftUI

// MARK: - Widget gallery
// Every fixed widget (Pump Widgets.dc.html) drawn at design scale in light / dark / tinted —
// the same views WidgetKit renders, so what you see here is what ships.

struct WidgetGalleryView: View {
    var onBack: (() -> Void)? = nil
    var section: String? = nil          // show a single section id (debug)
    @State private var theme: Theme = {
        #if DEBUG
        Theme(rawValue: UserDefaults.standard.string(forKey: "debugGalleryTheme") ?? "") ?? .light
        #else
        .light
        #endif
    }()

    enum Theme: String, CaseIterable, Identifiable {
        case light, dark, tinted
        var id: String { rawValue }
        var scheme: ColorScheme { self == .light ? .light : .dark }
        var wall: Color { self == .light ? Color(hex: "#D4DAE2") : Color(hex: "#0E0C0A") }
    }

    private var sections: [PWGallerySection] {
        let all = PWRegistry.sections
        guard let section else { return all }
        return all.filter { $0.id == section }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                MoreScreenHeader(title: "WIDGET GALLERY", onBack: onBack)
            }
            HStack(spacing: 6) {
                ForEach(Theme.allCases) { t in
                    Button { theme = t } label: {
                        Text(t.rawValue.uppercased()).font(.spaceMono(9, weight: .bold)).tracking(1)
                            .foregroundStyle(theme == t ? Color.canvasBg : Color.inkMuted)
                            .padding(.horizontal, 14).frame(height: 30)
                            .background(theme == t ? Color.inkPrimary : Color.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme == t ? Color.clear : Color.dsHairLine, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(sections) { sec in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text(sec.id).font(.spaceMono(11, weight: .bold))
                                Text(sec.tier).font(.spaceMono(8)).tracking(1.2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ruleStrong, lineWidth: 1))
                            }
                            Text(sec.name).font(.archivo(20, weight: .bold))
                            Text(sec.blurb).font(.archivo(13)).foregroundStyle(Color.inkMuted)
                            ForEach(sec.items) { item in tile(item) }
                        }
                        .padding(.horizontal, 16)
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.top, 8)
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        #if DEBUG
        .task { if UserDefaults.standard.bool(forKey: "debugGalleryDump") { dump() } }
        #endif
    }

    #if DEBUG
    /// `-debugGalleryDump 1`: renders each section × theme to a tall PNG in the app's tmp dir.
    @MainActor private func dump() {
        let dir = NSTemporaryDirectory()
        for sec in sections {
            for t in Theme.allCases {
                let col = VStack(alignment: .leading, spacing: 14) {
                    Text("\(sec.id) · \(sec.name) · \(t.rawValue.uppercased())").font(.spaceMono(11, weight: .bold))
                    ForEach(sec.items) { item in tileFor(item, t) }
                }
                .padding(16).frame(width: 390, alignment: .leading).background(Color.canvasBg)
                .environment(\.colorScheme, t.scheme)
                let r = ImageRenderer(content: col); r.scale = 2
                if let data = r.uiImage?.pngData() { try? data.write(to: URL(fileURLWithPath: dir + "gallery_\(sec.id)_\(t.rawValue).png")) }
            }
        }
        print("GALLERY_DUMP_DONE \(dir)")
    }
    #endif

    private func tileFor(_ item: PWGalleryItem, _ t: Theme) -> some View {
        let size = item.customSize ?? item.family.size
        let width: CGFloat = min(size.width, 310)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                (item.isLock ? Color(hex: "#3A424D") : t.wall)
                PWGalleryCanvas(item: item, theme: t, width: width).padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            Text(item.title).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
    }

    private func tile(_ item: PWGalleryItem) -> some View {
        let size = item.customSize ?? item.family.size
        let width: CGFloat = min(size.width, 310)
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                (item.isLock ? Color(hex: "#3A424D") : theme.wall)
                PWGalleryCanvas(item: item, theme: theme, width: width)
                    .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            Text(item.title).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
    }
}

private struct PWGalleryCanvas: View {
    let item: PWGalleryItem
    let theme: WidgetGalleryView.Theme
    let width: CGFloat

    var body: some View {
        let size = item.customSize ?? item.family.size
        let s = width / size.width
        let content = item.make(PumpWidgetSnapshot.sample)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(item.isLock ? Color.clear : PumpTheme.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .environment(\.colorScheme, item.isLock ? .dark : theme.scheme)
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: width, height: size.height * s, alignment: .topLeading)
        if theme == .tinted && !item.isLock {
            content.grayscale(1).brightness(0.08)
                .overlay(Color(hex: "#7FB8E6").blendMode(.color).allowsHitTesting(false))
                .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            content
        }
    }
}
