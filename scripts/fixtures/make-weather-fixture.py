#!/usr/bin/env python3
"""天気の起動テスト用の保存ファイル（Apps/weather.json）を、今の時刻に合わせて作る。

通信はオフ（isNetworkEnabled: false）で、前回取得した東京の天気（10 分前）を入れる。
起動テスト（scripts/smoke-test-simulator.sh の app-weather）では、通信しないまま前回の天気が表示されることを確かめる。
時刻はその場で作るので、リポジトリには固定のファイルを置かない（古い時刻だと「この先の予報」が空になるため）。
形式は MyHome.swiftpm/Core/Weather/WeatherData.swift と同じ（Swift の Codable が書く形）。

使い方: python3 scripts/fixtures/make-weather-fixture.py <書き出す先>
"""
import json
import math
import sys
import time

TOKYO_ID = 1850147
OFFSET = 9 * 3600  # 日本時間


def local_hour(unix_time):
    return ((unix_time + OFFSET) // 3600) % 24


def is_day(unix_time):
    return 6 <= local_hour(unix_time) < 17


def build(now):
    hour_start = now - now % 3600
    day_start = now - (now + OFFSET) % 86400
    hourly = []
    for index in range(48):
        moment = hour_start + index * 3600
        hour = local_hour(moment)
        temperature = round(16 + 4 * math.sin((hour - 9) / 24 * 2 * math.pi), 1)
        rainy = 5 <= index <= 7
        hourly.append({
            "time": moment,
            "temperature": temperature,
            "precipitationProbability": 60 if rainy else (30 if index in (4, 8) else 10),
            "precipitation": 1.2 if rainy else 0.0,
            "weatherCode": 61 if rainy else (3 if index in (4, 8) else 2),
            "isDay": is_day(moment),
        })
    codes = [2, 61, 3, 1, 0, 80, 3]
    highs = [21.4, 17.2, 19.0, 22.3, 23.1, 18.4, 20.2]
    lows = [13.1, 14.0, 12.2, 13.5, 15.0, 12.4, 11.3]
    sums = [0.2, 12.5, 0.8, 0.0, 0.0, 3.2, 0.4]
    chances = [30, 90, 40, 10, 0, 60, 20]
    uv = [3.5, 1.2, 2.8, 4.0, 4.1, 2.2, 3.0]
    daily = []
    for index in range(7):
        date = day_start + index * 86400
        daily.append({
            "date": date,
            "weatherCode": codes[index],
            "temperatureMax": highs[index],
            "temperatureMin": lows[index],
            "precipitationSum": sums[index],
            "precipitationProbabilityMax": chances[index],
            "sunrise": date + 6 * 3600 + 5 * 60 + index * 60,
            "sunset": date + 16 * 3600 + 50 * 60 - index * 60,
            "uvIndexMax": uv[index],
        })
    tokyo = {
        "id": TOKYO_ID,
        "name": "東京",
        "region": "東京都",
        "country": "日本",
        "latitude": 35.6895,
        "longitude": 139.69171,
        "timeZoneID": "Asia/Tokyo",
    }
    snapshot = {
        "locationID": TOKYO_ID,
        "fetchedAt": now - 600,
        "timeZoneID": "Asia/Tokyo",
        "utcOffsetSeconds": OFFSET,
        "current": {
            "time": now - 600 - (now - 600) % 900,
            "temperature": 18.4,
            "apparentTemperature": 17.2,
            "humidity": 58,
            "precipitation": 0.0,
            "weatherCode": 2,
            "windSpeed": 12.6,
            "windDirection": 45,
            "isDay": is_day(now),
        },
        "hourly": hourly,
        "daily": daily,
    }
    return {
        "schemaVersion": 1,
        "app": "weather",
        "content": {
            "isNetworkEnabled": False,
            "temperatureUnit": "celsius",
            "windSpeedUnit": "metersPerSecond",
            "locations": [tokyo],
            "selectedLocationID": TOKYO_ID,
            "snapshots": [snapshot],
        },
    }


def main():
    if len(sys.argv) != 2:
        sys.exit("使い方: make-weather-fixture.py <書き出す先>")
    with open(sys.argv[1], "w", encoding="utf-8") as output:
        json.dump(build(int(time.time())), output, ensure_ascii=False, indent=2, sort_keys=True)
        output.write("\n")


if __name__ == "__main__":
    main()
