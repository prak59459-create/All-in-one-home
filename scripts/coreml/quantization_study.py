#!/usr/bin/env python3
"""量子化のしかたで、答えがどれだけ元のモデル（float32）と変わるかを PyTorch の上で比べる（Core ML がなくても動く）。

使い方: python scripts/coreml/quantization_study.py <Qwen2.5 のモデルのフォルダ>

5 つの質問で元のモデルの貪欲な答え（48 トークン）を正解にし、量子化したモデルに正解を順に入れて、
各位置で一番高いトークンが正解と同じだった割合を出す。重みは 32 個（4bit は 16 個も）ずつの区切りで対称に量子化する
（Core ML の linear_quantize_weights の per_block と同じ考え方）。入力の埋め込みと出力（lm_head）は別の重みにして測る。
"""
import sys

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

PROMPTS = ["日本の首都はどこですか？", "Write a haiku about autumn.", "1 から 10 までの数を足すといくつ？",
           "Pythonでリストを逆順にする方法を教えて。", "おすすめの朝ごはんを3つ教えてください。"]
# (層, 入力の埋め込み, 出力, 区切り)
CONFIGS = [(4, 4, 4, 32), (4, 4, 4, 16), (8, 8, 8, 32), (8, 4, 8, 32), (8, 4, 4, 16), (4, 8, 8, 16)]


def quantize(weight, bits, block):
    rows, cols = weight.shape
    blocks = weight.reshape(rows, cols // block, block)
    top = 2 ** (bits - 1) - 1
    scale = blocks.abs().amax(dim=-1, keepdim=True) / top
    scale[scale == 0] = 1
    return (torch.clamp(torch.round(blocks / scale), -top - 1, top) * scale).reshape(rows, cols)


def main():
    folder = sys.argv[1]
    tokenizer = AutoTokenizer.from_pretrained(folder)
    reference = AutoModelForCausalLM.from_pretrained(folder, torch_dtype=torch.float32).eval()
    cases = []
    with torch.no_grad():
        for question in PROMPTS:
            messages = [{"role": "system", "content": "You are a helpful assistant."}, {"role": "user", "content": question}]
            ids = tokenizer.apply_chat_template(messages, tokenize=True, add_generation_prompt=True)
            answer = reference.generate(torch.tensor([ids]), max_new_tokens=48, do_sample=False)[0, len(ids):].tolist()
            cases.append((ids, answer))
    for layer_bits, embed_bits, head_bits, block in CONFIGS:
        model = AutoModelForCausalLM.from_pretrained(folder, torch_dtype=torch.float32).eval()
        with torch.no_grad():
            model.lm_head.weight = torch.nn.Parameter(model.model.embed_tokens.weight.data.clone())
            for name, parameter in model.named_parameters():
                if parameter.dim() != 2 or parameter.numel() < 2048:
                    continue
                bits = embed_bits if "embed_tokens" in name else head_bits if "lm_head" in name else layer_bits
                parameter.data = quantize(parameter.data, bits, block)
            agree = total = 0
            for ids, answer in cases:
                logits = model(torch.tensor([ids + answer])).logits[0]
                for index, token in enumerate(answer):
                    agree += int(int(torch.argmax(logits[len(ids) - 1 + index])) == token)
                    total += 1
        print(f"層 int{layer_bits} / 入力の埋め込み int{embed_bits} / 出力 int{head_bits} / 区切り {block}: {agree}/{total} = {agree / total:.0%}")


if __name__ == "__main__":
    main()
