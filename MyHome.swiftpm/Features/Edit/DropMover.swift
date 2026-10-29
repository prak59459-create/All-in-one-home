import SwiftUI

/// ドラッグで落とされた項目の移動。理由のある失敗（Dock がいっぱい等）は説明を出し、
/// ホーム画面の項目ではない文字列（他のアプリからのドラッグなど）は黙って無視する。
@MainActor
enum DropMover {
    static func perform(store: HomeStore, router: AppRouter, action: (HomeStore) throws -> Void) -> Bool {
        do {
            try action(store)
            return true
        } catch LayoutEditError.itemNotFound {
            return false
        } catch let error as LayoutEditError {
            router.showNotice(title: "移動できません", message: error.message)
            return false
        } catch {
            return false
        }
    }
}
