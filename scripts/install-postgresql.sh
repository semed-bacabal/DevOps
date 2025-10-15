#!/bin/bash
log() { echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

log "Iniciando configuração do banco de dados PostgreSQL..."

log "Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo

log "Instalando CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb

log "Atualizando sistema..."
apt update

log "Instalando dependências básicas..."
apt install -y awscli jq

log "Configurando AWS CLI..."
aws configure set region "$AWS_REGION"

log "Buscando senha do banco de dados..."
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text | jq -r '.password')

log "Instalando PostgreSQL e PostgreSQL Contrib..."
apt install -y postgresql postgresql-contrib

log "Iniciando serviço PostgreSQL..."
systemctl start postgresql.service
systemctl enable postgresql

log "Criando usuário do banco de dados..."
sudo -u postgres psql -c "CREATE USER $DB_USERNAME WITH PASSWORD '$DB_PASSWORD' SUPERUSER CREATEDB;"

log "Criando banco de dados..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"

log "Configurando PostgreSQL para aceitar conexões da aplicação..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '(\d+)' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

log "Configurando listen_addresses..."
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"

log "Aplicando configurações de performance..."
sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 1GB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 128MB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#checkpoint_completion_target = 0.9/checkpoint_completion_target = 0.9/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#random_page_cost = 4.0/random_page_cost = 1.1/" "$PG_CONFIG_DIR/postgresql.conf"

log "Configurando autenticação da VPC..."
echo "host    all             all             10.0.0.0/16             md5" >> "$PG_CONFIG_DIR/pg_hba.conf"

log "Reiniciando PostgreSQL..."
systemctl restart postgresql

log "Verificando status do PostgreSQL..."
systemctl status postgresql --no-pager -l

log "Testando conexão..."
sudo -u postgres psql -c "SELECT version();"

log "Instalação do PostgreSQL finalizada." > /var/log/installation-complete.log
