# フロントエンド開発用 Dockerfile
FROM node:20-alpine

WORKDIR /app

# パッケージファイルをコピーして依存関係をインストール
COPY package.json package-lock.json* ./
RUN npm install

# ソースコードをコピー
COPY . .

# Vite 開発サーバーのポート
EXPOSE 5173

# 開発サーバー起動
CMD ["npm", "run", "dev"]
