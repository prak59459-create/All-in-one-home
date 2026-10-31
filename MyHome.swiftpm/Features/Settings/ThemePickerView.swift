import SwiftUI

/// テーマのプリセットを並べて選ぶ（F0645）。選択中は枠と記号で示し、色だけに頼らない（F0980）。
@MainActor
struct ThemePickerView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                ForEach(ThemeCatalog.all) { preset in
                    ThemeOptionButton(preset: preset, isDark: colorScheme == .dark, isSelected: preset.id == settings.themeID) {
                        settings.themeID = preset.id
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.small)
        }
    }
}

@MainActor
struct ThemeOptionButton: View {
    let preset: ThemePreset
    let isDark: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.small) {
                swatch
                Text(preset.name)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(traits)
    }

    private var traits: AccessibilityTraits {
        isSelected ? .isSelected : []
    }

    private var swatch: some View {
        let palette: ThemePalette = preset.palette(isDark: isDark)
        let colors: [Color] = [palette.wallpaperTop.color, palette.wallpaperBottom.color]
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        return shape
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(width: DesignTokens.Swatch.width, height: DesignTokens.Swatch.height)
            .overlay { shape.stroke(borderColor, lineWidth: borderWidth) }
            .overlay(alignment: .bottomTrailing) { checkmark }
    }

    private var borderColor: Color {
        isSelected ? Color.accentColor : Color.secondary.opacity(0.3)
    }

    private var borderWidth: CGFloat {
        isSelected ? 3 : 1
    }

    @ViewBuilder
    private var checkmark: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.accentColor)
                .padding(DesignTokens.Spacing.xSmall)
        }
    }
}
