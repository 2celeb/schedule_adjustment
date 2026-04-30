# 技術仕様書

## 技術スタック

### バックエンド

| 項目 | 技術 | 理由 |
|---|---|---|
| 言語 | Ruby 3.2+ | ユーザー要件。Rails との親和性 |
| フレームワーク | Ruby on Rails 7.1+（API モード） | ユーザー要件。高速な開発が可能 |
| 認証 | Devise + devise-jwt | JWT ベースの API 認証。SPA との相性が良い |
| データベース | PostgreSQL 15+ | 無料枠が充実。JSON カラム対応で柔軟なデータ保存 |
| バックグラウンドジョブ | Sidekiq + Redis | Google カレンダー同期やリマインダー送信の非同期処理 |
| API 形式 | RESTful JSON API | シンプルで React との連携が容易 |

### フロントエンド

| 項目 | 技術 | 理由 |
|---|---|---|
| フレームワーク | React 18+ | ユーザー要件。コンポーネントベースの UI 構築 |
| ビルドツール | Vite | 高速なビルドと HMR |
| 状態管理 | Zustand または React Query | 軽量でシンプル。サーバー状態管理に適する |
| UI ライブラリ | Tailwind CSS + Headless UI | カスタマイズ性が高く軽量 |
| カレンダー UI | カスタム実装 or react-big-calendar | Availability_Board の要件に合わせて選定 |
| HTTP クライアント | Axios | API 通信の標準ライブラリ |

### 外部連携

| 項目 | 技術 | 理由 |
|---|---|---|
| Google カレンダー | Google Calendar API v3 + OAuth 2.0 | 予定の有無のみ取得（FreeBusy API を活用） |
| Discord | discord.js + Discord Bot API | 通知・リマインダー送信 |
| 広告 | Google AdSense | 導入が容易で小規模サイトにも対応 |

## コンピューティング環境

### 開発環境

- Docker Compose によるローカル開発環境
  - Rails API コンテナ
  - React 開発サーバーコンテナ
  - PostgreSQL コンテナ
  - Redis コンテナ

### 本番環境（低コスト構成）

| コンポーネント | サービス | 月額目安 |
|---|---|---|
| バックエンド | Render.com Free/Starter プラン or Railway | 無料〜$7/月 |
| フロントエンド | Vercel or Cloudflare Pages | 無料 |
| データベース | Render PostgreSQL or Supabase Free | 無料〜$7/月 |
| Redis | Upstash Redis | 無料枠あり |
| Discord Bot | バックエンドと同居 | 追加コストなし |
| ドメイン | お名前.com 等 | 約$10〜15/年 |

**月額合計目安: 無料〜約$15/月**

### スケーリング方針

- 初期は無料枠を最大限活用する
- ユーザー数が増加した場合、Render の有料プランまたは AWS Lightsail へ移行
- 最大20名/グループの小規模利用を前提とし、過度なスケーリング設計は行わない

## データベース設計（概要）

### 主要テーブル

```
users
├── id, email, name, google_oauth_token (暗号化), created_at, updated_at

groups
├── id, name, owner_id (FK: users), invite_code, threshold_n, created_at, updated_at

memberships
├── id, user_id (FK: users), group_id (FK: groups), role (core/sub), created_at

auto_schedule_rules
├── id, group_id (FK: groups), pattern_type, day_of_week, interval, created_at

event_days
├── id, group_id (FK: groups), date, auto_generated (boolean), created_at

availabilities
├── id, user_id (FK: users), group_id (FK: groups), date, status (○/△/×), 
│   comment, auto_synced (boolean), created_at, updated_at

discord_configs
├── id, group_id (FK: groups), server_id, channel_id, bot_token (暗号化), created_at
```

## セキュリティ考慮事項

- Google OAuth トークンは暗号化して保存（Rails の `encrypts` を使用）
- Discord Bot トークンも暗号化して保存
- Google カレンダーの FreeBusy API を使用し、予定の詳細は一切取得・保存しない
- CORS 設定でフロントエンドのドメインのみ許可
- Rate Limiting を導入し API の乱用を防止
- HTTPS を必須とする

## パフォーマンス考慮事項

- Availability_Board のデータはページネーション（月単位）で取得
- Google カレンダーの同期は Sidekiq で非同期実行（15分間隔）
- Redis によるセッションキャッシュと頻繁にアクセスされるデータのキャッシュ
- フロントエンドは React Query でサーバー状態をキャッシュし不要な再取得を防止
