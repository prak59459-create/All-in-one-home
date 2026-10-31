import XCTest
@testable import MyHomeCore

final class GridMetricsTests: XCTestCase {
    private let metrics: GridMetrics = .standard

    func testInvalidWidthsFallBackToMinimum() {
        XCTAssertEqual(metrics.columnCount(forWidth: 0), metrics.minimumColumns)
        XCTAssertEqual(metrics.columnCount(forWidth: -10), metrics.minimumColumns)
        XCTAssertEqual(metrics.columnCount(forWidth: .nan), metrics.minimumColumns)
        XCTAssertEqual(metrics.columnCount(forWidth: .infinity), metrics.minimumColumns)
    }

    /// Slide Over や狭い Split View でも最低列数を保つ。
    func testNarrowWindowKeepsMinimumColumns() {
        XCTAssertEqual(metrics.columnCount(forWidth: 280), 3)
    }

    func testColumnsGrowWithWidth() {
        let portrait: Int = metrics.columnCount(forWidth: 794)
        let landscape: Int = metrics.columnCount(forWidth: 1154)
        XCTAssertEqual(portrait, 6)
        XCTAssertGreaterThan(landscape, portrait)
    }

    func testWideWindowIsCappedAtMaximum() {
        XCTAssertEqual(metrics.columnCount(forWidth: 5000), metrics.maximumColumns)
    }

    func testCellsNeverGetNarrowerThanMinimumAboveMinimumColumns() {
        for width in stride(from: 400.0, through: 1400.0, by: 7.0) {
            let columns: Int = metrics.columnCount(forWidth: width)
            let cellWidth: Double = (width - Double(columns - 1) * metrics.spacing) / Double(columns)
            XCTAssertGreaterThanOrEqual(cellWidth, metrics.minimumCellWidth, "width \(width)")
        }
    }
}
