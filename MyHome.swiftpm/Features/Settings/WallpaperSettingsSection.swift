import PhotosUI
import SwiftUI

/// 壁紙の設定（F0647、F0650、F0651）。写真は PhotosPicker で選ぶ（写真へのアクセスの許可は不要。選んだ写真だけを受け取る）。
/// 画面に合う大きさに縮小してから、アプリの中に保存する。iPadOS 自体の壁紙は変えられない（OS の制限）。
@MainActor
struct WallpaperSettingsSection: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.imageStore) private var imageStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading: Bool = false
    @State private var failure: String?

    var body: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(isLoading ? "読み込んでいます…" : "写真を選ぶ", systemImage: "photo")
            }
            .disabled(imageStore == nil || isLoading)
            if case .image(let image) = settings.wallpaper {
                WallpaperAdjustments(image: image)
                Button("テーマの背景に戻す") {
                    settings.wallpaper = .themeGradient
                }
            }
            if imageStore == nil {
                Text("この起動では画像を保存できません（検証用の起動など）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let failure {
                Text(failure).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("壁紙")
        } footer: {
            Text("MyHome の中の壁紙です。iPadOS のホーム画面やロック画面の壁紙は、アプリからは変えられません。")
        }
        .onChange(of: pickerItem) { _, item in
            if let item {
                Task { await load(item) }
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let store = imageStore else { return }
        isLoading = true
        failure = nil
        defer {
            isLoading = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ImageFileError.unreadable }
            let prepared: Data = try await Task.detached(priority: .userInitiated) {
                try ImageImporter.prepare(data, maxPixels: ImageImporter.wallpaperMaxPixels, squareCrop: false)
            }.value
            let name: String = try store.save(prepared, prefix: "wallpaper")
            let previous: WallpaperImage? = currentImage
            settings.wallpaper = .image(WallpaperImage(fileName: name, blur: previous?.blur ?? 0, dim: previous?.dim ?? 0.2))
        } catch let error as ImageFileError {
            failure = error.message
        } catch {
            failure = ImageFileError.unreadable.message
        }
    }

    private var currentImage: WallpaperImage? {
        if case .image(let image) = settings.wallpaper {
            return image
        }
        return nil
    }
}

@MainActor
struct WallpaperAdjustments: View {
    let image: WallpaperImage
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading) {
            Text("ぼかし")
            Slider(value: binding(\.blur), in: 0...1)
            Text("暗さ（文字を読みやすくする）")
            Slider(value: binding(\.dim), in: 0...1)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<WallpaperImage, Double>) -> Binding<Double> {
        Binding<Double>(
            get: { image[keyPath: keyPath] },
            set: { (value: Double) in
                var updated: WallpaperImage = image
                updated[keyPath: keyPath] = value
                settings.wallpaper = .image(WallpaperImage(fileName: updated.fileName, blur: updated.blur, dim: updated.dim))
            }
        )
    }
}
