import AppKit
@testable import CmuxNextBrowser
import Foundation
import Testing

/// Extension popup windows (user 2026-11-17, Bitwarden's passkey popout): `chrome.windows.create({type:
/// "popup"})` has no opener, so cmux shows the window over the last shown pane. That pane was often a
/// cmux page (Home, an agent chat, New Tab) in Chromium: such a page lets no popup open (it closes the
/// tab and opens its URL as a link), so the extension's window closed within 70 ms, the extension got
/// `windows.onRemoved` at once, and its URL opened in a new tab. The window now opens over the last
/// shown web pane of a regular profile, and over no pane when none shows.
extension CEFSparePageSuites {
    @MainActor @Suite struct CEFPopupWindowOpenerTests {
        typealias Fixture = CEFSparePageSuites.CEFSparePageTests

        /// A pane of `runtime` showing a tab (not created yet) in a view of its own.
        private static func shown(_ runtime: CEFRuntime, profile: BrowserProfileID, offTheRecord: Bool) -> (CEFTab, NSView) {
            let key = CEFPaneKey(pane: BrowserPaneID(rawValue: UUID().uuidString), profile: profile, offTheRecord: offTheRecord)
            let host = runtime.host(for: key)
            host.endOfTurn = { $0() }
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            let tab = CEFTab(id: .random(), profile: profile, host: host, runtime: runtime)
            host.add(tab)
            host.present(tab, in: container)
            return (tab, container)
        }

        @Test func anExtensionPopupWindowOpensOverTheLastWebPaneNotOverACmuxPage() throws {
            let (runtime, root) = try Fixture.runtime()
            defer { Fixture.tearDown(runtime, root) }
            Fixture.setSparePage(false)
            let (web, webView) = Self.shown(runtime, profile: .default, offTheRecord: false)
            // A cmux page shows after it: the cmux pages' store is off the record.
            let (page, pageView) = Self.shown(runtime, profile: BrowserProfileID(rawValue: UUID()), offTheRecord: true)
            _ = (webView, pageView)
            #expect(runtime.lastShownHost === page.host)
            #expect(runtime.popupWindowOpener() === web, "the extension's window opened over a cmux page, which closes it at once")
        }

        @Test func withOnlyCmuxPagesShownNoPaneTakesTheWindow() throws {
            let (runtime, root) = try Fixture.runtime()
            defer { Fixture.tearDown(runtime, root) }
            Fixture.setSparePage(false)
            let (page, pageView) = Self.shown(runtime, profile: BrowserProfileID(rawValue: UUID()), offTheRecord: true)
            _ = pageView
            #expect(runtime.lastShownHost === page.host)
            #expect(runtime.popupWindowOpener() == nil, "a cmux page took the extension's window")
        }
    }
}
