"""Qwen2.5（Qwen2 の構造）の推論だけを、Core ML に変換しやすい形で書いたもの。

transformers の Qwen2ForCausalLM と同じ計算をする（verify で照合する）。違うのは次の点だけ:
- KV キャッシュは register_buffer の状態（Core ML の状態。iOS 18 以降）に置き、slice の代入で書き込む
- RMSNorm は layer_norm で計算する（[x, -x] の平均は 0 なので、layer_norm が x / sqrt(mean(x^2) + eps) になる。
  float16 で x^2 が溢れるのを避けるため。Core ML の layer_norm は内部で安定に計算される）
- 位置は入力の position_ids から、前もって作った cos / sin の表を引く
- モデルを「埋め込み」「層のまとまり」「出力」に分けて変換できる（1 ファイル 100MB 未満にするため）
"""
import json
import math
import os

import torch
from torch import nn
from safetensors.torch import load_file


class QwenConfig:
    def __init__(self, path):
        with open(os.path.join(path, "config.json"), encoding="utf-8") as handle:
            raw = json.load(handle)
        self.hidden = raw["hidden_size"]
        self.intermediate = raw["intermediate_size"]
        self.layers = raw["num_hidden_layers"]
        self.heads = raw["num_attention_heads"]
        self.kv_heads = raw["num_key_value_heads"]
        self.head_dim = self.hidden // self.heads
        self.eps = raw["rms_norm_eps"]
        self.theta = raw["rope_theta"]
        self.vocab = raw["vocab_size"]
        self.tied = raw.get("tie_word_embeddings", False)


def load_weights(path):
    weights = load_file(os.path.join(path, "model.safetensors"))
    return {name: tensor.to(torch.float32) for name, tensor in weights.items()}


class RMSNorm(nn.Module):
    def __init__(self, weight, eps):
        super().__init__()
        self.weight = nn.Parameter(weight.clone(), requires_grad=False)
        self.eps = eps
        # 次元は Python の整数で持つ（テンソルの形から取り出すと Core ML に変換できないため）
        self.dim = int(weight.shape[0])

    def forward(self, x):
        # layer_norm([x, -x]) の前半 = x / sqrt(mean(x^2) + eps)
        doubled = torch.cat([x, -x], dim=-1)
        normed = torch.nn.functional.layer_norm(doubled, (2 * self.dim,), eps=self.eps)
        return normed[..., : self.dim] * self.weight


def rotate_half(x, half):
    """half は Python の整数（head_dim の半分）。"""
    return torch.cat([-x[..., half:], x[..., :half]], dim=-1)


class Attention(nn.Module):
    def __init__(self, cfg, w, prefix):
        super().__init__()
        self.cfg = cfg
        self.q = nn.Linear(cfg.hidden, cfg.heads * cfg.head_dim, bias=True)
        self.k = nn.Linear(cfg.hidden, cfg.kv_heads * cfg.head_dim, bias=True)
        self.v = nn.Linear(cfg.hidden, cfg.kv_heads * cfg.head_dim, bias=True)
        self.o = nn.Linear(cfg.heads * cfg.head_dim, cfg.hidden, bias=False)
        for name, layer in (("q_proj", self.q), ("k_proj", self.k), ("v_proj", self.v), ("o_proj", self.o)):
            layer.weight.data = w[f"{prefix}.self_attn.{name}.weight"].clone()
            if layer.bias is not None:
                layer.bias.data = w[f"{prefix}.self_attn.{name}.bias"].clone()

    def forward(self, x, cos, sin, mask, key_cache, value_cache, index, past, end):
        cfg = self.cfg
        # 長さは -1 にする（形から整数を取り出すと Core ML に変換できないため。バッチは常に 1）
        q = self.q(x).view(1, -1, cfg.heads, cfg.head_dim).transpose(1, 2)
        k = self.k(x).view(1, -1, cfg.kv_heads, cfg.head_dim).transpose(1, 2)
        v = self.v(x).view(1, -1, cfg.kv_heads, cfg.head_dim).transpose(1, 2)
        half = cfg.head_dim // 2
        q = q * cos + rotate_half(q, half) * sin
        k = k * cos + rotate_half(k, half) * sin
        # 状態（KV キャッシュ）に書き込んでから、そこまでの全部を読む
        # 状態は float16（Core ML の決まり）。計算の型との間は、書く時と読む時に合わせる
        key_cache[index : index + 1, :, past:end, :] = k.to(key_cache.dtype)
        value_cache[index : index + 1, :, past:end, :] = v.to(value_cache.dtype)
        keys = key_cache[index : index + 1, :, :end, :].to(q.dtype)
        values = value_cache[index : index + 1, :, :end, :].to(q.dtype)
        # GQA: KV のヘッド（2）を、Q のヘッドの数（14）に広げる。repeat_interleave は長さから整数を取り出すので
        # Core ML に変換できない。expand と reshape で同じことをする
        groups = cfg.heads // cfg.kv_heads
        keys = keys[:, :, None, :, :].expand(-1, -1, groups, -1, -1).reshape(1, cfg.heads, -1, cfg.head_dim)
        values = values[:, :, None, :, :].expand(-1, -1, groups, -1, -1).reshape(1, cfg.heads, -1, cfg.head_dim)
        scores = torch.matmul(q, keys.transpose(2, 3)) / math.sqrt(cfg.head_dim) + mask
        weights = torch.softmax(scores, dim=-1)
        out = torch.matmul(weights, values).transpose(1, 2).reshape(1, -1, cfg.heads * cfg.head_dim)
        return self.o(out)


class MLP(nn.Module):
    def __init__(self, cfg, w, prefix):
        super().__init__()
        self.gate = nn.Linear(cfg.hidden, cfg.intermediate, bias=False)
        self.up = nn.Linear(cfg.hidden, cfg.intermediate, bias=False)
        self.down = nn.Linear(cfg.intermediate, cfg.hidden, bias=False)
        self.gate.weight.data = w[f"{prefix}.mlp.gate_proj.weight"].clone()
        self.up.weight.data = w[f"{prefix}.mlp.up_proj.weight"].clone()
        self.down.weight.data = w[f"{prefix}.mlp.down_proj.weight"].clone()

    def forward(self, x):
        return self.down(torch.nn.functional.silu(self.gate(x)) * self.up(x))


class Block(nn.Module):
    def __init__(self, cfg, w, layer):
        super().__init__()
        prefix = f"model.layers.{layer}"
        self.input_norm = RMSNorm(w[f"{prefix}.input_layernorm.weight"], cfg.eps)
        self.post_norm = RMSNorm(w[f"{prefix}.post_attention_layernorm.weight"], cfg.eps)
        self.attention = Attention(cfg, w, prefix)
        self.mlp = MLP(cfg, w, prefix)

    def forward(self, x, cos, sin, mask, key_cache, value_cache, index, past, end):
        x = x + self.attention(self.input_norm(x), cos, sin, mask, key_cache, value_cache, index, past, end)
        return x + self.mlp(self.post_norm(x))


def rope_tables(cfg, max_context):
    inv = 1.0 / (cfg.theta ** (torch.arange(0, cfg.head_dim, 2, dtype=torch.float64) / cfg.head_dim))
    positions = torch.arange(max_context, dtype=torch.float64)
    freqs = torch.outer(positions, inv)
    emb = torch.cat([freqs, freqs], dim=-1)
    return emb.cos().to(torch.float32), emb.sin().to(torch.float32)


class Embedding(nn.Module):
    """input_ids (1, Q) int32 → hidden (1, Q, hidden)。"""

    def __init__(self, cfg, w):
        super().__init__()
        self.table = nn.Embedding(cfg.vocab, cfg.hidden)
        self.table.weight.data = w["model.embed_tokens.weight"].clone()

    def forward(self, input_ids):
        return self.table(input_ids)


class LayerChunk(nn.Module):
    """層 [start, end) をまとめたもの。hidden (1, Q, H)・position_ids (Q,)・causal_mask (1, 1, Q, K) → hidden。
    K（そこまでの長さ）は causal_mask の最後の次元、past = K - Q。KV キャッシュはこのまとまりの状態に持つ。"""

    def __init__(self, cfg, w, start, end, max_context, dtype=torch.float16):
        super().__init__()
        self.blocks = nn.ModuleList([Block(cfg, w, layer) for layer in range(start, end)])
        cos, sin = rope_tables(cfg, max_context)
        self.register_buffer("cos_table", cos)
        self.register_buffer("sin_table", sin)
        shape = (end - start, cfg.kv_heads, max_context, cfg.head_dim)
        self.register_buffer("keyCache", torch.zeros(shape, dtype=dtype))
        self.register_buffer("valueCache", torch.zeros(shape, dtype=dtype))

    def forward(self, hidden, position_ids, causal_mask):
        length = hidden.shape[1]
        end = causal_mask.shape[-1]
        past = end - length
        cos = self.cos_table[position_ids].unsqueeze(0).unsqueeze(0)
        sin = self.sin_table[position_ids].unsqueeze(0).unsqueeze(0)
        for index, block in enumerate(self.blocks):
            hidden = block(hidden, cos, sin, causal_mask, self.keyCache, self.valueCache, index, past, end)
        return hidden


class Head(nn.Module):
    """hidden (1, Q, H) → 最後の位置の、語彙 [start, end) の logits (1, 1, end - start)。
    8bit の出力は 1 ファイル 100MB を超えるので、語彙を 2 つに分けて別のモデルにする（Swift の側でつなぐ）。"""

    def __init__(self, cfg, w, start=0, end=None):
        super().__init__()
        end = cfg.vocab if end is None else end
        self.norm = RMSNorm(w["model.norm.weight"], cfg.eps)
        self.lm_head = nn.Linear(cfg.hidden, end - start, bias=False)
        name = "model.embed_tokens.weight" if cfg.tied else "lm_head.weight"
        self.lm_head.weight.data = w[name][start:end].clone()

    def forward(self, hidden):
        last = hidden[:, -1:, :]
        return self.lm_head(self.norm(last))


def causal_mask(length, past):
    """(1, 1, length, past + length)。見てはいけない所は -inf の代わりに大きな負の数（float16 で表せる値）。"""
    end = past + length
    mask = torch.zeros((1, 1, length, end), dtype=torch.float32)
    for row in range(length):
        mask[0, 0, row, past + row + 1 :] = -1e4
    return mask
