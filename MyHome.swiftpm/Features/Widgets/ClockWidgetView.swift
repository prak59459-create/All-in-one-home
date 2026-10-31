import SwiftUI

/// 時計のウィジェット（F0201、F0202、F0203）。秒を表示する時だけ1秒ごとに描き直す。
@MainActor
struct ClockWidgetView: View {
    let style: ClockWidgetStyle
    let size: WidgetSize

    var body: some View {
        if style.showsSeconds {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                face(context.date)
            }
        } else {
            TimelineView(.everyMinute) { context in
                face(context.date)
            }
        }
    }

    @ViewBuilder
    private func face(_ date: Date) -> some View {
        if style.isAnalog {
            HStack(spacing: DesignTokens.Spacing.medium) {
                AnalogClockFace(date: date, showsSeconds: style.showsSeconds)
                if size == .medium {
                    DigitalClockText(date: date, showsSeconds: style.showsSeconds)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(date, format: .dateTime.hour().minute()))
        } else {
            DigitalClockText(date: date, showsSeconds: style.showsSeconds)
        }
    }
}

@MainActor
struct DigitalClockText: View {
    let date: Date
    let showsSeconds: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text(date, format: timeFormat)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(date, format: .dateTime.month().day().weekday(.abbreviated))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var timeFormat: Date.FormatStyle {
        showsSeconds ? Date.FormatStyle.dateTime.hour().minute().second() : Date.FormatStyle.dateTime.hour().minute()
    }
}

/// アナログ時計の文字盤。針の角度は Calendar から求める。
@MainActor
struct AnalogClockFace: View {
    let date: Date
    let showsSeconds: Bool

    var body: some View {
        Canvas { context, canvasSize in
            AnalogClockDrawing.draw(in: &context, size: canvasSize, hands: AnalogClockDrawing.hands(for: date))
            if showsSeconds {
                AnalogClockDrawing.drawSecondHand(in: &context, size: canvasSize, date: date)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

enum AnalogClockDrawing {
    struct Hands {
        let hour: Double
        let minute: Double
    }

    /// 0 時の位置から時計回りの角度（ラジアン）。
    static func hands(for date: Date) -> Hands {
        let parts: DateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour: Double = Double((parts.hour ?? 0) % 12)
        let minute: Double = Double(parts.minute ?? 0)
        let hourAngle: Double = (hour + minute / 60) / 12 * 2 * Double.pi
        let minuteAngle: Double = minute / 60 * 2 * Double.pi
        return Hands(hour: hourAngle, minute: minuteAngle)
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, hands: Hands) {
        let radius: CGFloat = min(size.width, size.height) / 2 - 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let face = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(face, with: .color(.primary.opacity(0.35)), lineWidth: 2)
        for tick in 0..<12 {
            let angle: Double = Double(tick) / 12 * 2 * Double.pi
            let mark: Path = line(center, angle: angle, from: radius * 0.82, to: radius * 0.95)
            context.stroke(mark, with: .color(.primary.opacity(0.6)), lineWidth: 2)
        }
        let hourHand: Path = line(center, angle: hands.hour, from: 0, to: radius * 0.5)
        let minuteHand: Path = line(center, angle: hands.minute, from: 0, to: radius * 0.78)
        context.stroke(hourHand, with: .color(.primary), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        context.stroke(minuteHand, with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    static func drawSecondHand(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let radius: CGFloat = min(size.width, size.height) / 2 - 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let second: Double = Double(Calendar.current.component(.second, from: date))
        let angle: Double = second / 60 * 2 * Double.pi
        context.stroke(line(center, angle: angle, from: -radius * 0.1, to: radius * 0.85), with: .color(.orange), lineWidth: 1.5)
    }

    private static func line(_ center: CGPoint, angle: Double, from start: CGFloat, to end: CGFloat) -> Path {
        let dx: CGFloat = CGFloat(sin(angle))
        let dy: CGFloat = CGFloat(-cos(angle))
        var path = Path()
        path.move(to: CGPoint(x: center.x + dx * start, y: center.y + dy * start))
        path.addLine(to: CGPoint(x: center.x + dx * end, y: center.y + dy * end))
        return path
    }
}
