# 技術仕様書

## 技術スタック

### バックエンド

| 項目 | 技術 | 理由 |
|---|---|---|
| 言語 | Ruby 3.2+ | ユーザー要件。Rails との親和性 |
| フレームワーク | Ruby on Rails 7.1+（API モード） | ユーザー要件。高速な開発が可能 |
| データベース | PostgreSQL 15+ | 無料枠が充実。JSON カラム対応で柔軟なデータ保存 |
| バックグラウンドジョブ | Sidekiq + Redis | 自動確定、リマインド送信、Google カレンダー同期の非同期処理 |
| API 形式 | RESTful JSON API | シンプルで React との連携が容易 |
| スケジューラ | sidekiq-cron | 週次の自動確定、リマインド、当日通知のスケジュール実行 |

> **注意**: Devise / JWT は不要。ゆるい識別方式（Q18）を採用するため、一般メンバーの認証基盤は実装しない。Owner の Discord OAuth と Google OAuth のみサーバー側で管理する。

### フロントエンド

| 項目 | 技術 | 理由 |
|---|---|---|
| フレームワーク | React 18+ | ユーザー要件。コンポーネントベースの UI 構築 |
| ビルドツール | Vite | 高速なビルドと HMR |
| 状態管理 | TanStack Query (React Query) | サーバー状態管理に最適。キャッシュ・再取得の制御が容易 |
| UI ライブラリ | Tailwind CSS + Headless UI | カスタマイズ性が高く軽量。レスポンシブ対応が容易 |
| カレンダー UI | カスタム実装 | Availability_Board の独自要件（集計表示、色分け、メンバー横並び）に対応 |
| HTTP クライアント | Axios | API 通信の標準ライブラリ |
| 国際化 | react-i18next | ロケール設定による記号・テキスト切り替え（Q30） |
| ローカルストレージ | localStorage API | ユーザー選択の記憶（Q18） |

### 外部連携

| 項目 | 技術 | 理由 |
|---|---|---|
| Google カレンダー | Google Calendar API v3 + OAuth 2.0 | FreeBusy API（予定有無の一括取得）+ Calendar API（予定作成・サブカレンダー作成） |
| Discord | discord.js v14+ | Bot 開発。Server Members Intent によるメンバーリスト取得、スラッシュコマンド、通知送信 |
| 広告 | Google AdSense | 導入が容易で小規模サイトにも対応 |

## 認証・識別方式

### 一般メンバー（ゆるい識別方式）

パスワードや OAuth 認証は不要。以下のフローでユーザーを識別する:

1. グループのスケジュールページは共通URL（`/schedule/group/{nanoid}`）
2. ページ上部にメンバー名が横並びで表示
3. ユーザーが自分の名前をクリック/タップ → 入力モードに切り替え
4. 選択したユーザーID を localStorage に保存 → 次回以降は自動選択
5. 別のユーザーへの切り替えはいつでも可能

**変更履歴の記録（抑止力）:**

| 記録項目 | 取得方法 |
|---|---|
| User-Agent（OS / ブラウザ） | リクエストヘッダー |
| 地域情報 | IP アドレスからの GeoIP 推定 |
| 変更日時 | サーバータイムスタンプ |
| 変更内容 | 変更前 → 変更後の差分 |

### Owner（認証あり）

- **Discord OAuth**: Bot 導入時に必須。Discord サーバーの管理者であることを確認
- **Google OAuth（任意）**: Google カレンダー連携時に必要。書き込み権限（`calendar` スコープ）を要求

### メンバーの Google カレンダー連携（任意、メンバー自身が選択）

| 連携パターン | Google OAuth スコープ | 機能 |
|---|---|---|
| 連携なし | 不要 | 手動入力のみ |
| 予定枠のみ | `calendar.freebusy.readonly` | FreeBusy で予定有無を取得 → 自動×設定 |
| 予定枠 + 書き込み | `calendar.freebusy.readonly` + `calendar.events` | 上記 + 活動日確定時に個人カレンダーへ予定作成 |

## コンピューティング環境

### 開発環境

Docker Compose によるローカル開発環境:

```yaml
services:
  api:        # Rails API（ポート 3000）
  frontend:   # React 開発サーバー（ポート 5173）
  db:         # PostgreSQL 15
  redis:      # Redis（Sidekiq + キャッシュ）
  bot:        # Discord Bot（Node.js）
```

### 本番環境（低コスト構成）

| コンポーネント | サービス | 月額目安 |
|---|---|---|
| バックエンド（Rails API） | Render.com Free/Starter | 無料〜$7/月 |
| フロントエンド（React） | Vercel or Cloudflare Pages | 無料 |
| データベース（PostgreSQL） | Render PostgreSQL or Supabase Free | 無料〜$7/月 |
| Redis | Upstash Redis | 無料枠あり |
| Discord Bot | バックエンドと同居 or 別プロセス | 追加コストなし |
| ドメイン | お名前.com 等 | 約 $10〜15/年 |

**月額合計目安: 無料〜約 $15/月**

### スケーリング方針

- 初期は無料枠を最大限活用する
- ユーザー数が増加した場合、Render の有料プランまたは AWS Lightsail へ移行
- 最大20名/グループの小規模利用を前提とし、過度なスケーリング設計は行わない

## データベース設計

### ER 図（概要）

```
users ──< memberships >── groups
  │                         │
  │                         ├──< event_days
  │                         ├──< auto_schedule_rules
  │                         ├──< group_settings
  │                         └──< discord_configs
  │
  └──< availabilities >── groups
         │
         └──< availability_logs（変更履歴）
```

### 主要テーブル

```sql
-- ユーザー（Discord メンバーから自動登録）
users
├── id (PK)
├── discord_user_id (UNIQUE, nullable)     -- Discord ユーザーID
├── discord_screen_name                     -- Discord スクリーン名（元の名前）
├── display_name                            -- 表示名（ユーザーが変更可能）
├── google_oauth_token (暗号化, nullable)   -- Google OAuth トークン
├── google_calendar_scope (nullable)        -- 連携パターン: none / freebusy / full
├── locale (default: 'ja')                  -- ロケール設定
├── anonymized (default: false)             -- 退会時に true
├── created_at, updated_at

-- グループ
groups
├── id (PK)
├── name                                    -- グループ名（デフォルト: Discord サーバー名）
├── event_name                              -- イベント名（デフォルト: "${グループ名}の活動"）
├── owner_id (FK: users)
├── share_token (UNIQUE)                    -- 共通URL用のランダムID（nanoid）
├── timezone (default: 'Asia/Tokyo')
├── default_start_time (TIME)               -- 基本活動開始時間
├── default_end_time (TIME)                 -- 基本活動終了時間
├── threshold_n (integer)                   -- 参加不可人数の閾値
├── threshold_target (default: 'core')      -- 閾値の対象: core / all
├── ad_enabled (default: true)              -- 広告表示 ON/OFF
├── locale (default: 'ja')                  -- グループのロケール（Bot 導入者から初期設定）
├── created_at, updated_at

-- メンバーシップ
memberships
├── id (PK)
├── user_id (FK: users)
├── group_id (FK: groups)
├── role (default: 'sub')                   -- owner / core / sub
├── created_at, updated_at
├── UNIQUE(user_id, group_id)

-- 活動日自動設定ルール
auto_schedule_rules
├── id (PK)
├── group_id (FK: groups)
├── max_days_per_week (integer)             -- 週の最大活動日数
├── min_days_per_week (integer)             -- 週の最低活動日数
├── deprioritized_days (integer[])          -- 優先度を下げる曜日（0=日〜6=土）
├── excluded_days (integer[])               -- 除外曜日
├── week_start_day (integer, default: 1)    -- 週の始まり（0=日〜6=土、デフォルト: 月曜）
├── confirm_days_before (integer, default: 3) -- 確定日（週の始まりのN日前）
├── remind_days_before_confirm (integer, default: 2) -- リマインド開始日（確定日のN日前）
├── confirm_time (TIME, default: '21:00')   -- 確定時刻
├── activity_notify_hours_before (integer, default: 8) -- 活動日当日通知（開始N時間前）
├── activity_notify_channel_id (nullable)   -- 当日通知チャンネル（null の場合はデフォルトチャンネル）
├── activity_notify_message (nullable)      -- 当日通知メッセージ（null の場合はデフォルト）
├── created_at, updated_at

-- 活動日
event_days
├── id (PK)
├── group_id (FK: groups)
├── date (DATE)
├── start_time (TIME, nullable)             -- 個別の活動開始時間（null の場合はグループデフォルト）
├── end_time (TIME, nullable)               -- 個別の活動終了時間
├── auto_generated (boolean)                -- 自動生成か手動設定か
├── confirmed (boolean, default: false)     -- 確定済みか
├── confirmed_at (TIMESTAMP, nullable)
├── created_at, updated_at
├── UNIQUE(group_id, date)

-- 参加可否
availabilities
├── id (PK)
├── user_id (FK: users)
├── group_id (FK: groups)
├── date (DATE)
├── status (integer)                        -- 1=○, 0=△, -1=×, null=未入力(−)
├── comment (TEXT, nullable)
├── auto_synced (boolean, default: false)   -- Google カレンダーから自動設定されたか
├── created_at, updated_at
├── UNIQUE(user_id, group_id, date)

-- 参加可否の変更履歴（抑止力）
availability_logs
├── id (PK)
├── availability_id (FK: availabilities)
├── user_id (FK: users)
├── old_status (integer, nullable)
├── new_status (integer)
├── old_comment (TEXT, nullable)
├── new_comment (TEXT, nullable)
├── user_agent (TEXT)
├── ip_address (INET)
├── geo_region (VARCHAR, nullable)          -- IP から推定した地域（例: 名古屋）
├── created_at

-- Discord 設定
discord_configs
├── id (PK)
├── group_id (FK: groups, UNIQUE)
├── guild_id                                -- Discord サーバーID
├── default_channel_id                      -- デフォルト通知チャンネル
├── remind_channel_id (nullable)            -- リマインド用チャンネル（null の場合はデフォルト）
├── created_at, updated_at

-- Google カレンダーのキャッシュ
calendar_caches
├── id (PK)
├── user_id (FK: users)
├── group_id (FK: groups)
├── date (DATE)
├── has_event (boolean)                     -- 予定の有無のみ
├── fetched_at (TIMESTAMP)                  -- 取得日時（キャッシュ有効期限の判定用）
├── UNIQUE(user_id, group_id, date)
```

## Discord Bot 設計

### 必要な権限

| 権限 | 理由 |
|---|---|
| Send Messages | 通知・リマインド・予定一覧の投稿 |
| View Channels | チャンネルの閲覧 |
| Server Members Intent（特権） | メンバーリストの自動取得（Q27） |
| Guild Members スコープ | メンバーのニックネーム・ユーザー名の読み取り |

### スラッシュコマンド

| コマンド | 説明 | 実行権限 | 備考 |
|---|---|---|---|
| `/schedule` | スケジュールページのURLを表示 | 全員 | 初回設定が未完了の場合は設定フローを開始 |
| `/status` | 今週の予定入力状況を表示 | 全員 | |
| `/settings` | グループ設定画面のURLを表示 | Owner | |

### 自動通知フロー

```
[リマインド開始日（確定日の2日前）]
  └─ 21:00 → チャンネルにメンション（未入力メンバー宛）

[リマインド開始日の翌日]
  └─ 21:00 → まだ未入力のメンバーに DM 送信

[確定日（週の始まりの3日前）]
  └─ 21:00 → 自動確定処理
       ├─ Discord チャンネルに予定一覧を投稿
       ├─ Owner の Google カレンダー（サブカレンダー）に予定追加
       └─ 書き込み連携メンバーの個人カレンダーに予定作成

[活動日当日]
  └─ 活動開始の8時間前 → チャンネルに「本日活動日です」投稿（メンションなし）
```

## Google カレンダー連携設計

### OAuth スコープ

| ユーザー種別 | スコープ | 用途 |
|---|---|---|
| Owner | `https://www.googleapis.com/auth/calendar` | サブカレンダー作成 + 予定書き込み |
| メンバー（読み取りのみ） | `https://www.googleapis.com/auth/calendar.freebusy.readonly` | FreeBusy で予定有無を取得 |
| メンバー（読み書き） | 上記 + `https://www.googleapis.com/auth/calendar.events` | 上記 + 個人カレンダーへの予定作成 |

### FreeBusy 同期フロー

```
ユーザーがスケジュールページを開く
  → サーバーが calendar_caches の fetched_at を確認
  → 15分以上経過している場合:
       → Google カレンダー連携済みメンバー全員分を FreeBusy API で一括取得（1リクエスト）
       → calendar_caches を更新
       → has_event = true の日の Availability_Status を自動的に × に設定
  → 15分以内の場合:
       → キャッシュから返却
  → 「今すぐ同期」ボタン:
       → キャッシュを無視して強制再取得
```

### サブカレンダー作成

```
Owner が Google OAuth で認証
  → Google Calendar API の calendars.insert で新しいカレンダーを作成
  → カレンダー名: "[グループ名] イベント"
  → カレンダーID をサーバーに保存
  → 活動日確定時にこのカレンダーに予定を追加
```

## 国際化（i18n）設計

### Availability_Status の表示

| 内部値 | 日本語（ja） | 英語（en） | 色 |
|---|---|---|---|
| 1 | ○ | ✓ | 緑 (#22c55e) |
| 0 | △ | ? | 黄 (#eab308) |
| -1 | × | ✗ | 赤 (#ef4444) |
| null | − | − | グレー (#9ca3af) |

> **注意**: ◎ と ✓✓ は不採用（Q30）

- 初期ロケールは Bot 導入者のロケールから自動設定
- グループ設定画面で後から変更可能
- 内部データは数値で管理し、表示はロケールに応じて切り替え

## セキュリティ考慮事項

- Google OAuth トークンは暗号化して保存（Rails の `encrypts` を使用）
- Google カレンダーの FreeBusy API を使用し、予定の詳細は一切取得・保存しない
- calendar_caches には予定の有無（boolean）のみ保存
- CORS 設定でフロントエンドのドメインのみ許可
- Rate Limiting を導入し API の乱用を防止（rack-attack）
- HTTPS を必須とする
- グループの共通URL は nanoid（推測困難なランダム文字列）を使用
- Owner に URL の再生成（リセット）機能を提供
- 退会メンバーのデータは匿名化（個人情報は即時削除、Availability データは無期限保持）
- 匿名化データは Owner のみ閲覧可能

## パフォーマンス考慮事項

- Availability_Board のデータはページネーション（月単位）で取得
- Google カレンダーの FreeBusy 結果は Redis でキャッシュ（15分 TTL）
- Sidekiq で非同期処理: 自動確定、リマインド送信、Google カレンダー書き込み
- フロントエンドは TanStack Query でサーバー状態をキャッシュし不要な再取得を防止
- FreeBusy API は1リクエストで20人分を一括取得（API 無料枠: 100万リクエスト/日）
