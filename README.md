# スケジュール調整ツール

小規模グループ（最大約20名）向けのスケジュール調整ツール。Discord コミュニティでの利用を前提とし、メンバーの参加可否の可視化、活動日の自動・手動設定、Discord Bot および Google カレンダーとの連携を提供する。

## 技術スタック

| レイヤー | 技術 |
|---|---|
| バックエンド | Ruby on Rails 7.1+（API モード）、PostgreSQL 15、Sidekiq、Redis |
| フロントエンド | React 18+、Vite、TypeScript、MUI、Tailwind CSS、TanStack Query |
| Discord Bot | Node.js、discord.js v14+、TypeScript |
| インフラ | Docker Compose（開発）、ConoHa VPS（本番） |

## プロジェクト構成

```
schedule_adjustment/
├── backend/          # Rails API
├── frontend/         # React SPA
├── bot/              # Discord Bot
├── nginx/            # リバースプロキシ設定
├── docker-compose.yml
└── .env.example
```

## セットアップ

### 前提条件

- Docker および Docker Compose がインストールされていること
- ローカルに Ruby や Node.js のランタイムは不要（すべてコンテナ内で実行）

### 環境変数の設定

```bash
cp .env.example .env
```

`.env` を編集し、各値を実際の認証情報に置き換える。開発環境では Discord / Google の認証情報は空でも API サーバーとフロントエンドは起動する。

### 起動

```bash
# 全サービスを起動
docker compose up -d

# ログ確認
docker compose logs -f api
```

起動後のアクセス先:

| サービス | URL |
|---|---|
| フロントエンド（Nginx 経由） | http://localhost |
| フロントエンド（直接） | http://localhost:5173 |
| Rails API（直接） | http://localhost:3000 |
| Sidekiq 管理画面 | http://localhost:3000/sidekiq |

### データベースのセットアップ

```bash
# 開発用 DB の作成・マイグレーション
docker compose exec api bundle exec rails db:create db:migrate

# テスト用 DB の作成・マイグレーション
docker compose exec -e RAILS_ENV=test api bundle exec rails db:create db:migrate
```

### 部分起動

全サービスが不要な場合は、必要なものだけ起動できる。

```bash
# バックエンド関連のみ（テスト実行時など）
docker compose up -d db redis api

# フロントエンドのみ
docker compose up -d frontend
```

## テスト

**重要**: テストは必ず `RAILS_ENV=test` を指定して実行すること。docker-compose の api サービスは `RAILS_ENV=development` で起動しているため、`-e RAILS_ENV=test` を付けないとホスト認証やレート制限でテストが失敗する。

### バックエンド（RSpec）

```bash
# 全テスト実行
docker compose exec -e RAILS_ENV=test api bundle exec rspec

# 特定のファイルを実行
docker compose exec -e RAILS_ENV=test api bundle exec rspec spec/models/user_spec.rb

# 特定のテストを実行（行番号指定）
docker compose exec -e RAILS_ENV=test api bundle exec rspec spec/requests/oauth/google_spec.rb:136

# ドキュメント形式で出力
docker compose exec -e RAILS_ENV=test api bundle exec rspec --format documentation
```

### フロントエンド（Vitest）

```bash
# 全テスト実行
docker compose exec frontend npm test

# ウォッチモード
docker compose exec frontend npm run test:watch
```

### Discord Bot（Jest）

```bash
docker compose exec bot npm test
```

### Lint

```bash
# フロントエンド
docker compose exec frontend npm run lint

# バックエンド（RuboCop がインストール済みの場合）
docker compose exec api bundle exec rubocop
```

## 開発でよく使うコマンド

```bash
# Rails コンソール
docker compose exec api bundle exec rails console

# DB マイグレーション作成
docker compose exec api bundle exec rails generate migration AddColumnToUsers name:string

# DB マイグレーション実行
docker compose exec api bundle exec rails db:migrate

# gem 追加後
docker compose exec api bundle install

# npm パッケージ追加後（フロントエンド）
docker compose exec frontend npm install

# コンテナの再ビルド（Dockerfile 変更時）
docker compose build api
docker compose up -d api

# 全サービス停止
docker compose down

# データも含めて全削除
docker compose down -v
```

## サービス一覧

| サービス | ポート | 説明 |
|---|---|---|
| nginx | 80 | リバースプロキシ（`/api/*` → Rails、`/*` → React） |
| api | 3000 | Rails API サーバー（Puma） |
| sidekiq | — | バックグラウンドジョブ処理 |
| frontend | 5173 | React 開発サーバー（Vite） |
| db | 5432 | PostgreSQL 15 |
| redis | 6379 | Redis（ジョブキュー + キャッシュ） |
| bot | — | Discord Bot |
