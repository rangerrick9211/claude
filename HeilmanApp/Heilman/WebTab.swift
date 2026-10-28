import Combine
import SwiftUI
import WebKit

/// Holds the three tabs. Their web views stay alive while you switch, so nothing reloads.
@MainActor
final class TabStore: ObservableObject {
    @Published var selection: Destination {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: "selection")
            tab(selection).loadIfNeeded()
        }
    }

    private let tabs: [Destination: WebTab]

    init() {
        selection = UserDefaults.standard.string(forKey: "selection").flatMap(Destination.init(rawValue:)) ?? .basecamp
        tabs = Dictionary(uniqueKeysWithValues: Destination.allCases.map { ($0, WebTab(destination: $0)) })
        for tab in tabs.values {
            tab.openDestination = { [weak self] destination in self?.selection = destination }
            tab.didReturnHome = { [weak self, weak tab] in
                guard let self else { return }
                for other in self.tabs.values where other !== tab && other.hasStarted {
                    other.refreshAfterSignIn()
                }
            }
        }
    }

    var current: WebTab { tab(selection) }

    func tab(_ destination: Destination) -> WebTab { tabs[destination]! }

    func start() {
        current.loadIfNeeded()
        // Load the other two a moment later, so the first switch to them is instant.
        Task {
            try? await Task.sleep(for: .seconds(2))
            for destination in Destination.allCases { tab(destination).loadIfNeeded() }
        }
    }

    /// Clears the claude.ai sign-in and everything else the web views have stored.
    func signOut() async {
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
        for tab in tabs.values where tab.hasStarted { tab.goHome() }
    }
}

/// A sign-in window a page opened (Google's, for example), shown as a sheet.
struct Popup: Identifiable {
    let id = UUID()
    let webView: WKWebView
}

/// One tab: a web view showing a claude.ai artifact page, and what it's doing.
@MainActor
final class WebTab: NSObject, ObservableObject {
    let destination: Destination
    let webView: WKWebView

    @Published private(set) var progress = 0.0
    @Published private(set) var isLoading = false
    @Published private(set) var failure: String?
    @Published private(set) var showingOfflineCopy = false
    @Published var popup: Popup?

    private(set) var hasStarted = false
    private var lastReturnHome: Date?
    private var wasAway = false
    private var urlWatch: AnyCancellable?
    var openDestination: ((Destination) -> Void)?
    /// Called when this tab gets back to its page after signing in, so the other tabs can catch up.
    var didReturnHome: (() -> Void)?

    init(destination: Destination) {
        self.destination = destination
        let configuration = WKWebViewConfiguration()
        // One shared store, so signing in on one tab signs in all three, and it lasts between launches.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.applicationNameForUserAgent = Self.safariUserAgentSuffix
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        // Lets Safari's Web Inspector on the Mac look inside the app (Develop menu), for debugging.
        webView.isInspectable = true
        webView.publisher(for: \.estimatedProgress).assign(to: &$progress)
        webView.publisher(for: \.isLoading).assign(to: &$isLoading)
        urlWatch = webView.publisher(for: \.url).sink { [weak self] url in
            if let url { self?.urlChanged(url) }
        }
    }

    /// WKWebView leaves "Version/… Safari/…" off its user agent, and Google won't sign in a page it
    /// thinks is embedded in an app. Adding them back makes the agent read like Safari on this phone.
    private static var safariUserAgentSuffix: String {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return "Version/\(major).0 Mobile/15E148 Safari/604.1"
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        goHome()
    }

    func goHome() {
        failure = nil
        showingOfflineCopy = false
        webView.load(URLRequest(url: destination.url))
    }

    /// Opens a claude.ai link copied from elsewhere, like the sign-in link claude.ai emails you.
    func open(_ url: URL) {
        failure = nil
        showingOfflineCopy = false
        webView.load(URLRequest(url: url))
    }

    func reload() {
        if failure != nil || showingOfflineCopy || webView.url == nil {
            goHome()
        } else {
            webView.reload()
        }
    }

    /// Reloads this tab's page after another tab signed in, without passing the news on again.
    func refreshAfterSignIn() {
        wasAway = false
        goHome()
    }

    /// claude.ai lands on a chat after you sign in. Sends the tab back to its own page, unless it
    /// just did that (claude.ai redirecting in a loop), in which case it returns false and stays put.
    private func returnHome() -> Bool {
        if let last = lastReturnHome, Date.now.timeIntervalSince(last) < 15 { return false }
        lastReturnHome = .now
        Task { goHome() }
        return true
    }

    /// claude.ai changes pages inside its web app without a full load, and those changes skip the
    /// link rules below. This catches the after-sign-in landing anyway.
    private func urlChanged(_ url: URL) {
        guard Route(url) == .otherClaudePage, Route.isClaudeLanding(url) else { return }
        _ = returnHome()
    }

    private func openOutside(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func closePopup() {
        popup = nil
    }

    private func handle(_ error: Error, in webView: WKWebView) {
        guard webView === self.webView else { return }
        let error = error as NSError
        // A load replaced by another one, or stopped by the link rules below, isn't a failure.
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }
        if error.domain == "WebKitErrorDomain" && error.code == 102 { return } // frame load interrupted
        if let copy = destination.offlineCopy, !showingOfflineCopy {
            showingOfflineCopy = true
            webView.loadFileURL(copy, allowingReadAccessTo: copy.deletingLastPathComponent())
            return
        }
        failure = error.localizedDescription
    }
}

extension WebTab: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }

        // The artifact itself runs in a frame on claudeusercontent.com; claude.ai manages that frame.
        // A tapped link in it that leads off claude.ai still goes to Safari.
        if let frame = navigationAction.targetFrame, !frame.isMainFrame {
            if navigationAction.navigationType == .linkActivated && Route(url) != .stay {
                openOutside(url)
                return decisionHandler(.cancel)
            }
            return decisionHandler(.allow)
        }

        let isPopup = webView !== self.webView
        if let target = Destination(matching: url) {
            // This tab's own page (or claude.ai reloading it) loads here; another tab's page switches tabs.
            if target == destination && !isPopup { return decisionHandler(.allow) }
            if isPopup {
                // A sign-in window finishing on one of the pages: everything can reload signed in.
                closePopup()
                didReturnHome?()
            }
            if target == destination { Task { refreshAfterSignIn() } } else { openDestination?(target) }
            return decisionHandler(.cancel)
        }

        switch Route(url) {
        case .stay:
            decisionHandler(.allow)
        case .otherClaudePage where navigationAction.navigationType == .linkActivated:
            openOutside(url)
            if isPopup { closePopup() }
            decisionHandler(.cancel)
        case .otherClaudePage:
            // Sign-in steps can pass through claude.ai pages this app doesn't know; only the
            // chat it lands on afterwards sends the tab back to its own page.
            guard Route.isClaudeLanding(url), returnHome() else { return decisionHandler(.allow) }
            if isPopup { closePopup() }
            decisionHandler(.cancel)
        case .outside:
            openOutside(url)
            if isPopup { closePopup() }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === self.webView, let url = webView.url else { return }
        failure = nil
        if !url.isFileURL { showingOfflineCopy = false }
        // Back on this tab's page after a detour (the claude.ai sign-in): the other tabs can reload
        // signed in too.
        if Destination(matching: url) == destination {
            if wasAway {
                wasAway = false
                didReturnHome?()
            }
        } else if url.scheme?.hasPrefix("http") == true {
            wasAway = true
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error, in: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error, in: webView)
    }

    /// iOS drops web pages that sit in the background while memory is tight. Bring this one back.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView === self.webView { reload() }
    }
}

extension WebTab: WKUIDelegate {
    /// Links that open a new window (target="_blank", window.open).
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, !url.absoluteString.isEmpty, url.scheme != "about" {
            if let other = Destination(matching: url) {
                if other == destination { goHome() } else { openDestination?(other) }
                return nil
            }
            if Route(url) != .stay {
                openOutside(url)
                return nil
            }
        }
        // A sign-in window, or a blank one a script is about to fill. It has to be built from the
        // configuration WebKit passes in, so the page that opened it can talk to it.
        let child = WKWebView(frame: .zero, configuration: configuration)
        child.navigationDelegate = self
        child.uiDelegate = self
        child.isInspectable = true
        popup = Popup(webView: child)
        return child
    }

    /// A sign-in window closes itself when it's done.
    func webViewDidClose(_ webView: WKWebView) {
        guard webView === popup?.webView else { return }
        closePopup()
        didReturnHome?()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, over: webView, otherwise: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, over: webView, otherwise: { completionHandler(false) })
    }

    private func present(_ alert: UIAlertController, over webView: WKWebView, otherwise: () -> Void) {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard var top = (webView.window ?? keyWindow)?.rootViewController else { return otherwise() }
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        top.present(alert, animated: true)
        // WebKit throws if a panel's handler is never called, so answer for it if the alert didn't show.
        if alert.presentingViewController == nil { otherwise() }
    }
}
