#!/bin/bash
# Script de configuração comum para as aplicações i-educar/i-diario

log() {
    echo "ℹ️  [$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    echo "❌  [$(date '+%Y-%m-%d %H:%M:%S')] $1"
    exit 1
}

log "Iniciando configurações comuns para as aplicações i-educar/i-diario..."

log "Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo

log "Instalando CloudWatch Agent..."
AGENT_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/${ARCH}/latest/amazon-cloudwatch-agent.deb"
if ! wget -q "$AGENT_URL"; then
    error_exit "Falha ao baixar o CloudWatch Agent ($ARCH)."
fi
if ! dpkg -i -E ./amazon-cloudwatch-agent.deb; then
    error_exit "Falha ao instalar o CloudWatch Agent ($ARCH)."
fi
rm -f ./amazon-cloudwatch-agent.deb

log "Atualizando sistema e instalando dependências básicas..."
if ! apt update; then
    error_exit "Falha ao atualizar os pacotes."
fi
if ! apt install -y git jq awscli; then
    error_exit "Falha ao instalar dependências (git, jq, awscli)."
fi
aws configure set region "$AWS_REGION" || error_exit "Falha ao configurar a região AWS."

log "Preparando variáveis de ambiente..."
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text | jq -r '.password') || error_exit "Falha ao obter DB_PASSWORD."
export S3_SECRET=$(aws secretsmanager get-secret-value --secret-id "$S3_SECRET_ARN" --query SecretString --output text) || error_exit "Falha ao obter S3_SECRET."
export AWS_ACCESS_KEY_ID=$(echo "$S3_SECRET" | jq -r '.AWS_ACCESS_KEY_ID') || error_exit "Falha ao extrair AWS_ACCESS_KEY_ID."
export AWS_SECRET_ACCESS_KEY=$(echo "$S3_SECRET" | jq -r '.AWS_SECRET_ACCESS_KEY') || error_exit "Falha ao extrair AWS_SECRET_ACCESS_KEY."
export AWS_DEFAULT_REGION=$(echo "$S3_SECRET" | jq -r '.AWS_DEFAULT_REGION') || error_exit "Falha ao extrair AWS_DEFAULT_REGION."
export AWS_BUCKET=$(echo "$S3_SECRET" | jq -r '.AWS_BUCKET') || error_exit "Falha ao extrair AWS_BUCKET."

check_postgres() {
    log "Aguardando PostgreSQL ficar disponível..."
    local max_attempts=10
    local attempt=1
    local wait_time=30
    while ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; do
    log "PostgreSQL ainda não está disponível. Tentativa $attempt/$max_attempts. Aguardando $wait_time segundos..."
    if [ $attempt -ge $max_attempts ]; then
        error_exit "PostgreSQL não ficou disponível após $max_attempts tentativas!"
    fi
    sleep "$wait_time"
    attempt=$((attempt + 1))
    done
    log "PostgreSQL está disponível!"
}

log "Configurações comuns concluídas!"
