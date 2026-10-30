import Foundation

/// 「このアプリについて」の 1 行。link があれば、確認してから Safari で開くボタンを出す。
struct AboutItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    var linkTitle: String? = nil
    var link: String? = nil
}

struct AboutSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [AboutItem]
    let footer: String
}

/// 設定 → このアプリについて（Phase 9 のライセンス・権限の確認。F0742–F0746、F0756、F0840–F0849、F0861、F0865–F0867、F0870）。
/// OS の許可・通信・保存先・出典とライセンスを並べる。通信先は、実際に使う URL から作る（テストで確かめる）。
/// 機能を変えたら（通信先を増やす、OS の許可を使うなど）ここも直す。
enum AboutCatalog {
    static func sections() -> [AboutSection] {
        [permissions(), network(), storage(), licenses()]
    }

    /// 通信する相手（ホスト名）。天気とソフトウェアアップデートだけ。
    static var networkHosts: [String] {
        weatherHosts + updateHosts
    }

    static var weatherHosts: [String] {
        [OpenMeteoClient.searchEndpoint, OpenMeteoClient.forecastEndpoint].compactMap { (address: String) -> String? in
            URL(string: address)?.host
        }
    }

    static var updateHosts: [String] {
        [GitHubUpdateClient.apiHost, GitHubUpdateClient.rawHost]
    }

    private static func permissions() -> AboutSection {
        let items: [AboutItem] = [
            AboutItem(id: "location", title: "位置情報", detail: "使いません。天気の場所は、都市の名前で探して選びます。"),
            AboutItem(id: "photos", title: "写真", detail: "壁紙とアイコンは、写真を選ぶ画面で選んだ画像だけを受け取ります。写真ライブラリ全体へのアクセスは求めません。"),
            AboutItem(id: "notifications", title: "通知", detail: "使いません。タイマーが終わった時の知らせは、MyHome を開いている間だけです。"),
            AboutItem(id: "others", title: "カメラ・マイク・連絡先・カレンダー", detail: "使いません。カレンダーのウィジェットは日付を表示するだけで、予定は読みません。"),
            AboutItem(id: "files", title: "ファイル", detail: "バックアップの書き出し・読み込みとソフトウェアアップデートでは、ファイルを選ぶ画面で選んだ場所・ファイルだけを使います。"),
            AboutItem(id: "pasteboard", title: "クリップボード", detail: "「コピー」を押した時に書き込むだけです。読むのは、iPadOS の「ペースト」ボタンを押した時だけです。"),
            AboutItem(id: "system", title: "Wi-Fi・Bluetooth・他のアプリの通知・iPadOS の壁紙", detail: "iPadOS の決まりで、普通のアプリからは読めず、変えられません。MyHome も使いません。")
        ]
        return AboutSection(
            id: "permissions",
            title: "OS の許可",
            items: items,
            footer: "MyHome は、iPadOS の許可（プライバシーの確認）を 1 つも求めません。"
        )
    }

    private static func network() -> AboutSection {
        let weather: String = weatherHosts.joined(separator: "、")
        let update: String = updateHosts.joined(separator: "、")
        let items: [AboutItem] = [
            AboutItem(
                id: "weather",
                title: "天気（Open-Meteo）",
                detail: "天気の画面で「通信をオンにする」を押した時だけ、\(weather) に、検索した文字と、選んだ場所の緯度・経度を送ります。位置情報・個人情報は送りません。"
            ),
            AboutItem(
                id: "update",
                title: "ソフトウェアアップデート（GitHub）",
                detail: "設定 → ソフトウェアアップデート で確かめる・書き込む時だけ、\(update) からファイルを受け取ります。"
            ),
            AboutItem(id: "links", title: "リンク", detail: "ホーム画面のリンクは、開く前に確認してから Safari などで開きます。"),
            AboutItem(id: "ai", title: "AI", detail: "Apple の端末内のモデルを使います。会話はどこにも送らず、保存もしません。")
        ]
        return AboutSection(
            id: "network",
            title: "通信",
            items: items,
            footer: "使い方の記録やクラッシュの記録は集めず、どこにも送りません。広告もありません。"
        )
    }

    private static func storage() -> AboutSection {
        let items: [AboutItem] = [
            AboutItem(
                id: "device",
                title: "この iPad の中",
                detail: "ホーム画面の配置・設定・タイマー、ミニアプリのデータ、アイコンと壁紙の画像、この iPad のバックアップ、アップデートの記録を、MyHome の中（Application Support/MyHome）に保存します。"
            ),
            AboutItem(
                id: "exported",
                title: "書き出したバックアップ",
                detail: "選んだ場所（ファイルアプリ・iCloud Drive など）に保存されます。中身は暗号化していないので、渡す相手に気をつけてください。"
            ),
            AboutItem(
                id: "erase",
                title: "消す",
                detail: "設定 → バックアップと復元 の「すべてのデータを消す」で消せます。MyHome を削除しても消えます。"
            )
        ]
        return AboutSection(
            id: "storage",
            title: "保存先",
            items: items,
            footer: "MyHome から iCloud などに送ることはありません。ただし iPad 自体のバックアップ（iCloud バックアップ・パソコンへのバックアップ）には、MyHome のデータも含まれます。"
        )
    }

    private static func licenses() -> AboutSection {
        let items: [AboutItem] = [
            AboutItem(
                id: "open-meteo",
                title: "天気のデータ",
                detail: "Weather data by Open-Meteo.com（CC BY 4.0）。非商用の利用は無料です。",
                linkTitle: "Open-Meteo.com",
                link: "https://open-meteo.com/"
            ),
            AboutItem(
                id: "geonames",
                title: "場所の検索のデータ",
                detail: "GeoNames（CC BY 4.0）。Open-Meteo の場所の検索を通して使います。",
                linkTitle: "GeoNames",
                link: "https://www.geonames.org/"
            ),
            AboutItem(
                id: "cc-by",
                title: "CC BY 4.0",
                detail: "出典を示せば、共有・改変できるライセンスです。",
                linkTitle: "ライセンスの全文",
                link: "https://creativecommons.org/licenses/by/4.0/"
            ),
            AboutItem(
                id: "libraries",
                title: "使っているライブラリ",
                detail: "Apple の SDK（SwiftUI・Foundation Models など）と SF Symbols だけです。外部のライブラリやパッケージは使っていません。"
            )
        ]
        return AboutSection(
            id: "licenses",
            title: "出典とライセンス",
            items: items,
            footer: "\(AppInfo.displayName) バージョン \(AppInfo.version)"
        )
    }
}
