#!/usr/bin/env python3
"""Swift の QwenTokenizer のテスト用に、Hugging Face のトークナイザーで正解を作る。

使い方: python scripts/coreml/make_tokenizer_cases.py <Qwen2.5 のモデルのフォルダ> <書き出す JSON>
"""
import json
import sys

from transformers import AutoTokenizer

CASES = [
    "こんにちは、世界！",
    "日本の首都はどこですか？",
    "Hello, world! I'm fine, aren't you? We've done it, they'll come, it's OK.",
    "The quick brown fox jumps over the lazy dog 1234567890 times.",
    "  先頭と末尾の空白  ",
    "改行\nが\n\n2つ\r\nと CRLF",
    "タブ\tと　全角空白",
    "絵文字🙂👍🏽と国旗🇯🇵",
    "コード: for i in range(10): print(i ** 2) # comment",
    "func add(_ a: Int, _ b: Int) -> Int { a + b }",
    "メールは test@example.com、URL は https://example.com/path?q=1&r=2 です。",
    "１２３ と 123 と ①②③",
    "가나다 和 中文 и русский",
    "ﾊﾝｶｸｶﾀｶﾅ と ＡＢＣ",
    "é と é（NFC で同じになる）",
    "",
    " ",
    "a",
    "!!!???...",
    "<|im_start|> は普通の文字として扱う",
]


def main():
    tokenizer = AutoTokenizer.from_pretrained(sys.argv[1])
    cases = []
    for text in CASES:
        ids = tokenizer.encode(text, add_special_tokens=False, split_special_tokens=True)
        cases.append({"text": text, "ids": ids, "decoded": tokenizer.decode(ids)})
    chat = [{"role": "system", "content": "あなたは親切なアシスタントです。"}, {"role": "user", "content": "こんにちは"}]
    prompt = tokenizer.apply_chat_template(chat, tokenize=True, add_generation_prompt=True)
    with open(sys.argv[2], "w", encoding="utf-8") as handle:
        json.dump({"cases": cases, "chat": {"messages": chat, "ids": prompt}}, handle, ensure_ascii=False, indent=1)
    print(f"{len(cases)} 件")


if __name__ == "__main__":
    main()
