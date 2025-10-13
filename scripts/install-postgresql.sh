#!/bin/bash
# Script de instalação do PostgreSQL

log() {
    echo "ℹ️[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    echo "❌[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    exit 1
}

log "Iniciando configuração da instância de banco de dados PostgreSQL..."

log "Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo

log "Instalando CloudWatch Agent..."
if ! wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb; then
    error_exit "Falha ao baixar o CloudWatch Agent."
fi
if ! dpkg -i -E ./amazon-cloudwatch-agent.deb; then
    error_exit "Falha ao instalar o CloudWatch Agent."
fi
rm -f ./amazon-cloudwatch-agent.deb

log "Atualizando sistema..."
if ! apt update; then
    error_exit "Falha ao atualizar os pacotes."
fi

log "Instalando dependências básicas..."
if ! apt install -y awscli jq; then
    error_exit "Falha ao instalar dependências (awscli, jq)."
fi

log "Configurando AWS CLI..."
aws configure set region "$AWS_REGION" || error_exit "Falha ao configurar a região AWS."

log "Buscando senha do banco de dados..."
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text | jq -r '.password') || error_exit "Falha ao obter DB_PASSWORD."

log "Instalando PostgreSQL e PostgreSQL Contrib..."
if ! apt install -y postgresql postgresql-contrib; then
    error_exit "Falha ao instalar PostgreSQL e PostgreSQL Contrib."
fi

log "Iniciando serviço PostgreSQL..."
if ! systemctl start postgresql.service; then
    error_exit "Falha ao iniciar o serviço PostgreSQL."
fi
systemctl enable postgresql || error_exit "Falha ao habilitar o serviço PostgreSQL."

log "Criando usuário do banco de dados..."
if ! sudo -u postgres psql -c "CREATE USER $DB_USERNAME WITH PASSWORD '$DB_PASSWORD' SUPERUSER CREATEDB;"; then
    error_exit "Falha ao criar usuário do banco de dados."
fi

log "Criando banco de dados..."
if ! sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"; then
    error_exit "Falha ao criar banco de dados."
fi

log "Configurando PostgreSQL para aceitar conexões da aplicação..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '(\d+)' | head -1) || error_exit "Falha ao obter versão do PostgreSQL."
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

log "Configurando listen_addresses..."
if ! sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"; then
    error_exit "Falha ao configurar listen_addresses."
fi

log "Aplicando configurações de performance..."
sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "$PG_CONFIG_DIR/postgresql.conf" || error_exit "Falha ao configurar shared_buffers."
sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 1GB/" "$PG_CONFIG_DIR/postgresql.conf" || error_exit "Falha ao configurar effective_cache_size."
sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 128MB/" "$PG_CONFIG_DIR/postgresql.conf" || error_exit "Falha ao configurar maintenance_work_mem."
sed -i "s/#checkpoint_completion_target = 0.9/checkpoint_completion_target = 0.9/" "$PG_CONFIG_DIR/postgresql.conf" || error_exit "Falha ao configurar checkpoint_completion_target."
sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" "$PG_CONFIG_DIR/postgresql.conf" || error_exit "Falha ao configurar wal_buffers."
sed -i "s/#random_page_cost = 4.0/random_page_cost = 1.1/" "$PG_CONFIG_DIR/postgresql.conf" || error_exit "Falha ao configurar random_page_cost."

log "Configurando autenticação da VPC..."
if ! echo "host    all             all             10.0.0.0/16             md5" >> "$PG_CONFIG_DIR/pg_hba.conf"; then
    error_exit "Falha ao configurar autenticação da VPC."
fi

log "Reiniciando PostgreSQL..."
if ! systemctl restart postgresql; then
    error_exit "Falha ao reiniciar PostgreSQL."
fi

log "Verificando status do PostgreSQL..."
systemctl status postgresql --no-pager -l || error_exit "PostgreSQL não está rodando corretamente."

log "Testando conexão..."
if ! sudo -u postgres psql -c "SELECT version();"; then
    error_exit "Falha ao testar conexão com PostgreSQL."
fi

log "Criando marca de conclusão..."
echo "$(date): PostgreSQL installation completed successfully" > /var/log/installation-complete.log || error_exit "Falha ao criar marca de conclusão."

log "Configuração do PostgreSQL concluída!"
