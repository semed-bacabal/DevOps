#!/bin/bash
log() { echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

log "Iniciando configurações comuns para as aplicações i-educar/i-diario..."

log "Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo

log "Atualizando sistema e instalando dependências básicas..."
apt update
apt install -y git jq awscli
aws configure set region "$AWS_REGION"

log "Preparando variáveis de ambiente..."
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text | jq -r '.password')
export S3_SECRET=$(aws secretsmanager get-secret-value --secret-id "$S3_SECRET_ARN" --query SecretString --output text)
export AWS_ACCESS_KEY_ID=$(echo "$S3_SECRET" | jq -r '.AWS_ACCESS_KEY_ID')
export AWS_SECRET_ACCESS_KEY=$(echo "$S3_SECRET" | jq -r '.AWS_SECRET_ACCESS_KEY')
export AWS_DEFAULT_REGION=$(echo "$S3_SECRET" | jq -r '.AWS_DEFAULT_REGION')
export AWS_BUCKET=$(echo "$S3_SECRET" | jq -r '.AWS_BUCKET')

check_postgres() {
    log "Aguardando PostgreSQL ficar disponível..."
    for attempt in {1..10}; do
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1 && {
            log "PostgreSQL está disponível!"
            return 0
        }
        log "PostgreSQL ainda não está disponível. Tentativa $attempt/10. Aguardando 30 segundos..."
        sleep 30
    done
    log "PostgreSQL não ficou disponível após 10 tentativas!"
    exit 1
}

log "Configurações comuns concluídas!"
