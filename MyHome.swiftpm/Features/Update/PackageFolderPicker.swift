import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Files から MyHome.swiftpm を「その場で開く」形で選ぶ（asCopy: false）。
/// SwiftUI の fileImporter ではなく UIDocumentPickerViewController を使い、コピーを受け取らないことをはっきりさせる。
@MainActor
struct PackageFolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types: [UTType] = [.folder, .package]
        if let swiftpm = UTType(filenameExtension: "swiftpm") {
            types.insert(swiftpm, at: 0)
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    @MainActor
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
