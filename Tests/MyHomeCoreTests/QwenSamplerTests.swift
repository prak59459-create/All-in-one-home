import Foundation
import XCTest
@testable import MyHomeCore

/// 追加フェーズ A: 次のトークンの選び方（温度・上位 k 個・累積 p・繰り返しの抑制）。
final class QwenSamplerTests: XCTestCase {
    func testGreedyPicksTheHighestScore() {
        var random = SeededRandom(seed: 1)
        let logits: [Float] = [0.1, 3.0, 2.0, -1.0]
        XCTAssertEqual(QwenSampler.next(logits: logits, previous: [], options: .greedy, random: &random), 1)
    }

    func testRepetitionPenaltyFollowsHuggingFace() {
        var scores: [Float] = [2.0, -2.0, 1.0]
        QwenSampler.penalize(&scores, previous: [0, 1, 1], penalty: 2)
        XCTAssertEqual(scores, [1.0, -4.0, 1.0], "正は割り、負は掛ける。同じトークンが何度出ても 1 回だけ")
    }

    func testTopKeepsTheLargestInOrder() {
        let top: [(id: Int, score: Float)] = QwenSampler.top([0.5, 2.0, Float.nan, 2.0, 1.0], count: 3)
        XCTAssertEqual(top.map { (item: (id: Int, score: Float)) -> Int in item.id }, [1, 3, 4], "同じ値は ID の小さい方が先。NaN は使わない")
    }

    func testNucleusKeepsTheSmallestSetReachingP() {
        XCTAssertEqual(QwenSampler.nucleusCount([0.5, 0.3, 0.2], topP: 0.8), 2)
        XCTAssertEqual(QwenSampler.nucleusCount([0.9, 0.1], topP: 0.8), 1)
        XCTAssertEqual(QwenSampler.nucleusCount([0.5, 0.5], topP: 1), 2)
    }

    func testSamplingStaysInsideTheNucleusAndIsRepeatable() {
        // 0 と 1 で 0.8 を超えるので、2 と 3 は選ばれない
        let logits: [Float] = [3.0, 2.5, 0.0, -1.0]
        let options = QwenSamplingOptions(temperature: 1, topK: 4, topP: 0.8, repetitionPenalty: 1)
        var first = SeededRandom(seed: 42)
        var second = SeededRandom(seed: 42)
        var picks: [Int] = []
        for _ in 0..<200 {
            let pick: Int = QwenSampler.next(logits: logits, previous: [], options: options, random: &first)
            XCTAssertTrue([0, 1].contains(pick))
            XCTAssertEqual(pick, QwenSampler.next(logits: logits, previous: [], options: options, random: &second), "同じ種なら同じ")
            picks.append(pick)
        }
        XCTAssertTrue(picks.contains(0) && picks.contains(1), "どちらも選ばれる")
    }
}
