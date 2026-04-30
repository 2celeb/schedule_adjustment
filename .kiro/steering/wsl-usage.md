# WSL コマンドの使用制限

## 基本方針

- `wsl` コマンドを必要以上に使わないこと
- シェルが `bash`（Git Bash）の場合、`sed` や `grep` などの UNIX コマンドはそのまま使用可能
- `wsl sed` や `wsl grep` のように `wsl` を前置する必要はない
- Docker コマンド（`docker compose exec` 等）もホストの bash から直接実行すること
