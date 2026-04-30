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

> **注意**: Devise / JWT は不要。ゆるい識別方式（Q18）を採用し、Google/Discord 連携ユーザーのみ Cookie ベースのセッション管理を行う（Q40/Q41）。

### フロントエンド

| 項目 | 技術 | 理由 |
|---|---|---|
| フレームワーク | React 18+ | ユーザー要件。コンポーネントベースの UI 構築 |
| ビルドツール | Vite | 高速なビルドと HMR |
| 状態管理 | TanStack Query (React Query) | サーバー状態管理に最適。キャッシュ・再取得の制御が容易 |
| UI ライブラリ | Material UI (MUI) + Tailwind CSS | MUI: 豊富なコンポーネント（Table、Tooltip、Dialog、Chip 等）で開発速度向上。Tailwind: レイアウト微調整に使用 |
| カレンダー UI | カスタム実装 | Availability_Board の独自要件（集計表示、色分け、メンバー横並び）に対応 |
| HTTP クライアント | Axios | API 通信の標準ライブラリ |
| 国際化 | react-i18next | ロケール設定による記号・テキスト切り替え（Q30） |
| ローカルストレージ | localStorage API | ゆるい識別ユーザーの記憶（Q18） |

### 外部連携

| 項目 | 技術 | 理由 |
|---|---|---|
| Google カレンダー | Google Calendar API v3 + OAuth 2.0 | FreeBusy API（予定有無の一括取得）+ Calendar API（予定作成・サブカレンダー作成） |
| Discord | discord.js v14+ | Bot 開発。Server Members Intent によるメンバーリスト取得、スラッシュコマンド、通知送信 |
| 広告 | Google AdSense | 導入が容易で小規模サイトにも対応 |

## 認証・識別方式（2層構造）

認証レベルに応じた2層構造を採用する（Q40/Q41）。

### 認証レベル一覧

| レベル | 識別方法 | 対象 | デバイス間共有 | UI 表示 |
|---|---|---|---|---|
| ゆるい識別 | localStorage のみ | Google 未連携メンバー | 不可（デバイスごとに選択） | 名前のみ |
| OAuth 識別 | HttpOnly Secure Cookie | Google 連携メンバー / Owner | 可（再認証で紐付け） | 名前 + 🔒 |

### ゆるい識別（Google 未連携メンバー）

パスワードや OAuth 認証は不要。以下のフローでユーザーを識別する:

1. グループのスケジュールページは共通URL（`/schedule/group/{nanoid}`）
2. ページ上部にメンバー名が横並びで表示
3. ユーザーが自分の名前をクリック/タップ → 入力モードに切り替え
4. 選択したユーザーID を localStorage に保存 → 次回以降は自動選択
5. 別のユーザーへの切り替えはいつでも可能

### OAuth 識別（Google 連携メンバー / Owner）

Google 連携した時点で、そのユーザーは「ゆるい識別」から卒業し、Google アカウントが本人確認の鍵になる。

**UI の変化:**
- Google 連携済みメンバー: 名前の横に 🔒 アイコン表示
- 🔒 付きユーザーをクリック → 「Google でログイン」ボタンが表示
- Google 認証に成功した場合のみ操作可能

**フロー例（えれんさん）:**
```
1. PC: 「えれん」を選択（ゆるい識別）→ 予定入力可能
2. PC: Google 連携ボタンを押す → Google アカウント A で認証
   → users[42] に Google A を紐付け、Cookie 発行
   → 以降「えれん」は 🔒 付き表示になる
3. モバイル: 「えれん 🔒」をタップ → 「Google でログイン」画面
4. モバイル: Google アカウント A で認証 → OK、Cookie 発行
5. モバイル: Google アカウント B で認証 → エラー「別のGoogleアカウントで連携済みです」
```

**ルール:**
- 1つの users レコードに紐付く Google アカウントは1つだけ（`google_account_id` に UNIQUE 制約）
- 連携済みユーザーに対して別の Google アカウントで認証 → エラー表示
- Google 連携の解除: 本人（設定画面）または Owner（管理画面から強制解除）
- 連携解除時: Google OAuth トークンと予定枠キャッシュ（calendar_caches）を削除し、ゆるい識別に戻る

**Cookie の仕様:**
- HttpOnly: JavaScript からアクセス不可（XSS 対策）
- Secure: HTTPS 通信のみ
- SameSite=Lax: CSRF 対策
- 有効期限: 30日（アクセス時に自動延長）
- セッショントークンはサーバー側で生成し、DB に保存

**識別の優先順位:**
1. Cookie がある場合 → Cookie のセッションからユーザーを特定（最優先）
2. Cookie がない場合 → localStorage の selectedUserId を使用（ゆるい識別）
3. 🔒 付きユーザーを localStorage で選択した場合 → 「Google でログイン」ボタンを表示

### Owner（Discord OAuth + Google OAuth）

- **Discord OAuth**: Bot 導入時に必須。Discord サーバーの管理者であることを確認。🔒 付き
- **Google OAuth（任意）**: Google カレンダー連携時に必要。書き込み権限（`calendar` スコープ）を要求
- 管理機能へのアクセスは Cookie（Discord OAuth セッション）で認証
- 別デバイスでも同じ Discord アカウントで再認証すれば OK

### メンバーの Google カレンダー連携（任意、メンバー自身が選択）

| 連携パターン | Google OAuth スコープ | 機能 | 認証レベル |
|---|---|---|---|
| 連携なし | 不要 | 手動入力のみ | ゆるい識別 |
| 予定枠のみ | `calendar.freebusy.readonly` | FreeBusy で予定有無を取得 → 自動×設定 | OAuth 識別（🔒） |
| 予定枠 + 書き込み | `calendar.freebusy.readonly` + `calendar.events` | 上記 + 活動日確定時に個人カレンダーへ予定作成 | OAuth 識別（🔒） |

### 変更履歴の記録（抑止力、全ユーザー共通）

| 記録項目 | 取得方法 |
|---|---|
| User-Agent（OS / ブラウザ） | リクエストヘッダー |
| 地域情報 | IP アドレスからの GeoIP 推定 |
| 変更日時 | サーバータイムスタンプ |
| 変更内容 | 変更前 → 変更後の差分 |

## コンピューティング環境

### 開発環境

Docker Compose によるローカル開発環境:

```yaml
services:
  nginx:      # リバースプロキシ（ポート 80/443）
  api:        # Rails API（ポート 3000）
  sidekiq:    # Sidekiq ワーカー
  frontend:   # React 開発サーバー（ポート 5173）
  db:         # PostgreSQL 15
  redis:      # Redis（Sidekiq + キャッシュ）
  bot:        # Discord Bot（Node.js）
```

### 本番環境（ConoHa VPS）

ConoHa VPS 1台に全コンポーネントを Docker Compose で構築する。

**アーキテクチャ:**

```
[インターネット]
    │
    ▼
[ConoHa VPS（Docker Compose）]
    │
    ├── Nginx（リバースプロキシ + SSL終端 + 静的ファイル配信）
    │     ├── /api/*  → Rails API コンテナ
    │     └── /*      → React ビルド済み静的ファイル
    │
    ├── Rails API コンテナ（Puma）
    ├── Sidekiq コンテナ（バックグラウンドジョブ）
    ├── Discord Bot コンテナ（Node.js / discord.js）
    ├── PostgreSQL コンテナ（データ永続化: Docker Volume）
    └── Redis コンテナ（キャッシュ + ジョブキュー）
```

**プラン別構成と負荷見積もり:**

| フェーズ | グループ数 | ConoHa プラン | スペック | 月額 |
|---|---|---|---|---|
| 初期 | 〜50 | 2GB | 3コア / 2GB RAM / 100GB SSD | 1,259円 |
| 成長期 | 50〜500 | 4GB | 4コア / 4GB RAM / 100GB SSD | 2,408円 |
| 拡大期 | 500〜1000 | 12GB | 6コア / 12GB RAM / 100GB SSD | 4,828円 |

**初期構成（2GB プラン）のメモリ配分:**

| コンポーネント | メモリ使用量（目安） |
|---|---|
| Nginx | 約30MB |
| Rails API（Puma 2ワーカー） | 約300MB |
| Sidekiq（1プロセス） | 約150MB |
| Discord Bot（Node.js） | 約100MB |
| PostgreSQL | 約200MB |
| Redis | 約50MB |
| OS + その他 | 約200MB |
| **合計** | **約1,030MB / 2,048MB** |

### SSL/TLS

- Let's Encrypt + certbot で無料 SSL 証明書を取得
- certbot の自動更新を cron で設定（90日ごとに自動更新）
- Nginx で SSL 終端

### デプロイフロー

```
開発者が main ブランチに push
  → GitHub Actions が起動
  → テスト実行（RSpec, Jest, ESLint）
  → テスト通過後、SSH 経由で ConoHa VPS にデプロイ:
       1. git pull
       2. docker compose build
       3. docker compose up -d
       4. docker compose exec api rails db:migrate（必要な場合）
```

### バックアップ

- **PostgreSQL**: cron + pg_dump で毎日バックアップ（ローカル保存 + 外部ストレージ）
- **保持期間**: 直近7日分のデイリーバックアップ + 直近4週分のウィークリーバックアップ
- **リストア手順**: pg_restore でバックアップファイルから復元

### 監視

- **死活監視**: Uptime Kuma（Docker コンテナとして同居、または外部サービス）
- **ログ**: Docker のログドライバーで集約。logrotate で肥大化防止
- **アラート**: Uptime Kuma → Discord Webhook でダウン時に通知
- **リソース監視**: htop / docker stats で手動確認。必要に応じて Prometheus + Grafana を追加

### セキュリティ（VPS 固有）

- UFW（ファイアウォール）で 80/443/SSH のみ開放
- SSH は鍵認証のみ（パスワード認証無効化）
- fail2ban で SSH ブルートフォース対策
- Docker コンテナは非 root ユーザーで実行
- 定期的な OS セキュリティアップデート（unattended-upgrades）

### スケールアップ方針

- ConoHa VPS のプラン変更はコントロールパネルから実行可能（サーバー停止 → プラン変更 → 再起動）
- Docker Compose 構成のため、プラン変更後の再構築は不要
- まとめトク契約中のプラン変更制約に注意（上位プランへの変更は可能、下位への変更は契約期間終了後）
- 将来的にサーバー分離が必要になった場合は、DB を別 VPS に分離するのが最初のステップ

### リポジトリ構成（モノレポ）

```
schedule-adjustment/
├── backend/          # Ruby on Rails API
│   ├── Dockerfile
│   ├── Gemfile
│   └── ...
├── frontend/         # React + Vite
│   ├── Dockerfile
│   ├── package.json
│   └── ...
├── bot/              # Discord Bot（Node.js）
│   ├── Dockerfile
│   ├── package.json
│   └── ...
├── nginx/            # Nginx 設定
│   └── nginx.conf
├── docker-compose.yml
├── docker-compose.prod.yml
├── .github/
│   └── workflows/
│       ├── ci.yml    # テスト・Lint
│       └── deploy.yml # 自動デプロイ
└── doc/              # ドキュメント
    ├── plan.md
    ├── tech.md
    └── qa.md
```

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
├── google_account_id (UNIQUE, nullable)    -- Google アカウントID（連携時に設定）
├── google_oauth_token (暗号化, nullable)   -- Google OAuth トークン
├── google_calendar_scope (nullable)        -- 連携パターン: none / freebusy / full
├── auth_locked (default: false)            -- true = OAuth 識別（🔒）、false = ゆるい識別
├── locale (default: 'ja')                  -- ロケール設定
├── anonymized (default: false)             -- 退会時に true
├── created_at, updated_at

-- セッション（OAuth 識別ユーザー用）
sessions
├── id (PK)
├── user_id (FK: users)
├── token (UNIQUE)                          -- セッショントークン（Cookie に保存）
├── expires_at (TIMESTAMP)                  -- 有効期限（30日、アクセス時に延長）
├── user_agent (TEXT, nullable)
├── ip_address (INET, nullable)
├── created_at

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
