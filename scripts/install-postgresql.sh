#!/bin/bash

# Script de instalação do PostgreSQL
# Este script instala e configura o PostgreSQL para as aplicações

echo "[PostgreSQL] Iniciando configuração da instância de banco de dados PostgreSQL..."

echo "[UserData] Iniciando configuração da instância de banco de dados PostgreSQL..."
echo "[UserData] Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo

echo "[UserData] Instalando CloudWatch Agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

echo "[UserData] Atualizando sistema..."
apt update

echo "[UserData] Instalando dependências básicas..."
apt install -y awscli jq

echo "[UserData] Configurando AWS CLI..."
aws configure set region $AWS_REGION

echo "[UserData] Buscando senha do banco de dados..."
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text | jq -r '.password')

echo "[UserData] Instalando PostgreSQL e PostgreSQL Contrib..."
apt install -y postgresql postgresql-contrib

echo "[UserData] Iniciando serviço PostgreSQL..."
systemctl start postgresql.service
systemctl enable postgresql

echo "[UserData] Criando usuário do banco de dados..."
sudo -u postgres psql -c "CREATE USER $DB_USERNAME WITH PASSWORD '$DB_PASSWORD' SUPERUSER CREATEDB;"

echo "[UserData] Criando banco de dados..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"

echo "[UserData] Configurando PostgreSQL para aceitar conexões da aplicação..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '(\d+)' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

# Permitir conexões da rede
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"

# Configurações básicas de performance
sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 1GB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 128MB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#checkpoint_completion_target = 0.9/checkpoint_completion_target = 0.9/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" "$PG_CONFIG_DIR/postgresql.conf"
sed -i "s/#random_page_cost = 4.0/random_page_cost = 1.1/" "$PG_CONFIG_DIR/postgresql.conf"

# Permitir autenticação da VPC
echo "host    all             all             10.0.0.0/16             md5" >> "$PG_CONFIG_DIR/pg_hba.conf"

echo "[UserData] Reiniciando PostgreSQL..."
systemctl restart postgresql

echo "[UserData] Verificando status do PostgreSQL..."
systemctl status postgresql --no-pager -l

echo "[UserData] Testando conexão..."
sudo -u postgres psql -c "SELECT version();"

echo "[UserData] Limpando arquivos temporários..."
apt autoremove -y
apt autoclean
rm -f amazon-cloudwatch-agent.deb

echo "[UserData] Criando marca de conclusão..."
echo "$(date): PostgreSQL installation completed successfully" > /var/log/installation-complete.log

echo "[UserData] IMPORTANTE: Após o deploy, verifique:"
echo "[UserData] 1. Conexão da aplicação com o banco"
echo "[UserData] 2. Health check do ALB"
echo "[UserData] 3. Logs no CloudWatch"
echo "[UserData] 4. Configuração de backup se necessário"

echo "[UserData] Configuração do PostgreSQL concluída!"
