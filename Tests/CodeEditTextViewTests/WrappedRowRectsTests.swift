import XCTest
@testable import CodeEditTextView

/// `rectsFor(range:)` on every row of a wrapped line, and past the first piece of a long unwrapped one. Rows after
/// the first used to give no rect at all: a line-relative range went to a fragment-relative x lookup (Forge FD64).
/// `rectForOffset` (the caret) is the reference: it is checked against clicks in `LongLineDrawTests`.
@MainActor
final class WrappedRowRectsTests: XCTestCase {
    private let font = NSFont(name: "CourierNewPSMT", size: 13)!

    override func setUp() { continueAfterFailure = false }

    private func layOut(_ string: String, wrap: Bool) throws -> TextLayoutManager {
        let textView = TextView(
            string: string, font: font, textColor: .white, lineHeightMultiplier: 1.0, wrapLines: wrap,
            isEditable: true, isSelectable: false, letterSpacing: 1.0, delegate: nil
        )
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        scrollView.documentView = textView
        textView.frame = scrollView.bounds
        let window = NSWindow(contentRect: scrollView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = scrollView
        textView.updateFrameIfNeeded()
        textView.layoutManager.setNeedsLayout() // first laid out before it had a scroll view, so at infinite width
        textView.layout()
        return try XCTUnwrap(textView.layoutManager)
    }

    /// The rect a range on one row should have: from its first character's caret rect to its last's.
    private func expectedRect(_ range: NSRange, in layoutManager: TextLayoutManager) throws -> CGRect {
        let first = try XCTUnwrap(layoutManager.rectForOffset(range.location))
        let last = try XCTUnwrap(layoutManager.rectForOffset(range.max - 1))
        XCTAssertEqual(first.minY, last.minY, "test range crosses a row")
        return CGRect(x: first.minX, y: first.minY, width: last.maxX - first.minX, height: first.height)
    }

    private func assertRect(_ rect: CGRect, matches expected: CGRect, line: UInt = #line) {
        XCTAssertEqual(rect.minX, expected.minX, accuracy: 1, line: line)
        XCTAssertEqual(rect.maxX, expected.maxX, accuracy: 1, line: line)
        XCTAssertEqual(rect.minY, expected.minY, accuracy: 0.5, line: line)
    }

    func test_matchOnSecondAndThirdWrappedRow() throws {
        let layoutManager = try layOut(String(repeating: "let value = isSelected; ", count: 13), wrap: true)
        let rows = Array(try XCTUnwrap(layoutManager.textLineForIndex(0)).data.lineFragments)
        XCTAssertGreaterThanOrEqual(rows.count, 3)
        for row in rows.prefix(3) {
            let match = NSRange(location: row.range.location + 10, length: 6)
            let rects = layoutManager.rectsFor(range: match)
            XCTAssertEqual(rects.count, 1, "row \(row.index + 1) gave \(rects.count) rects")
            assertRect(rects[0], matches: try expectedRect(match, in: layoutManager))
        }
    }

    func test_rangeSpanningARowBreak() throws {
        let layoutManager = try layOut(String(repeating: "let value = isSelected; ", count: 13), wrap: true)
        let rows = Array(try XCTUnwrap(layoutManager.textLineForIndex(0)).data.lineFragments)
        let rowBreak = rows[1].range.max // between rows 2 and 3
        let range = NSRange(location: rowBreak - 4, length: 9)
        let rects = layoutManager.rectsFor(range: range)
        XCTAssertEqual(rects.count, 2)
        assertRect(rects[0], matches: try expectedRect(NSRange(start: range.location, end: rowBreak), in: layoutManager))
        assertRect(rects[1], matches: try expectedRect(NSRange(start: rowBreak, end: range.max), in: layoutManager))
    }

    func test_matchPastTheFirstPieceOfALongUnwrappedLine() throws {
        let layoutManager = try layOut(String(repeating: "isSelected0123456789", count: 1_100), wrap: false)
        let match = NSRange(location: 15_000, length: 10)
        let rects = layoutManager.rectsFor(range: match)
        XCTAssertEqual(rects.count, 1)
        assertRect(rects[0], matches: try expectedRect(match, in: layoutManager))
    }
}
