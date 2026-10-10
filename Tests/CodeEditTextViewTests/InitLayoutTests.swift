import Testing
import AppKit
@testable import CodeEditTextView

/// A `TextView` built before it is in a scroll view must not lay out the whole document: with no window its
/// `visibleRect` is every line, and a 50k-line file took ~48 s to open (one line-fragment view per line).
@Suite
@MainActor
struct InitLayoutTests {
    @Test
    func initWithoutScrollViewLaysOutOneScreenful() {
        let text = String(repeating: "let value = 42 // a line of code\n", count: 5_000)
        let textView = TextView(string: text)
        let laidOut = textView.layoutManager.visibleLineIds.count
        #expect(laidOut > 0)
        #expect(laidOut < 500)
    }
}
