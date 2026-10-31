/// 使える幅からアイコングリッドの列数を決める。
/// 縦横の回転、Split View、ステージマネージャーでのウィンドウ幅変更に追従できるよう、幅だけを入力にする。
struct GridMetrics: Hashable, Sendable {
    var minimumCellWidth: Double
    var spacing: Double
    var minimumColumns: Int
    var maximumColumns: Int

    static let standard = GridMetrics(minimumCellWidth: 104, spacing: 16, minimumColumns: 3, maximumColumns: 8)

    func columnCount(forWidth width: Double) -> Int {
        guard width.isFinite, width > 0 else { return minimumColumns }
        let fitting: Double = ((width + spacing) / (minimumCellWidth + spacing)).rounded(.down)
        let columns: Int = Int(fitting)
        return min(max(columns, minimumColumns), maximumColumns)
    }
}
