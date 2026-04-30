# 開発環境用 Dockerfile
# Ruby 3.2 ベースイメージ（ホットリロード対応）
FROM ruby:3.2-slim

# 必要なシステムパッケージをインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    libyaml-dev \
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

# tmp ディレクトリを作成（Puma の PID ファイル用）
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log

# ポート 3000 を公開
EXPOSE 3000

# デフォルトコマンド: Puma を直接起動（config.ru を読み込み、全インターフェースでリッスン）
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
