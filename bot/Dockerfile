# Discord Bot 開発用 Dockerfile
FROM node:20-alpine

WORKDIR /app

# パッケージファイルをコピーして依存関係をインストール
COPY package.json package-lock.json* ./
RUN npm install 2>/dev/null || true

# ソースコードをコピー
COPY . .

# TypeScript をビルドして起動
CMD ["sh", "-c", "npm run build && npm start"]
