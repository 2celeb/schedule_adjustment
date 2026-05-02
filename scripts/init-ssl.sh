#!/bin/bash
# SSL 証明書の初回取得スクリプト
# Let's Encrypt + certbot で SSL 証明書を取得する
#
# 使用方法:
#   SERVER_NAME=example.com EMAIL=admin@example.com ./scripts/init-ssl.sh
#
# 前提条件:
#   - DNS の A レコードがサーバーの IP アドレスを指していること
#   - ポート 80 が開放されていること

set -euo pipefail

SERVER_NAME="${SERVER_NAME:?SERVER_NAME 環境変数を設定してください}"
EMAIL="${EMAIL:?EMAIL 環境変数を設定してください}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "[$(date)] SSL 証明書の初回取得を開始します"
echo "  ドメイン: ${SERVER_NAME}"
echo "  メール: ${EMAIL}"

# certbot 用ディレクトリの作成
mkdir -p "${PROJECT_DIR}/certbot/conf"
mkdir -p "${PROJECT_DIR}/certbot/www"

# 一時的な Nginx 設定で HTTP チャレンジに対応
# （SSL 証明書がまだない状態で起動するため）
cat > "${PROJECT_DIR}/nginx/nginx.init-ssl.conf" << 'NGINX_CONF'
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name _;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 200 'SSL certificate initialization in progress...';
            add_header Content-Type text/plain;
        }
    }
}
NGINX_CONF

echo "[$(date)] 一時 Nginx を起動中..."

# 一時的な Nginx コンテナを起動
docker run -d --name nginx-init-ssl \
    -p 80:80 \
    -v "${PROJECT_DIR}/nginx/nginx.init-ssl.conf:/etc/nginx/nginx.conf:ro" \
    -v "${PROJECT_DIR}/certbot/www:/var/www/certbot" \
    nginx:1.25-alpine

echo "[$(date)] certbot で証明書を取得中..."

# certbot で証明書を取得
docker run --rm \
    -v "${PROJECT_DIR}/certbot/conf:/etc/letsencrypt" \
    -v "${PROJECT_DIR}/certbot/www:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    -d "${SERVER_NAME}"

# 一時 Nginx を停止・削除
docker stop nginx-init-ssl
docker rm nginx-init-ssl
rm -f "${PROJECT_DIR}/nginx/nginx.init-ssl.conf"

echo "[$(date)] SSL 証明書の取得が完了しました"
echo "  証明書: ${PROJECT_DIR}/certbot/conf/live/${SERVER_NAME}/fullchain.pem"
echo "  秘密鍵: ${PROJECT_DIR}/certbot/conf/live/${SERVER_NAME}/privkey.pem"
echo ""
echo "次のステップ:"
echo "  1. .env.prod の SERVER_NAME を設定"
echo "  2. docker compose -f docker-compose.prod.yml up -d"
