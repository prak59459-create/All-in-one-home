import Foundation

/// 復元の前に見せる、バックアップの中身の要約（F0817、F0818、F0819、F0861）。
struct BackupSummary: Hashable, Sendable {
    let pageCount: Int
    /// 項目の数（フォルダの中の項目も数え、フォルダ自体も 1 件と数える）。
    let itemCount: Int
    let widgetCount: Int
    let themeName: String
    let usesImageWallpaper: Bool
    let countdownCount: Int
    let imageCount: Int

    init(_ contents: BackupContents) {
        let layout: HomeLayout = contents.home.layout
        pageCount = layout.pages.count
        itemCount = layout.itemCount
        widgetCount = layout.pages.reduce(0) { (total: Int, page: HomePage) -> Int in total + page.widgets.count }
        themeName = ThemeCatalog.preset(id: contents.home.settings.themeID).name
        usesImageWallpaper = contents.home.settings.wallpaper.imageFileName != nil
        countdownCount = contents.home.timers.countdowns.count
        imageCount = contents.images.count
    }

    /// 「ページ 2 枚・項目 14 件・ウィジェット 1 個」
    var homeText: String {
        "ページ \(pageCount) 枚・項目 \(itemCount) 件・ウィジェット \(widgetCount) 個"
    }

    /// 「テーマ: 森・壁紙: 画像・タイマー 3 個」
    var settingsText: String {
        let wallpaper: String = usesImageWallpaper ? "画像" : "テーマの色"
        return "テーマ: \(themeName)・壁紙: \(wallpaper)・タイマー \(countdownCount) 個"
    }
}

/// バックアップの表示に使う文字（日時・大きさ・ファイル名）。
enum BackupFormat {
    /// 「2026年10月30日 10:15」（端末の時刻）。
    static func date(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy年M月d日 H:mm"
        return formatter.string(from: date)
    }

    /// 「350 KB」「1.2 MB」（1 KB = 1,000 バイト）。
    static func size(_ byteCount: Int) -> String {
        if byteCount < 1_000 {
            return "\(byteCount) バイト"
        }
        if byteCount < 1_000_000 {
            return "\(byteCount / 1_000) KB"
        }
        let tenths: Int = (byteCount + 50_000) / 100_000
        return "\(tenths / 10).\(tenths % 10) MB"
    }

    /// 書き出す時のファイル名: MyHome-backup-20261030-1015.json（端末の時刻）。
    static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "MyHome-backup-\(formatter.string(from: date)).json"
    }
}
