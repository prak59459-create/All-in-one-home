import Foundation

/// 次のトークンの選び方。既定値は Qwen2.5-0.5B-Instruct の generation_config.json と同じ
/// （温度 0.7、上位 20 個、累積 0.8、繰り返しの抑制 1.1）。温度 0 なら一番高いものを選ぶ。
struct QwenSamplingOptions: Hashable, Sendable {
    var temperature: Float = 0.7
    var topK: Int = 20
    var topP: Float = 0.8
    var repetitionPenalty: Float = 1.1

    static let greedy = QwenSamplingOptions(temperature: 0, topK: 1, topP: 1, repetitionPenalty: 1)
}

/// 決まった種から同じ列を出す乱数（テストで結果を固定するため。SplitMix64）。
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value: UInt64 = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

enum QwenSampler {
    /// logits から次のトークンを選ぶ。previous は、これまでに出したトークン（繰り返しの抑制に使う）。
    static func next<Random: RandomNumberGenerator>(
        logits: [Float],
        previous: [Int],
        options: QwenSamplingOptions,
        random: inout Random
    ) -> Int {
        var scores: [Float] = logits
        penalize(&scores, previous: previous, penalty: options.repetitionPenalty)
        let candidates: [(id: Int, score: Float)] = top(scores, count: max(options.topK, 1))
        guard options.temperature > 0, candidates.count > 1 else {
            return candidates.first?.id ?? 0
        }
        let probabilities: [Float] = softmax(candidates.map { (candidate: (id: Int, score: Float)) -> Float in candidate.score / options.temperature })
        let kept: Int = nucleusCount(probabilities, topP: options.topP)
        let total: Float = probabilities.prefix(kept).reduce(0, +)
        var threshold: Float = Float.random(in: 0..<1, using: &random) * total
        for index in 0..<kept {
            threshold -= probabilities[index]
            if threshold < 0 {
                return candidates[index].id
            }
        }
        return candidates[kept - 1].id
    }

    /// Hugging Face と同じ: 出たことのあるトークンは、正なら割り、負なら掛ける。
    static func penalize(_ scores: inout [Float], previous: [Int], penalty: Float) {
        guard penalty != 1 else { return }
        for id in Set(previous) where id >= 0 && id < scores.count {
            scores[id] = scores[id] > 0 ? scores[id] / penalty : scores[id] * penalty
        }
    }

    /// 大きい順に count 個（同じ値なら ID の小さい方を先に）。
    static func top(_ scores: [Float], count: Int) -> [(id: Int, score: Float)] {
        var best: [(id: Int, score: Float)] = []
        best.reserveCapacity(count + 1)
        for (id, score) in scores.enumerated() where !score.isNaN {
            if best.count == count, let last = best.last, score <= last.score {
                continue
            }
            let position: Int = best.firstIndex { (item: (id: Int, score: Float)) -> Bool in score > item.score } ?? best.count
            best.insert((id, score), at: position)
            if best.count > count {
                best.removeLast()
            }
        }
        return best
    }

    static func softmax(_ values: [Float]) -> [Float] {
        guard let maximum = values.max() else { return [] }
        let exponentials: [Float] = values.map { (value: Float) -> Float in exp(value - maximum) }
        let sum: Float = exponentials.reduce(0, +)
        return exponentials.map { (value: Float) -> Float in value / sum }
    }

    /// 確率の大きい順に足して topP に届くまでの個数（届いた 1 つも含める。最低 1 個）。
    static func nucleusCount(_ probabilities: [Float], topP: Float) -> Int {
        guard topP < 1 else { return probabilities.count }
        var sum: Float = 0
        for (index, probability) in probabilities.enumerated() {
            sum += probability
            if sum >= topP {
                return index + 1
            }
        }
        return max(probabilities.count, 1)
    }
}
