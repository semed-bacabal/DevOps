#!/bin/bash

# Script de configuração comum para as aplicações i-educar/i-diario
# Este script realiza configurações básicas necessárias para ambas as aplicações

echo "[Common Setup] Iniciando configurações comuns..."
echo "[UserData] Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo
echo "[UserData] Instalando CloudWatch Agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
echo "[UserData] Preparando variáveis de ambiente..."
apt update
apt install -y git jq awscli
aws configure set region $AWS_REGION
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text | jq -r '.password')
export S3_SECRET=$(aws secretsmanager get-secret-value --secret-id "$S3_SECRET_ARN" --query SecretString --output text)
export AWS_ACCESS_KEY_ID=$(echo "$S3_SECRET" | jq -r '.AWS_ACCESS_KEY_ID')
export AWS_SECRET_ACCESS_KEY=$(echo "$S3_SECRET" | jq -r '.AWS_SECRET_ACCESS_KEY')
export AWS_DEFAULT_REGION=$(echo "$S3_SECRET" | jq -r '.AWS_DEFAULT_REGION')
export AWS_BUCKET=$(echo "$S3_SECRET" | jq -r '.AWS_BUCKET')
check_postgres() {
    echo "[UserData] Aguardando PostgreSQL ficar disponível..."
    local max_attempts=10
    local attempt=1
    local wait_time=30
    while ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; do
    echo "[UserData] PostgreSQL ainda não está disponível. Tentativa $attempt/$max_attempts. Aguardando $wait_time segundos..."
    if [ $attempt -ge $max_attempts ]; then
        echo "[UserData] ERRO: PostgreSQL não ficou disponível após $max_attempts tentativas!" >&2
        exit 1
    fi
    sleep "$wait_time"
    attempt=$((attempt + 1))
    done
    echo "[UserData] PostgreSQL está disponível!"
}
