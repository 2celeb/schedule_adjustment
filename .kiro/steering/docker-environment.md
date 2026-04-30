---
inclusion: always
---

# Docker 開発環境ルール

## 基本方針

- 本プロジェクトの全サービスは Docker Compose で動作する
- ローカル環境に Ruby、Node.js 等のランタイムが入っていることを前提としない
- テスト、ビルド、マイグレーション等のコマンドは **必ず Docker コンテナ経由で実行する**

## コマンド実行ルール

### バックエンド（Rails）

```bash
# RSpec テスト実行
docker compose exec api bundle exec rspec

# 特定のテストファイル実行
docker compose exec api bundle exec rspec spec/models/user_spec.rb

# DB マイグレーション
docker compose exec api bundle exec rails db:migrate

# テスト用 DB セットアップ
docker compose exec api bundle exec rails db:create db:migrate RAILS_ENV=test

# Rails コンソール
docker compose exec api bundle exec rails console

# Bundler（gem 追加後）
docker compose exec api bundle install
```

### フロントエンド（React）

```bash
# テスト実行
docker compose exec frontend npm test

# ビルド
docker compose exec frontend npm run build

# Lint
docker compose exec frontend npm run lint

# パッケージインストール
docker compose exec frontend npm install
```

### Discord Bot（Node.js）

```bash
# テスト実行
docker compose exec bot npm test

# パッケージインストール
docker compose exec bot npm install
```

## コンテナ起動

```bash
# 全サービス起動
docker compose up -d

# バックエンド関連のみ起動（テスト実行時など）
docker compose up -d db redis api

# ログ確認
docker compose logs -f api
```

## 禁止事項

- `bundle exec rspec` をホスト側で直接実行しない
- `npm test` や `npm run build` をホスト側で直接実行しない
- `rails db:migrate` をホスト側で直接実行しない
- コンテナが起動していない状態でテストを実行しない（先に `docker compose up -d` で起動すること）
