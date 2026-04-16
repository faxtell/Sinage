# Apple Business Manager CSV自動登録 AppleScript

`Apple Business Manager` のユーザー作成フォームに対して、CSVの各行を順次入力して保存する AppleScript です。

## ファイル
- `scripts/abm_csv_register.applescript`

## 事前準備
1. macOS の「スクリプトエディタ」または `osascript` が使えること
2. Safari で Apple Business Manager にサインインできること
3. macOS のオートメーション権限で、スクリプト実行元から Safari 制御を許可すること
4. スクリプト先頭の `scriptConfig` にある CSS セレクタを、実際の ABM 画面 DOM に合わせること

## 対応CSV
- 1行目: ヘッダー
- 2行目以降: データ
- 必須ヘッダー: `first_name`, `last_name`, `email`, `managed_apple_id`
- 任意ヘッダー: `role`, `location`, `department`, `job_title`

### サンプル
```csv
first_name,last_name,email,managed_apple_id,role,location,department,job_title
Taro,Yamada,taro.yamada@example.com,taro.yamada@example.appleid.com,Staff,Tokyo,Sales,Manager
Hanako,Sato,hanako.sato@example.com,hanako.sato@example.appleid.com,Staff,Osaka,HR,Specialist
```

## 実行方法
```bash
osascript scripts/abm_csv_register.applescript
```

実行後にCSVファイル選択ダイアログが表示されるので、対象CSVを選択してください。
