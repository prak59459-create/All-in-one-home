import Foundation
@testable import MyHomeCore

/// メモリ上の保存先。書き込み回数を数え、失敗も起こせる。複数のタスクから使われるためロックで守る。
final class MemoryArchiveStorage: HomeArchiveStorage, @unchecked Sendable {
    struct WriteFailure: Error {}

    private let lock = NSLock()
    private var stored: Data?
    private var writes: Int = 0
    private var asideNames: [String] = []
    private var failingWrites: Bool = false
    private var failingSetAside: Bool = false

    init(data: Data? = nil) {
        stored = data
    }

    var data: Data? {
        locked { stored }
    }

    var writeCount: Int {
        locked { writes }
    }

    var setAsideNames: [String] {
        locked { asideNames }
    }

    func failWrites(_ failing: Bool) {
        locked { failingWrites = failing }
    }

    func failSetAside(_ failing: Bool) {
        locked { failingSetAside = failing }
    }

    func read(limit: Int) throws -> Data? {
        locked { stored.map { data in data.prefix(limit + 1) } }
    }

    func write(_ data: Data) throws {
        try locked {
            if failingWrites {
                throw WriteFailure()
            }
            stored = data
            writes += 1
        }
    }

    func setAside(label: String) throws -> String {
        try locked {
            if failingSetAside {
                throw WriteFailure()
            }
            let name: String = "home.\(label)-\(asideNames.count + 1).json"
            asideNames.append(name)
            stored = nil
            return name
        }
    }

    private func locked<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

enum PersistenceFixtures {
    static func link(_ id: String, title: String = "リンク") -> HomeItem {
        HomeItem(id: id, title: title, symbolName: "link", tint: RGBAColor(hex: 0x2563EB), action: .openURL("https://example.com/\(id)"))
    }

    static func feature(_ feature: AppFeature) -> HomeItem {
        HomeItem(id: "feature.\(feature.rawValue)", title: feature.title, symbolName: "gearshape", tint: RGBAColor(hex: 0x6B7280), action: .feature(feature))
    }

    static func layout(pages: [[HomeItem]], dock: [HomeItem] = []) -> HomeLayout {
        var result: [HomePage] = []
        for (index, items) in pages.enumerated() {
            result.append(HomePage(id: "page.\(index)", items: items))
        }
        return HomeLayout(pages: result, dock: dock)
    }

    static func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    static func encoded(_ saved: SavedHome) throws -> Data {
        try HomeArchiveCodec.encode(saved)
    }
}
