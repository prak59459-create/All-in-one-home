/// WMO の天気コード（Open-Meteo の weather_code）を、日本語の名前と SF Symbols の記号にする（F0289）。
/// Open-Meteo は数字だけを返すので、名前と記号はこのアプリで付けている。
struct WeatherCondition: Hashable, Sendable {
    /// 背景の色分け（F0317）と雨の判定に使う大まかな種類。
    enum Kind: Hashable, Sendable {
        case clear
        case partlyCloudy
        case cloudy
        case fog
        case rain
        case snow
        case thunder
        case unknown
    }

    let code: Int

    var kind: Kind {
        switch code {
        case 0, 1: return .clear
        case 2: return .partlyCloudy
        case 3: return .cloudy
        case 45, 48: return .fog
        case 51...67, 80...82: return .rain
        case 71...77, 85, 86: return .snow
        case 95...99: return .thunder
        default: return .unknown
        }
    }

    /// 雨・雪・雷雨など、何かが降っている（降る）天気か。
    var isPrecipitation: Bool {
        switch kind {
        case .rain, .snow, .thunder: return true
        case .clear, .partlyCloudy, .cloudy, .fog, .unknown: return false
        }
    }

    var title: String {
        switch code {
        case 0: return "快晴"
        case 1: return "晴れ"
        case 2: return "晴れ時々くもり"
        case 3: return "くもり"
        case 45: return "霧"
        case 48: return "霧（着氷）"
        case 51: return "弱い霧雨"
        case 53: return "霧雨"
        case 55: return "強い霧雨"
        case 56, 57: return "着氷性の霧雨"
        case 61: return "弱い雨"
        case 63: return "雨"
        case 65: return "強い雨"
        case 66, 67: return "着氷性の雨"
        case 71: return "弱い雪"
        case 73: return "雪"
        case 75: return "強い雪"
        case 77: return "霧雪"
        case 80: return "弱いにわか雨"
        case 81: return "にわか雨"
        case 82: return "激しいにわか雨"
        case 85: return "弱いにわか雪"
        case 86: return "強いにわか雪"
        case 95: return "雷雨"
        case 96, 99: return "ひょうを伴う雷雨"
        case 97: return "激しい雷雨"
        default: return "不明（コード \(code)）"
        }
    }

    /// SF Symbols の名前。夜は月の記号にする（晴れ・晴れ時々くもり・にわか雨）。
    func symbolName(isDay: Bool) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 95, 97: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.hail.fill"
        default: return "questionmark.circle"
        }
    }
}
