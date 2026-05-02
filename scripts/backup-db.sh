#!/bin/bash
# PostgreSQL バックアップスクリプト
# cron で毎日実行し、デイリー（7日分）+ ウィークリー（4週分）を保持する
#
# 使用方法:
#   ./scripts/backup-db.sh
#
# crontab 設定例:
#   0 3 * * * /opt/schedule-adjustment/scripts/backup-db.sh >> /var/log/db-backup.log 2>&1

set -euo pipefail

# 設定
BACKUP_DIR="${BACKUP_DIR:-/var/backups/schedule-adjustment}"
DAILY_DIR="${BACKUP_DIR}/daily"
WEEKLY_DIR="${BACKUP_DIR}/weekly"
DAILY_RETENTION=7
WEEKLY_RETENTION=4
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DAY_OF_WEEK=$(date +%u)  # 1=月曜 ... 7=日曜

# Docker Compose のプロジェクトディレクトリ
PROJECT_DIR="${PROJECT_DIR:-/opt/schedule-adjustment}"

# バックアップディレクトリの作成
mkdir -p "${DAILY_DIR}" "${WEEKLY_DIR}"

echo "[$(date)] バックアップ開始"

# pg_dump を Docker コンテナ内で実行
BACKUP_FILE="${DAILY_DIR}/schedule_prod_${TIMESTAMP}.sql.gz"

docker compose -f "${PROJECT_DIR}/docker-compose.prod.yml" exec -T db \
    pg_dump -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-schedule_prod}" \
    --no-owner --no-privileges --clean --if-exists \
    | gzip > "${BACKUP_FILE}"

if [ $? -eq 0 ] && [ -s "${BACKUP_FILE}" ]; then
    echo "[$(date)] デイリーバックアップ完了: ${BACKUP_FILE}"
    echo "[$(date)] ファイルサイズ: $(du -h "${BACKUP_FILE}" | cut -f1)"
else
    echo "[$(date)] エラー: バックアップに失敗しました" >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi

# 日曜日（7）にウィークリーバックアップをコピー
if [ "${DAY_OF_WEEK}" -eq 7 ]; then
    WEEKLY_FILE="${WEEKLY_DIR}/schedule_prod_weekly_${TIMESTAMP}.sql.gz"
    cp "${BACKUP_FILE}" "${WEEKLY_FILE}"
    echo "[$(date)] ウィークリーバックアップ作成: ${WEEKLY_FILE}"
fi

# 古いデイリーバックアップの削除（7日分を保持）
find "${DAILY_DIR}" -name "schedule_prod_*.sql.gz" -mtime +${DAILY_RETENTION} -delete
DAILY_COUNT=$(find "${DAILY_DIR}" -name "schedule_prod_*.sql.gz" | wc -l)
echo "[$(date)] デイリーバックアップ保持数: ${DAILY_COUNT}"

# 古いウィークリーバックアップの削除（4週分を保持）
WEEKLY_RETENTION_DAYS=$((WEEKLY_RETENTION * 7))
find "${WEEKLY_DIR}" -name "schedule_prod_weekly_*.sql.gz" -mtime +${WEEKLY_RETENTION_DAYS} -delete
WEEKLY_COUNT=$(find "${WEEKLY_DIR}" -name "schedule_prod_weekly_*.sql.gz" | wc -l)
echo "[$(date)] ウィークリーバックアップ保持数: ${WEEKLY_COUNT}"

echo "[$(date)] バックアップ完了"
