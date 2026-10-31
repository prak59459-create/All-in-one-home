/// ウィジェット型のホーム画面の並べ方（追加フェーズ A）。左上から順に並べ、入りきらなければ次の行へ送る。
/// 位置は、並べた全体の左上からの値。全体の幅は、いちばん長い行の幅（画面では中央に寄せる）。
struct WidgetFlow: Equatable, Sendable {
    struct Frame: Equatable, Sendable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    let frames: [Frame]
    let width: Double
    let height: Double

    /// sizes はウィジェットの幅と高さ。使える幅より広いものは、1 行に 1 つだけ置く。
    init(sizes: [(width: Double, height: Double)], availableWidth: Double, spacing: Double) {
        var frames: [Frame] = []
        var x: Double = 0
        var y: Double = 0
        var rowHeight: Double = 0
        var widest: Double = 0
        for size in sizes {
            if x > 0 && x + size.width > availableWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            frames.append(Frame(x: x, y: y, width: size.width, height: size.height))
            widest = max(widest, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        self.frames = frames
        self.width = widest
        self.height = frames.isEmpty ? 0 : y + rowHeight
    }
}
