#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

log() { echo "[backup-db] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
die() { echo "[backup-db] $(date '+%Y-%m-%d %H:%M:%S') - ERRO: $1" >&2; exit 1; }

CONF_FILE="/etc/db-backup.conf"
if [[ ! -f "$CONF_FILE" ]]; then
  die "Arquivo de config não encontrado: $CONF_FILE"
fi
source "$CONF_FILE"

# Normaliza BACKUP_DIR removendo barra no final para evitar // nos paths
BACKUP_DIR="${BACKUP_DIR%/}"

mkdir -p "$BACKUP_DIR"
# Garante que o usuário postgres tenha permissão de escrita no diretório de backup
if ! sudo -u postgres bash -c "test -w '$BACKUP_DIR'" 2>/dev/null; then
  log "Ajustando permissões de $BACKUP_DIR para o usuário postgres..."
  # Tenta ajustar; se não conseguir, aborta
  (chown postgres:postgres "$BACKUP_DIR" && chmod 0770 "$BACKUP_DIR") || true
  if ! sudo -u postgres bash -c "test -w '$BACKUP_DIR'" 2>/dev/null; then
    die "Usuário postgres não tem permissão de escrita em $BACKUP_DIR"
  fi
fi
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

# Confirma que o arquivo foi realmente criado e não está vazio antes de prosseguir
if [[ ! -s "$BACKUP_FILE" ]]; then
  die "Arquivo de dump não foi criado ou está vazio: $BACKUP_FILE"
fi

# Retenção local: 7 dias
find "$BACKUP_DIR" -type f -name "${PROJECT_NAME}-${ENVIRONMENT}-*.dump" -mtime +7 -print -delete || true

S3_PATH="s3://${AWS_BUCKET}/backups/daily/${FILENAME}"
log "Enviando para o S3: $S3_PATH ..."
aws s3 cp "$BACKUP_FILE" "$S3_PATH"
log "Upload concluído: $S3_PATH"

exit 0
