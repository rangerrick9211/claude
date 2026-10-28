import Foundation

/// Where a link should open: in the app, or handed to Safari and other apps.
enum Route: Equatable {
    /// Artifact pages, claude.ai sign-in, and the sign-in providers it sends you through.
    case stay
    /// Any other claude.ai page. A tap opens it in the Claude app. Landing on a chat after
    /// sign-in sends the tab back to its own page (see `isClaudeLanding`); anything else loads.
    case otherClaudePage
    /// Everything else: Strava, Walmart, Etsy, mail and phone links.
    case outside

    init(_ url: URL) {
        switch url.scheme?.lowercased() ?? "" {
        case "about", "blob", "data", "file":
            self = .stay
            return
        case "http", "https":
            break
        default:
            self = .outside
            return
        }
        let host = url.host?.lowercased() ?? ""
        if host == "claude.ai" || host.hasSuffix(".claude.ai") {
            let path = url.path.lowercased()
            let inApp = Self.claudePaths.contains { path == $0 || path.hasPrefix($0 + "/") }
            self = inApp ? .stay : .otherClaudePage
        } else if Self.signInHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            self = .stay
        } else {
            self = .outside
        }
    }

    /// The claude.ai pages it drops you on after sign-in: home, a new chat, recents, a chat, a project.
    static func isClaudeLanding(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return ["", "/", "/new", "/recents"].contains(path) || path.hasPrefix("/chat/") || path.hasPrefix("/project/")
    }

    private static let claudePaths = [
        "/artifact", "/code/artifact",
        "/login", "/logout", "/magic-link", "/auth", "/oauth", "/sso", "/onboarding", "/verify",
        "/api", "/cdn-cgi",
    ]

    private static let signInHosts = [
        "claudeusercontent.com",
        "accounts.google.com", "accounts.youtube.com", "gds.google.com",
        "appleid.apple.com", "idmsa.apple.com",
        "challenges.cloudflare.com",
    ]
}
