#!/usr/bin/env python3
"""models/qwen2.5-0.5b-instruct-coreml のファイルから、アプリが持つ一覧（QwenModelManifest+Files.swift）を作る。

使い方: python3 scripts/coreml/make_manifest.py [--check] models/qwen2.5-0.5b-instruct-coreml MyHome.swiftpm/Core/AI/Qwen/QwenModelManifest+Files.swift
--check は書き換えず、今のファイルと同じかだけを確かめる（違えば終了コード 1。CI で使う）。

ハッシュは git のブロブのハッシュ（git hash-object と同じ。GitHub の tree API の sha と比べる）。
README と LICENSE は取得しないので入れない。
"""
import hashlib
import os
import sys

SKIP = {"README.md", "LICENSE-Qwen2.5.txt"}


def blob_hash(path):
    with open(path, "rb") as handle:
        data = handle.read()
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest(), len(data)


def main():
    arguments = sys.argv[1:]
    check = "--check" in arguments
    folder, output = [argument for argument in arguments if argument != "--check"]
    entries = []
    for root, _, names in os.walk(folder):
        for name in names:
            full = os.path.join(root, name)
            relative = os.path.relpath(full, folder)
            if relative in SKIP or name.startswith("."):
                continue
            sha, size = blob_hash(full)
            entries.append((relative, size, sha))
    entries.sort()
    lines = [
        "// このファイルは scripts/coreml/make_manifest.py で作る（手で書き換えない）。",
        "// models/qwen2.5-0.5b-instruct-coreml の中身を変えたら、作り直してから一緒にコミットする。",
        "extension QwenModelManifest {",
        "    static let files: [QwenModelFile] = [",
    ]
    for relative, size, sha in entries:
        lines.append(f'        QwenModelFile(path: "{relative}", size: {size}, blob: "{sha}"),')
    lines += ["    ]", "}", ""]
    content = "\n".join(lines)
    total = sum(size for _, size, _ in entries)
    if check:
        with open(output, encoding="utf-8") as handle:
            if handle.read() != content:
                raise SystemExit(f"{output} が {folder} の中身と違う。make_manifest.py で作り直してコミットする")
        print(f"一致: {len(entries)} ファイル、合計 {total / 1_000_000:.1f}MB")
        return
    with open(output, "w", encoding="utf-8") as handle:
        handle.write(content)
    print(f"{len(entries)} ファイル、合計 {total / 1_000_000:.1f}MB")


if __name__ == "__main__":
    main()
