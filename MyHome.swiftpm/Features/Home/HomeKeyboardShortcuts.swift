import SwiftUI

/// iPad のハードウェアキーボードでの操作（F0983）。⌘ キーを長押しすると一覧が出る。
/// 見えないボタンにショートカットを付けている。シートやフォルダが開いている時は、後ろのホーム画面を動かさない。
@MainActor
struct HomeKeyboardShortcuts: View {
    @Binding var pageIndex: Int
    let pageCount: Int
    @Environment(AppRouter.self) private var router
    @Environment(\.motionLevel) private var motion

    var body: some View {
        let editTitle: String = router.isEditing ? "編集を終える" : "ホーム画面を編集"
        ZStack {
            Button("設定") {
                perform {
                    router.sheet = .feature(.settings)
                }
            }
            .keyboardShortcut(",", modifiers: .command)
            Button(editTitle) {
                perform {
                    toggleEditing()
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            Button("前のページ") {
                perform {
                    movePage(by: -1)
                }
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("次のページ") {
                perform {
                    movePage(by: 1)
                }
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func perform(_ action: () -> Void) {
        guard router.sheet == nil, router.openFolderID == nil else { return }
        action()
    }

    private func toggleEditing() {
        if router.isEditing {
            router.endEditing()
        } else {
            router.beginEditing()
        }
    }

    private func movePage(by offset: Int) {
        guard pageCount > 0 else { return }
        let next: Int = min(max(pageIndex + offset, 0), pageCount - 1)
        withAnimation(MotionStyle.movement(motion)) {
            pageIndex = next
        }
    }
}
