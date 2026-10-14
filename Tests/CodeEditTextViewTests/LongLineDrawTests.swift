import XCTest
@testable import CodeEditTextView

/// A line whose glyph run is wider than 65,536 device pixels draws nothing at all with some TrueType faces
/// (Courier New, JetBrains Mono): CoreGraphics drops the whole run, not just the far end (Forge FD59).
@MainActor
final class LongLineDrawTests: XCTestCase {
    private let font = NSFont(name: "CourierNewPSMT", size: 13)!
    private let line = String(repeating: "isSelected0123456789", count: 1_100) // 22,000 characters

    override func setUp() { continueAfterFailure = false }

    func test_veryLongLineDraws() throws {
        let textView = TextView(
            string: line, font: font, textColor: .white, lineHeightMultiplier: 1.0, wrapLines: false,
            isEditable: true, isSelectable: false, letterSpacing: 1.0, delegate: nil
        )
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 100))
        scrollView.documentView = textView
        textView.frame = scrollView.bounds
        let window = NSWindow(contentRect: scrollView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = scrollView
        textView.updateFrameIfNeeded()
        textView.layout()

        let rep = try XCTUnwrap(scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds))
        scrollView.cacheDisplay(in: scrollView.bounds, to: rep)
        var inked = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh where (rep.colorAt(x: x, y: y)?.brightnessComponent ?? 0) > 0.5 {
                inked += 1
                break
            }
        }
        XCTAssertGreaterThan(inked, rep.pixelsWide / 4, "the long line drew (almost) nothing")

        // Past the first piece, a caret still maps to its x and a click back to its offset.
        let layoutManager = try XCTUnwrap(textView.layoutManager)
        let rect = try XCTUnwrap(layoutManager.rectForOffset(15_000))
        XCTAssertEqual(rect.minX, try XCTUnwrap(layoutManager.rectForOffset(1)).minX * 15_000, accuracy: 1)
        XCTAssertEqual(layoutManager.textOffsetAtPoint(CGPoint(x: rect.minX + 1, y: rect.midY)), 15_000)
    }

    /// Each text piece's CTLine covers exactly the characters it is laid out for, and none is wider than the cap.
    func test_textContentsCoverTheirFragmentAndStayNarrow() {
        for maxWidth in [CGFloat.greatestFiniteMagnitude, 600] {
            let typesetter = Typesetter()
            let string = NSAttributedString(string: line, attributes: [.font: font])
            typesetter.typeset(
                string,
                documentRange: NSRange(location: 0, length: string.length),
                displayData: .init(maxWidth: maxWidth, lineHeightMultiplier: 1, estimatedLineHeight: 15, breakStrategy: .character),
                markedRanges: nil
            )
            var location = 0
            for fragment in typesetter.lineFragments {
                for content in fragment.data.contents {
                    guard case .text(let ctLine) = content.data else { continue }
                    XCTAssertEqual(CTLineGetStringRange(ctLine).location, location)
                    XCTAssertLessThanOrEqual(content.width, Typesetter.maxContentWidth)
                    location += content.length
                }
                XCTAssertLessThanOrEqual(fragment.data.width, min(maxWidth, CGFloat(string.length) * 10))
                XCTAssertEqual(location, fragment.range.max, "fragment's text does not match its range")
            }
            XCTAssertEqual(location, string.length)
        }
    }
}
