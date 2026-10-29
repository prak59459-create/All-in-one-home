import ImageIO
import SwiftUI
import UIKit

/// 画像の保存先を View に渡す（保存しない起動では nil）。
private struct ImageStoreKey: EnvironmentKey {
    static let defaultValue: ImageFileStore? = nil
}

extension EnvironmentValues {
    var imageStore: ImageFileStore? {
        get { self[ImageStoreKey.self] }
        set { self[ImageStoreKey.self] = newValue }
    }
}

/// 読み込んだ画像のメモリ上の置き場。数を限って古いものから捨てる（F0678）。
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 120
    }

    /// 画像がない・読めない時は nil（呼び出し側は記号やグラデーションに戻す。F0827）。
    func image(named name: String?, in store: ImageFileStore?) -> UIImage? {
        guard let name, let store else { return nil }
        let key: NSString = name as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let data = store.load(name), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// 選んだ写真を縮小して JPEG にする。元の画像全体を展開せずに縮小する ImageIO を使い、メモリを抑える。
/// 時間がかかるので、メインスレッドの外（Task.detached）から呼ぶ（F0902）。
enum ImageImporter {
    /// 壁紙は iPad の画面の長辺（最大 2,752px）程度まで。
    static let wallpaperMaxPixels: Int = 2800
    /// アイコンは 64pt の 3 倍程度。
    static let iconMaxPixels: Int = 256

    static func prepare(_ data: Data, maxPixels: Int, squareCrop: Bool) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw ImageFileError.unreadable }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: squareCrop ? maxPixels * 2 : maxPixels
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageFileError.unreadable
        }
        let image: CGImage = squareCrop ? try centerSquare(of: thumbnail, side: maxPixels) : thumbnail
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else { throw ImageFileError.unreadable }
        return jpeg
    }

    /// 中央の正方形を切り出して、一辺 side px 以下にする。
    private static func centerSquare(of image: CGImage, side: Int) throws -> CGImage {
        let length: Int = min(image.width, image.height)
        let rect = CGRect(x: (image.width - length) / 2, y: (image.height - length) / 2, width: length, height: length)
        guard let cropped = image.cropping(to: rect) else { throw ImageFileError.unreadable }
        guard length > side else { return cropped }
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered: UIImage = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: target))
        }
        guard let result = rendered.cgImage else { throw ImageFileError.unreadable }
        return result
    }
}
