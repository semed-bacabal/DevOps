#!/bin/bash

log() { echo "[backup-db] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

CONF_FILE="/etc/db-backup.conf"
if [[ ! -f "$CONF_FILE" ]]; then
  log "Arquivo de config não encontrado: $CONF_FILE" >&2
  exit 1
fi
source "$CONF_FILE"

mkdir -p "$BACKUP_DIR"
TS=$(date +%F-%H%M%S)
FILENAME="${PROJECT_NAME}-${ENVIRONMENT}-${DB_NAME}-${TS}.dump"
BACKUP_FILE="$BACKUP_DIR/$FILENAME"

EXCLUDES=()
if [[ "$PROJECT_NAME" == "i-diario" ]]; then
  EXCLUDES+=(public.entities public.ieducar_api_configurations public.ieducar_api_synchronizations public.ieducar_api_exam_postings)
fi

log "Iniciando pg_dump (${PROJECT_NAME})..."
DUMP_CMD=(sudo -u postgres pg_dump -U postgres -F c -d "$DB_NAME" -f "$BACKUP_FILE")
for tbl in "${EXCLUDES[@]}"; do
  DUMP_CMD+=(--exclude-table="$tbl")
done
"${DUMP_CMD[@]}"
log "Dump salvo em $BACKUP_FILE"

# Retenção local: 7 dias
find "$BACKUP_DIR" -type f -name "${PROJECT_NAME}-${ENVIRONMENT}-*.dump" -mtime +7 -print -delete || true

S3_KEY="s3://${AWS_BUCKET}/backups/${PROJECT_NAME}/${ENVIRONMENT}/daily/${FILENAME}"
log "Enviando para o S3: $S3_KEY ..."
aws s3 cp "$BACKUP_FILE" "$S3_KEY"

exit 0
