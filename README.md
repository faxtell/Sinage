# Earthquake Overlay Watcher (Windows)

日本国内で **震度2以上** の地震を検知したら、指定ページを Edge のフルスクリーンで表示し、落ち着いたら自動で閉じる PowerShell スクリプトです。

- 表示URL: https://kotoho7.github.io/scratch-realtime-earthquake-viewer-page/
- 連続して地震が発生した場合: 表示時間を自動延長

## 動作要件

- Windows
- PowerShell 5.1+（または PowerShell 7）
- Microsoft Edge（`msedge.exe` が実行可能であること）

## 使い方

PowerShell で以下を実行してください。

```powershell
powershell -ExecutionPolicy Bypass -File .\quake_overlay.ps1
```

### オプション

```powershell
powershell -ExecutionPolicy Bypass -File .\quake_overlay.ps1 -PollIntervalSec 5 -BaseDisplaySec 180
```

- `PollIntervalSec`: 地震情報の取得間隔（秒）
- `BaseDisplaySec`: 震度2以上検知後の基本表示時間（秒）

## 仕組み

- `https://api.p2pquake.net/v2/history?codes=551&limit=1` をポーリング
- 最新イベントIDが更新されたときだけ評価
- 震度2以上（`maxScale >= 20`）かつ国内イベントと判定した場合に表示
- 表示中にさらに地震を検知したら `hideAt` を延長
- 落ち着いたら Edge プロセスを自動終了して非表示化

## 注意

- APIまたはネットワークの一時障害時は警告ログを出しつつ監視を継続します。
- 強制終了は `Ctrl + C`。
