#!/usr/bin/env python3
"""バックアップの画面の起動テスト用に、この iPad のバックアップ（Backups/myhome-*.json）を作る。

中身は起動テストの保存ファイル（home-folder.json と apps/notes.json）をまとめたもので、
形式は MyHome.swiftpm/Core/Backup/BackupArchive.swift と同じ（files の data は Base64）。
手動で保存したもの 1 つと、復元の前に自動で残したもの 1 つを作る（名前の日時は今の時刻。端末の時刻として読む）。

使い方: python3 scripts/fixtures/make-backup-fixture.py <Backups のフォルダ>
"""
import base64
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))


def entry(path, source):
    with open(os.path.join(ROOT, source), "rb") as handle:
        return {"path": path, "data": base64.b64encode(handle.read()).decode("ascii")}


def archive(created):
    return {
        "format": "myhome-backup",
        "formatVersion": 1,
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(created)),
        "appVersion": "0.1",
        "files": [entry("home.json", "home-folder.json"), entry("Apps/notes.json", "apps/notes.json")],
    }


def main():
    folder = sys.argv[1]
    os.makedirs(folder, exist_ok=True)
    now = int(time.time())
    for kind, created in (("manual", now - 3600), ("before-restore", now - 600)):
        stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(created))
        name = "myhome-%s-%s.json" % (kind, stamp)
        with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
            json.dump(archive(created), handle, ensure_ascii=False, indent=2)
        print(name)


if __name__ == "__main__":
    main()
