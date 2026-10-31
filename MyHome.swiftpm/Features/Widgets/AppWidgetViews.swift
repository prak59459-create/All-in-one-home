import SwiftUI

/// アプリのウィジェットの中身（追加フェーズ A。アイコンの代わりにホーム画面に置く）。
/// 天気・メモ・タスクは、そのアプリのデータの一部を表示する（データはホーム画面が出た後に、メインスレッドの外で読む）。
@MainActor
struct AppWidgetView: View {
    let feature: AppFeature
    let size: WidgetSize

    var body: some View {
        switch feature {
        case .weather:
            WeatherWidgetView(size: size)
        case .notes:
            NotesWidgetView(size: size)
        case .tasks:
            TasksWidgetView(size: size)
        case .aiAssistant:
            AIWidgetView(size: size)
        default:
            LauncherWidgetView(feature: feature, size: size)
        }
    }
}

/// ウィジェットの見出し（記号と名前）。
@MainActor
struct AppWidgetHeader: View {
    let feature: AppFeature

    var body: some View {
        let style: FeatureIconStyle = FeatureIconStyle.of(feature)
        Label(feature.title, systemImage: style.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RGBAColor(hex: style.tint).color)
            .lineLimit(1)
    }
}

/// 中身のないアプリ（電卓・単位変換・設定など）は、大きな記号と名前だけ。
@MainActor
struct LauncherWidgetView: View {
    let feature: AppFeature
    let size: WidgetSize

    var body: some View {
        let style: FeatureIconStyle = FeatureIconStyle.of(feature)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Image(systemName: style.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(RGBAColor(hex: style.tint).color, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
            Spacer(minLength: 0)
            Text(feature.title)
                .font(.headline)
                .lineLimit(1)
            if size == .medium {
                Text(feature.state.canOpen ? "タップして開く" : feature.state.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 天気: 選んでいる場所の今の天気（前回取得したもの。ホーム画面では通信しない）。
@MainActor
struct WeatherWidgetView: View {
    let size: WidgetSize
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<WeatherData> = library.document(WeatherData.self)
        WeatherWidgetContent(data: document.content, isLoaded: document.isLoaded, size: size)
            .task {
                await document.load()
            }
    }
}

@MainActor
struct WeatherWidgetContent: View {
    let data: WeatherData
    let isLoaded: Bool
    let size: WidgetSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            AppWidgetHeader(feature: .weather)
            if let location = data.selectedLocation, let snapshot = data.snapshot(for: location.id) {
                WeatherWidgetSummary(location: location, snapshot: snapshot, unit: data.temperatureUnit, size: size)
            } else {
                Spacer(minLength: 0)
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyText: String {
        guard isLoaded else { return "" }
        if data.locations.isEmpty {
            return "タップして、天気を表示する場所を追加"
        }
        return data.isNetworkEnabled ? "タップして天気を取得" : "通信はオフです。タップして設定"
    }
}

@MainActor
struct WeatherWidgetSummary: View {
    let location: WeatherLocation
    let snapshot: WeatherSnapshot
    let unit: TemperatureUnit
    let size: WidgetSize

    var body: some View {
        let current: CurrentWeather = snapshot.current
        let condition: WeatherCondition? = current.weatherCode.map { (code: Int) -> WeatherCondition in WeatherCondition(code: code) }
        let today: DailyWeather? = snapshot.upcomingDays(from: Date()).first
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(WeatherFormat.temperatureText(current.temperature, unit: unit))
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text(condition?.title ?? "")
                    .font(.caption)
                    .lineLimit(1)
                Text(rangeText(today))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if size == .medium {
                Image(systemName: condition?.symbolName(isDay: current.isDay ?? true) ?? "cloud")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 44))
            }
        }
    }

    private func rangeText(_ day: DailyWeather?) -> String {
        guard let day else { return "" }
        let high: String = WeatherFormat.temperatureText(day.temperatureMax, unit: unit)
        let low: String = WeatherFormat.temperatureText(day.temperatureMin, unit: unit)
        return "最高 \(high)  最低 \(low)"
    }
}

/// メモ: 新しい順（ピン留めが先）に、題名を 3 つまで。
@MainActor
struct NotesWidgetView: View {
    let size: WidgetSize
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<NoteBook> = library.document(NoteBook.self)
        let notes: [Note] = Array(document.content.sortedNotes.prefix(size == .medium ? 4 : 3))
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            AppWidgetHeader(feature: .notes)
            if notes.isEmpty {
                Spacer(minLength: 0)
                Text(document.isLoaded ? "メモはまだありません" : "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { (note: Note) in
                    Text(note.displayTitle)
                        .font(.callout)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await document.load()
        }
    }
}

/// タスク: 期限切れ・今日・これからの順に、終わっていないものを 3 つまで。
@MainActor
struct TasksWidgetView: View {
    let size: WidgetSize
    @Environment(MiniAppLibrary.self) private var library

    var body: some View {
        let document: MiniAppDocument<TodoList> = library.document(TodoList.self)
        let today = DayStamp(Date(), calendar: .current)
        let open: [TodoItem] = document.content.groups(today: today)
            .filter { (group: TodoGroup) -> Bool in group.section != .done }
            .flatMap { (group: TodoGroup) -> [TodoItem] in group.items }
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            AppWidgetHeader(feature: .tasks)
            if open.isEmpty {
                Spacer(minLength: 0)
                Text(document.isLoaded ? "終わっていないタスクはありません" : "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ForEach(open.prefix(size == .medium ? 4 : 3)) { (item: TodoItem) in
                    Label(item.title, systemImage: "circle")
                        .font(.callout)
                        .lineLimit(1)
                }
                let overdue: Int = document.content.overdueCount(today: today)
                if overdue > 0 {
                    Text("期限切れ \(overdue) 件")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await document.load()
        }
    }
}

/// AI: 使えるモデルを表示する（モデルは読み込まない。入れたかどうかは、表示した時に 1 回だけ調べる）。
@MainActor
struct AIWidgetView: View {
    let size: WidgetSize
    @State private var modelText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            AppWidgetHeader(feature: .aiAssistant)
            Spacer(minLength: 0)
            Text("AI に聞く")
                .font(.title3.weight(.semibold))
            Text(modelText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            modelText = AIWidgetView.describeModel()
        }
    }

    private static func describeModel() -> String {
        if LLMRuntime.isSystemModelAvailable {
            return "Apple の端末内モデル"
        }
        if QwenModelSupport.isInstalled {
            return QwenModelSupport.displayName
        }
        return "モデルを入れると使えます"
    }
}
