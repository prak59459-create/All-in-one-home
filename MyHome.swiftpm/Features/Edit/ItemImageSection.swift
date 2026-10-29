import PhotosUI
import SwiftUI

/// 項目のアイコンの画像（F0047、F0048）。選んだ写真の中央を正方形に切り出し、小さくして保存する。
/// 「保存」を押すまで項目は変わらない（imageName は編集シートの中の値）。
@MainActor
struct ItemImageSection: View {
    @Binding var imageName: String?
    let tint: RGBAColor
    let symbolName: String
    @Environment(\.imageStore) private var imageStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading: Bool = false
    @State private var failure: String?

    var body: some View {
        Section {
            HStack(spacing: DesignTokens.Spacing.medium) {
                IconTile(
                    symbolName: symbolName, tint: tint, badge: nil, size: DesignTokens.Icon.compactDockSize,
                    image: ImageCache.shared.image(named: imageName, in: imageStore)
                )
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(isLoading ? "読み込んでいます…" : "写真を選ぶ", systemImage: "photo")
                    }
                    .disabled(imageStore == nil || isLoading)
                    if imageName != nil {
                        Button("画像を外す（記号に戻す）") {
                            imageName = nil
                        }
                    }
                }
            }
            if let failure {
                Text(failure).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("画像")
        } footer: {
            Text(imageStore == nil ? "この起動では画像を保存できません。" : "画像のファイルがなくなった時は、記号で表示します。")
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
                try ImageImporter.prepare(data, maxPixels: ImageImporter.iconMaxPixels, squareCrop: true)
            }.value
            imageName = try store.save(prepared, prefix: "icon")
        } catch let error as ImageFileError {
            failure = error.message
        } catch {
            failure = ImageFileError.unreadable.message
        }
    }
}
