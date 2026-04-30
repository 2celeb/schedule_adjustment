# 開発環境用 Dockerfile
# Ruby 3.2 ベースイメージ（ホットリロード対応）
FROM ruby:3.2-slim

# 必要なシステムパッケージをインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /app

# Bundler の設定
ENV BUNDLE_PATH=/usr/local/bundle

# Gemfile をコピーして依存関係をインストール
COPY Gemfile Gemfile.lock ./
RUN bundle install

# アプリケーションコードをコピー
COPY . .

# ポート 3000 を公開
EXPOSE 3000

# デフォルトコマンド: Rails サーバーを起動（全インターフェースでリッスン、ポート3000）
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
