#!/usr/bin/env python3
"""Qwen2.5-0.5B-Instruct を Core ML（iOS 18 以降。状態付きの KV キャッシュ）に変換する。

使い方:
  python scripts/coreml/convert_qwen.py verify  <モデルのフォルダ>            # transformers と同じ結果になるか（PyTorch のまま）
  python scripts/coreml/convert_qwen.py convert <モデルのフォルダ> <出力先>   # 9 つの .mlpackage に分けて書き出す

出力（GitHub の 1 ファイル 100MB の上限より小さくするため、9 つに分ける）:
  QwenEmbedding.mlpackage     input_ids (1, Q) int32 → hidden (1, Q, 896)。重みは 4bit（入力の埋め込みは 4bit でも答えが変わらない）
  QwenLayers0〜5.mlpackage    層を 4 つずつ。hidden・position_ids (Q)・causal_mask (1, 1, Q, K) → hidden。KV キャッシュは状態。8bit
  QwenHead0・1.mlpackage      hidden → 最後の位置の logits。語彙の前半 (1, 1, 75968) と後半 (1, 1, 75968)。8bit
Q は 1〜MAX_QUERY、K は 1〜MAX_CONTEXT。尺度は 32 個ずつの区切りで持つ。
層と出力を 4bit にすると、元のモデルとの一致が 71〜78% に落ちる（8bit なら 93%。scripts/coreml/README.md）。

モデルのフォルダは Hugging Face の Qwen/Qwen2.5-0.5B-Instruct（Apache 2.0）を落としたもの。
"""
import os
import sys

import numpy as np
import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qwen_model import QwenConfig, load_weights, Embedding, LayerChunk, Head, causal_mask  # noqa: E402

MAX_CONTEXT = 2048
MAX_QUERY = 512
CHUNKS = [(0, 4), (4, 8), (8, 12), (12, 16), (16, 20), (20, 24)]
HEADS = [(0, 75968), (75968, 151936)]
PROMPT = "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n<|im_start|>user\n日本の首都はどこですか？<|im_end|>\n<|im_start|>assistant\n"


def forward_chunks(cfg, w, ids, dtype=torch.float32):
    """分けたモデルを順に通す（Swift の側と同じ手順）。最初に全部を、次に 1 トークンずつ。"""
    embed = Embedding(cfg, w)
    chunks = [LayerChunk(cfg, w, start, end, MAX_CONTEXT, dtype=dtype) for start, end in CHUNKS]
    parts = [Head(cfg, w, start, end) for start, end in HEADS]

    def head(hidden):
        return torch.cat([part(hidden) for part in parts], dim=-1)

    logits = []
    with torch.no_grad():
        hidden = embed(ids)
        length = ids.shape[1]
        positions = torch.arange(length, dtype=torch.int32)
        mask = causal_mask(length, 0)
        for chunk in chunks:
            hidden = chunk(hidden, positions, mask)
        logits.append(head(hidden)[0, -1])
        # 1 トークンずつ（貪欲に選ぶ）
        past = length
        token = int(torch.argmax(logits[-1]))
        generated = [token]
        for _ in range(8):
            hidden = embed(torch.tensor([[token]], dtype=torch.int32))
            positions = torch.tensor([past], dtype=torch.int32)
            mask = causal_mask(1, past)
            for chunk in chunks:
                hidden = chunk(hidden, positions, mask)
            logits.append(head(hidden)[0, -1])
            token = int(torch.argmax(logits[-1]))
            generated.append(token)
            past += 1
    return logits, generated


def verify(model_dir):
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(model_dir)
    reference = AutoModelForCausalLM.from_pretrained(model_dir, torch_dtype=torch.float32)
    reference.eval()
    ids = tokenizer(PROMPT, return_tensors="pt").input_ids.to(torch.int32)
    with torch.no_grad():
        expected = reference(ids.to(torch.long)).logits[0, -1]
        greedy = reference.generate(ids.to(torch.long), max_new_tokens=9, do_sample=False)[0, ids.shape[1]:].tolist()
    cfg = QwenConfig(model_dir)
    w = load_weights(model_dir)
    logits, generated = forward_chunks(cfg, w, ids)
    diff = float((logits[0] - expected).abs().max())
    print(f"最初の logits の差の最大: {diff:.5f}")
    print(f"transformers: {greedy} {tokenizer.decode(greedy)!r}")
    print(f"このモデル:   {generated} {tokenizer.decode(generated)!r}")
    # transformers は終わりの記号（<|im_end|>）で止まるので、その長さまで比べる
    if diff > 1e-2 or generated[: len(greedy)] != greedy:
        raise SystemExit("一致しない")
    print("一致した")


def quantize(mlmodel, dtype):
    import coremltools as ct

    op_config = ct.optimize.coreml.OpLinearQuantizerConfig(
        mode="linear_symmetric", dtype=dtype, granularity="per_block", block_size=32, weight_threshold=2048
    )
    config = ct.optimize.coreml.OptimizationConfig(global_config=op_config)
    return ct.optimize.coreml.linear_quantize_weights(mlmodel, config=config)


def convert_module(module, example_inputs, inputs, outputs, states, path, description, dtype):
    import coremltools as ct

    module.eval()
    with torch.no_grad():
        traced = torch.jit.trace(module, example_inputs)
    mlmodel = ct.convert(
        traced,
        inputs=inputs,
        outputs=outputs,
        states=states,
        minimum_deployment_target=ct.target.iOS18,
        compute_precision=ct.precision.FLOAT16,
        skip_model_load=True,
    )
    mlmodel = quantize(mlmodel, dtype)
    mlmodel.short_description = description
    mlmodel.author = "Qwen2.5-0.5B-Instruct (Apache 2.0, Alibaba Cloud) / MyHome で Core ML に変換"
    mlmodel.license = "Apache License 2.0"
    mlmodel.save(path)
    size = sum(os.path.getsize(os.path.join(root, name)) for root, _, names in os.walk(path) for name in names)
    print(f"{os.path.basename(path)}: {size / 1_000_000:.1f}MB")


def convert(model_dir, out_dir):
    import coremltools as ct

    os.makedirs(out_dir, exist_ok=True)
    cfg = QwenConfig(model_dir)
    w = load_weights(model_dir)
    query = ct.RangeDim(lower_bound=1, upper_bound=MAX_QUERY, default=1)
    context = ct.RangeDim(lower_bound=1, upper_bound=MAX_CONTEXT, default=1)

    ids = torch.zeros((1, 4), dtype=torch.int32)
    convert_module(
        Embedding(cfg, w),
        (ids,),
        [ct.TensorType(name="input_ids", shape=(1, query), dtype=np.int32)],
        [ct.TensorType(name="hidden", dtype=np.float16)],
        None,
        os.path.join(out_dir, "QwenEmbedding.mlpackage"),
        "Qwen2.5-0.5B: トークン → 埋め込み",
        "int4",
    )

    hidden = torch.zeros((1, 4, cfg.hidden), dtype=torch.float32)
    positions = torch.arange(4, dtype=torch.int32)
    mask = causal_mask(4, 2)
    for number, (start, end) in enumerate(CHUNKS):
        chunk = LayerChunk(cfg, w, start, end, MAX_CONTEXT)
        cache_shape = (end - start, cfg.kv_heads, MAX_CONTEXT, cfg.head_dim)
        states = [
            ct.StateType(wrapped_type=ct.TensorType(shape=cache_shape, dtype=np.float16), name="keyCache"),
            ct.StateType(wrapped_type=ct.TensorType(shape=cache_shape, dtype=np.float16), name="valueCache"),
        ]
        convert_module(
            chunk,
            (hidden, positions, mask),
            [
                ct.TensorType(name="hidden", shape=(1, query, cfg.hidden), dtype=np.float16),
                ct.TensorType(name="position_ids", shape=(query,), dtype=np.int32),
                ct.TensorType(name="causal_mask", shape=(1, 1, query, context), dtype=np.float16),
            ],
            [ct.TensorType(name="output_hidden", dtype=np.float16)],
            states,
            os.path.join(out_dir, f"QwenLayers{number}.mlpackage"),
            f"Qwen2.5-0.5B: 層 {start}〜{end - 1}（KV キャッシュは状態）",
            "int8",
        )

    for number, (start, end) in enumerate(HEADS):
        convert_module(
            Head(cfg, w, start, end),
            (hidden,),
            [ct.TensorType(name="hidden", shape=(1, query, cfg.hidden), dtype=np.float16)],
            [ct.TensorType(name="logits", dtype=np.float16)],
            None,
            os.path.join(out_dir, f"QwenHead{number}.mlpackage"),
            f"Qwen2.5-0.5B: 最後の位置の logits（語彙 {start}〜{end - 1}）",
            "int8",
        )


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    command, model_dir = sys.argv[1], sys.argv[2]
    if command == "verify":
        verify(model_dir)
    elif command == "convert":
        convert(model_dir, sys.argv[3])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
