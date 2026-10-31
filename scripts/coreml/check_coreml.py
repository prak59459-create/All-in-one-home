#!/usr/bin/env python3
"""変換した Core ML の Qwen を、macOS の Core ML で動かして確かめる（Linux では予測できない）。

使い方: python scripts/coreml/check_coreml.py <Qwen2.5 のモデルのフォルダ> <変換した .mlpackage のフォルダ>

1. 同じ質問で、transformers（float32）の貪欲な生成を正解として作る
2. Core ML（float16・重みは 4bit）に、質問と正解のトークンを順に入れ、各位置で一番高いトークンが正解と同じかを数える
   （4bit にした分のずれを測る。80% 以上で合格）
3. Core ML だけで貪欲に生成し、答えの文を表示する（「東京」が入っていれば合格）
"""
import os
import sys
import time

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

NAMES = ["QwenEmbedding", "QwenLayers0", "QwenLayers1", "QwenLayers2", "QwenHead"]
PROMPT = "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n<|im_start|>user\n日本の首都はどこですか？<|im_end|>\n<|im_start|>assistant\n"
STEPS = 16
MASKED = np.float16(-1e4)


def mask(length, past):
    end = past + length
    result = np.zeros((1, 1, length, end), dtype=np.float16)
    for row in range(length):
        result[0, 0, row, past + row + 1 :] = MASKED
    return result


class CoreMLQwen:
    def __init__(self, folder):
        units = ct.ComputeUnit.CPU_AND_GPU
        started = time.time()
        self.models = [ct.models.MLModel(os.path.join(folder, f"{name}.mlpackage"), compute_units=units) for name in NAMES]
        print(f"読み込み: {time.time() - started:.1f} 秒")
        self.reset()

    def reset(self):
        self.states = [model.make_state() for model in self.models[1:4]]
        self.length = 0

    def feed(self, ids):
        embed, layers, head = self.models[0], self.models[1:4], self.models[4]
        count = len(ids)
        hidden = embed.predict({"input_ids": np.array([ids], dtype=np.int32)})["hidden"]
        positions = np.arange(self.length, self.length + count, dtype=np.int32)
        causal = mask(count, self.length)
        for model, state in zip(layers, self.states):
            hidden = model.predict({"hidden": hidden, "position_ids": positions, "causal_mask": causal}, state=state)["output_hidden"]
        self.length += count
        logits = head.predict({"hidden": hidden})["logits"]
        return np.asarray(logits, dtype=np.float32).reshape(-1)


def main():
    model_dir, folder = sys.argv[1], sys.argv[2]
    tokenizer = AutoTokenizer.from_pretrained(model_dir)
    reference = AutoModelForCausalLM.from_pretrained(model_dir, torch_dtype=torch.float32).eval()
    prompt = tokenizer(PROMPT).input_ids
    with torch.no_grad():
        expected = reference.generate(torch.tensor([prompt]), max_new_tokens=STEPS, do_sample=False)[0, len(prompt):].tolist()
    print(f"正解（transformers）: {tokenizer.decode(expected)!r}")

    qwen = CoreMLQwen(folder)
    # 2. 正解のトークンを入れながら、各位置の一番高いトークンを比べる
    started = time.time()
    logits = qwen.feed(prompt)
    prefill = time.time() - started
    agree = 0
    for index, token in enumerate(expected):
        if int(np.argmax(logits)) == token:
            agree += 1
        if index + 1 < len(expected):
            logits = qwen.feed([token])
    rate = agree / len(expected)
    print(f"一致: {agree}/{len(expected)}（{rate:.0%}）。質問 {len(prompt)} トークンの読み込み {prefill:.2f} 秒")

    # 3. Core ML だけで生成する
    qwen.reset()
    logits = qwen.feed(prompt)
    generated = []
    started = time.time()
    for _ in range(STEPS):
        token = int(np.argmax(logits))
        generated.append(token)
        if token in (151643, 151645):
            break
        logits = qwen.feed([token])
    elapsed = time.time() - started
    text = tokenizer.decode(generated)
    print(f"Core ML の生成: {text!r}（{len(generated)} トークン、{len(generated) / max(elapsed, 1e-6):.1f} トークン/秒）")
    if not np.isfinite(logits).all():
        raise SystemExit("logits に NaN / inf がある")
    if rate < 0.8:
        raise SystemExit(f"正解との一致が少ない（{rate:.0%}）")
    if "東京" not in text:
        raise SystemExit("答えに「東京」がない")
    print("合格")


if __name__ == "__main__":
    main()
