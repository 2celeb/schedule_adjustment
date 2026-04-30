# Discord Bot 開発用 Dockerfile
FROM node:20-alpine

WORKDIR /app

# パッケージファイルをコピーして依存関係をインストール
COPY package.json package-lock.json* ./
RUN npm install 2>/dev/null || true

# ソースコードをコピー
COPY . .

# Bot 起動（プレースホルダー: タスク 11 で TypeScript ビルド設定を追加）
CMD ["node", "src/index.js"]
