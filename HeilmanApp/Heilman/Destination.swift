import SwiftUI

/// The three pages behind the tabs. Each one is a live Claude artifact, so the app shows the same
/// data as claude.ai, and Claude's routines keep updating it.
enum Destination: String, CaseIterable, Identifiable {
    case basecamp, family, almanac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basecamp: "Basecamp"
        case .family: "Family"
        case .almanac: "Almanac"
        }
    }

    var url: URL {
        switch self {
        case .basecamp: URL(string: "https://claude.ai/artifact/RAnDhxPeuq9rXSrM6mLak6")!
        case .family: URL(string: "https://claude.ai/artifact/WZQrttc8LVtAQuwCTs2CAN")!
        case .almanac: URL(string: "https://claude.ai/artifact/GLqU8sjSXuLRpCQocqxgK4")!
        }
    }

    /// A copy built into the app, shown when the live page can't load. Only the Almanac has one:
    /// it's a static page, while Basecamp and Family need Claude for their data.
    /// The file is optional and kept out of git (see README).
    var offlineCopy: URL? {
        switch self {
        case .almanac: Bundle.main.url(forResource: "almanac", withExtension: "html")
        default: nil
        }
    }

    /// Fills the strip behind the home indicator so it matches the bottom of each page.
    var edgeColor: Color {
        switch self {
        case .basecamp: Color(hex: 0xFBF8F2)
        case .family: Color(hex: 0xF7F4ED)
        case .almanac: Color(hex: 0xF1ECE3)
        }
    }

    /// The tab a claude.ai link points at, so a link from one page to another switches tabs.
    init?(matching url: URL) {
        guard let match = Self.allCases.first(where: { $0.url.host == url.host && $0.url.path == url.path }) else {
            return nil
        }
        self = match
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
