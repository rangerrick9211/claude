import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ZStack {
                // All three pages stay in place; switching tabs only changes which one shows.
                ForEach(Destination.allCases) { destination in
                    let isShown = store.selection == destination
                    TabPage(tab: store.tab(destination))
                        .opacity(isShown ? 1 : 0)
                        .allowsHitTesting(isShown)
                        .accessibilityHidden(!isShown)
                }
            }
        }
        .background(store.selection.edgeColor.ignoresSafeArea())
        .task { store.start() }
    }
}

/// The tab switcher. It sits at the top because Basecamp and the Family App draw their own
/// tab bars at the bottom of the page.
private struct TopBar: View {
    @EnvironmentObject private var store: TabStore
    @State private var confirmingSignOut = false

    var body: some View {
        HStack(spacing: 12) {
            Picker("Page", selection: $store.selection) {
                ForEach(Destination.allCases) { destination in
                    Text(destination.title).tag(destination)
                }
            }
            .pickerStyle(.segmented)

            Button {
                store.current.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Reload")

            Menu {
                Button {
                    UIApplication.shared.open(store.selection.url)
                } label: {
                    Label("Open on claude.ai", systemImage: "safari")
                }
                Button {
                    if let url = copiedClaudeLink() { store.current.open(url) }
                } label: {
                    Label("Paste sign-in link", systemImage: "link")
                }
                Button(role: .destructive) {
                    confirmingSignOut = true
                } label: {
                    Label("Sign out of Claude", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
        .font(.system(size: 17, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color("Chrome").ignoresSafeArea(edges: .top))
        .confirmationDialog("Sign out of Claude in this app?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await store.signOut() }
            }
        } message: {
            Text("All three tabs go back to the claude.ai sign-in.")
        }
    }

    /// A claude.ai link on the clipboard. Tapping the emailed sign-in link opens Safari, so copy it
    /// in Mail instead (press and hold, Copy Link) and paste it here.
    private func copiedClaudeLink() -> URL? {
        let text = UIPasteboard.general.url?.absoluteString ?? UIPasteboard.general.string ?? ""
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host?.lowercased() == "claude.ai" else { return nil }
        return url
    }
}

private struct TabPage: View {
    @ObservedObject var tab: WebTab

    var body: some View {
        WebContainer(webView: tab.webView)
            .overlay(alignment: .top) {
                if tab.isLoading && tab.progress < 1 {
                    ProgressView(value: tab.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
            }
            .overlay {
                if let failure = tab.failure {
                    FailureCard(message: failure, retry: { tab.goHome() })
                }
            }
            .overlay(alignment: .bottom) {
                if tab.showingOfflineCopy {
                    OfflineBanner(retry: { tab.goHome() })
                }
            }
            .sheet(item: $tab.popup) { popup in
                PopupSheet(popup: popup) { tab.popup = nil }
            }
    }
}

private struct WebContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}

private struct FailureCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Can't reach Claude")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Chrome"))
    }
}

private struct OfflineBanner: View {
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Offline: showing the copy saved in the app.")
                .font(.footnote)
            Button("Try live", action: retry)
                .font(.footnote.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 12)
    }
}

/// A window a page opened, usually a sign-in page from Google.
private struct PopupSheet: View {
    let popup: Popup
    let close: () -> Void

    var body: some View {
        NavigationStack {
            WebContainer(webView: popup.webView)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: close)
                    }
                }
        }
    }
}
