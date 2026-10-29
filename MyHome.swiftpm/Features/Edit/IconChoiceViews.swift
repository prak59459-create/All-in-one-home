import SwiftUI

/// 記号の選択。選んでいるものは枠と VoiceOver の「選択中」で示す。
@MainActor
struct SymbolChoiceGrid: View {
    @Binding var selection: String
    let tint: RGBAColor
    var symbols: [String] = IconChoices.symbols

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 52), spacing: DesignTokens.Spacing.small)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.small) {
            ForEach(symbols, id: \.self) { symbol in
                SymbolChoiceButton(symbol: symbol, tint: tint, isSelected: symbol == selection) {
                    selection = symbol
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xSmall)
    }
}

@MainActor
struct SymbolChoiceButton: View {
    let symbol: String
    let tint: RGBAColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint.readableForeground.color)
                .frame(width: 48, height: 48)
                .background(tint.color, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 色の選択。色の名前も読み上げる（色だけに頼らない）。
@MainActor
struct ColorChoiceRow: View {
    @Binding var selection: RGBAColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(IconChoices.colors.indices, id: \.self) { index in
                    ColorChoiceButton(
                        color: IconChoices.colors[index],
                        name: IconChoices.colorNames[index],
                        isSelected: IconChoices.colors[index] == selection
                    ) {
                        selection = IconChoices.colors[index]
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xSmall)
        }
    }
}

@MainActor
struct ColorChoiceButton: View {
    let color: RGBAColor
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(color.readableForeground.color)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
