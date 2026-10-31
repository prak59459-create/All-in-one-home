/// AI 画面で選べるモデル（F0374、F0380）。プロバイダーは「読み込む」を押した時に初めて作る（遅延ロード）。
struct AIProviderOption: Identifiable {
    let descriptor: LLMModelDescriptor
    let availability: LLMAvailability
    /// 何をするモデルかの説明（F0397、F0399）。
    let detail: String
    let makeProvider: @MainActor () -> (any LocalLLMProvider)?

    var id: String { descriptor.id }

    /// 使えるものを先に並べる。端末内モデルが使えればそれを既定にする。
    @MainActor
    static func all() -> [AIProviderOption] {
        let options: [AIProviderOption] = [systemModel(), qwen(), stub()]
        return options
    }

    /// Core ML の Qwen2.5 0.5B（追加フェーズ A）。モデルは AI の画面から 1 回だけ取得して入れる。
    static let qwenID: String = "qwen2.5-0.5b-coreml"

    @MainActor
    private static func qwen() -> AIProviderOption {
        AIProviderOption(
            descriptor: LLMModelDescriptor(id: qwenID, displayName: QwenModelSupport.displayName, format: .coreML),
            availability: QwenModelSupport.availability(),
            detail: "Alibaba Cloud の小さなモデル（Apache 2.0）を、この iPad の中の Core ML で動かします。入力した文章は端末の外に送りません。"
                + "小さいので、まちがえることも多いです。iPadOS 18 以降。",
            makeProvider: { () -> (any LocalLLMProvider)? in QwenModelSupport.makeProvider() }
        )
    }

    @MainActor
    private static func systemModel() -> AIProviderOption {
        AIProviderOption(
            descriptor: LLMModelDescriptor(id: "apple.system", displayName: "Apple の端末内モデル", format: .systemModel),
            availability: SystemModelSupport.availability(),
            detail: "iPad の中で動くモデルです（Apple Intelligence）。入力した文章は端末の外に送らず、ネットに接続していなくても使えます。",
            makeProvider: { () -> (any LocalLLMProvider)? in SystemModelSupport.makeProvider() }
        )
    }

    @MainActor
    private static func stub() -> AIProviderOption {
        let provider = StubLocalLLMProvider()
        return AIProviderOption(
            descriptor: provider.descriptor,
            availability: .available,
            detail: "推論をしない確認用のモデルです。決まった文だけを返します（本物の AI の回答ではありません）。",
            makeProvider: { () -> (any LocalLLMProvider)? in StubLocalLLMProvider() }
        )
    }
}
