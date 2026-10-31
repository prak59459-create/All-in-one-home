import SwiftUI

/// 電卓のボタン1つの定義。
struct CalculatorButtonSpec: Identifiable {
    enum Action {
        case key(CalculatorKey)
        case equals
    }

    enum Kind {
        case digit
        case function
        case operation
        case equals
    }

    let id: String
    let label: String
    /// VoiceOver で読み上げる名前。
    let spokenLabel: String
    let action: Action
    let kind: Kind
    var columns: Int = 1
    /// ハードウェアキーボードのキー（修飾キーなし）。
    var shortcut: KeyEquivalent? = nil
}

struct CalculatorRow: Identifiable {
    let id: Int
    let buttons: [CalculatorButtonSpec]
}

/// ボタンの並び。型推論の負荷を抑えるため、行ごとに分けて要素型を明示する。
enum CalculatorLayout {
    static func rows() -> [CalculatorRow] {
        let rows: [[CalculatorButtonSpec]] = [topRow(), digitRow(7, .multiply), digitRow(4, .subtract), digitRow(1, .add), bottomRow(), extraRow()]
        return rows.enumerated().map { (pair: (offset: Int, element: [CalculatorButtonSpec])) -> CalculatorRow in
            CalculatorRow(id: pair.offset, buttons: pair.element)
        }
    }

    private static func topRow() -> [CalculatorButtonSpec] {
        let row: [CalculatorButtonSpec] = [
            CalculatorButtonSpec(id: "clear", label: "C", spokenLabel: "クリア", action: .key(.clear), kind: .function, shortcut: .escape),
            CalculatorButtonSpec(id: "open", label: "(", spokenLabel: "かっこ開く", action: .key(.openParen), kind: .function, shortcut: "("),
            CalculatorButtonSpec(id: "close", label: ")", spokenLabel: "かっこ閉じる", action: .key(.closeParen), kind: .function, shortcut: ")"),
            operation(.divide, shortcut: "/")
        ]
        return row
    }

    private static func digitRow(_ first: Int, _ operation: CalculatorOperation) -> [CalculatorButtonSpec] {
        let shortcuts: [CalculatorOperation: KeyEquivalent] = [.multiply: "*", .subtract: "-", .add: "+"]
        let row: [CalculatorButtonSpec] = [
            digit(first),
            digit(first + 1),
            digit(first + 2),
            CalculatorLayout.operation(operation, shortcut: shortcuts[operation])
        ]
        return row
    }

    private static func bottomRow() -> [CalculatorButtonSpec] {
        let row: [CalculatorButtonSpec] = [
            CalculatorButtonSpec(id: "sign", label: "±", spokenLabel: "符号を変える", action: .key(.toggleSign), kind: .function),
            digit(0),
            CalculatorButtonSpec(id: "point", label: ".", spokenLabel: "小数点", action: .key(.decimalPoint), kind: .digit, shortcut: "."),
            CalculatorButtonSpec(id: "equals", label: "=", spokenLabel: "計算する", action: .equals, kind: .equals, shortcut: .return)
        ]
        return row
    }

    private static func extraRow() -> [CalculatorButtonSpec] {
        let row: [CalculatorButtonSpec] = [
            CalculatorButtonSpec(id: "percent", label: "%", spokenLabel: "パーセント", action: .key(.percent), kind: .function, columns: 2, shortcut: "%"),
            CalculatorButtonSpec(id: "back", label: "⌫", spokenLabel: "1文字消す", action: .key(.backspace), kind: .function, columns: 2, shortcut: .delete)
        ]
        return row
    }

    private static func digit(_ value: Int) -> CalculatorButtonSpec {
        let character: Character = Character(String(value))
        return CalculatorButtonSpec(
            id: "digit\(value)",
            label: String(value),
            spokenLabel: String(value),
            action: .key(.digit(value)),
            kind: .digit,
            shortcut: KeyEquivalent(character)
        )
    }

    private static func operation(_ operation: CalculatorOperation, shortcut: KeyEquivalent?) -> CalculatorButtonSpec {
        CalculatorButtonSpec(
            id: "op\(operation.rawValue)",
            label: operation.rawValue,
            spokenLabel: operation.spokenName,
            action: .key(.operation(operation)),
            kind: .operation,
            shortcut: shortcut
        )
    }
}

/// ボタンの並び（Grid）。iPad のハードウェアキーボードでも打てる。
@MainActor
struct CalculatorKeypad: View {
    let onPress: @MainActor (CalculatorKey) -> Void
    let onEquals: @MainActor () -> Void

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(CalculatorLayout.rows()) { (row: CalculatorRow) in
                GridRow {
                    ForEach(row.buttons) { (spec: CalculatorButtonSpec) in
                        CalculatorButton(spec: spec, onPress: onPress, onEquals: onEquals)
                            .gridCellColumns(spec.columns)
                    }
                }
            }
        }
    }
}

@MainActor
struct CalculatorButton: View {
    let spec: CalculatorButtonSpec
    let onPress: @MainActor (CalculatorKey) -> Void
    let onEquals: @MainActor () -> Void

    var body: some View {
        Button {
            switch spec.action {
            case .key(let key):
                onPress(key)
            case .equals:
                onEquals()
            }
        } label: {
            Text(spec.label)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(CalculatorKeyStyle(kind: spec.kind))
        .accessibilityLabel(spec.spokenLabel)
        .modifier(OptionalKeyboardShortcut(key: spec.shortcut))
    }
}

/// キーがある時だけ、修飾キーなしのショートカットを付ける。
@MainActor
struct OptionalKeyboardShortcut: ViewModifier {
    let key: KeyEquivalent?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(key, modifiers: [])
        } else {
            content
        }
    }
}

/// 電卓のボタンの見た目。数字は落ち着いた色、演算子と「=」は目立つ色。押している間は少し薄くする。
@MainActor
struct CalculatorKeyStyle: ButtonStyle {
    let kind: CalculatorButtonSpec.Kind

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        return configuration.label
            .foregroundStyle(foreground)
            .background(background, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }

    private var background: Color {
        switch kind {
        case .digit: return Color(uiColor: .secondarySystemBackground)
        case .function: return Color(uiColor: .systemGray4)
        case .operation: return Color.orange
        case .equals: return Color.accentColor
        }
    }

    private var foreground: Color {
        switch kind {
        case .digit, .function: return Color.primary
        case .operation, .equals: return Color.white
        }
    }
}
