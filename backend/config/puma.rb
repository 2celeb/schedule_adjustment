# Puma アプリケーションサーバー設定

# スレッド数の設定
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# ワーカー数（本番環境のみ）
workers ENV.fetch("WEB_CONCURRENCY") { 2 } if ENV["RAILS_ENV"] == "production"

# ポート設定
port ENV.fetch("PORT") { 3000 }

# 環境設定
environment ENV.fetch("RAILS_ENV") { "development" }

# PID ファイル
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# プリロード（本番環境のみ）
preload_app! if ENV["RAILS_ENV"] == "production"

# プラグイン
plugin :tmp_restart
