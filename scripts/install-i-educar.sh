#!/bin/bash
# i-Educar installation script

# Running common setup script
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/setup-common.sh"

log "Projeto i-educar detectado. Iniciando instalação..."

log "Adicionando repositórios PPA..."
add-apt-repository ppa:openjdk-r/ppa -y
add-apt-repository ppa:ondrej/php -y

log "Instalando dependências..."
PHP_PACKAGES="php8.4-common php8.4-cli php8.4-fpm php8.4-bcmath php8.4-curl php8.4-mbstring php8.4-pgsql php8.4-xml php8.4-zip php8.4-gd"
if ! apt install -y nginx redis openjdk-8-jdk openssl unzip git postgresql-client $PHP_PACKAGES; then
    error_exit "Falha na instalação de dependências."
fi

log "Instalando Composer..."
export HOME=/root
export COMPOSER_ALLOW_SUPERUSER=1
if ! php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" || \
   ! php composer-setup.php --install-dir=/usr/bin --filename=composer || \
   ! php -r "unlink('composer-setup.php');"; then
    error_exit "Falha na instalação do Composer."
fi

log "Clonando repositório..."
if ! git clone https://github.com/semed-bacabal/i-educar.git /var/www/ieducar; then
    error_exit "Falha ao clonar repositório."
fi
cd /var/www/ieducar
chmod -R 777 .

log "Configurando ambiente (.env)..."
cp .env.example .env
sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=pgsql|" .env
sed -i "s|^DB_HOST=.*|DB_HOST=$DB_HOST|" .env
sed -i "s|^DB_PORT=.*|DB_PORT=5432|" .env
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=$DB_USERNAME|" .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env
sed -i "s|^FILESYSTEM_DISK=.*|FILESYSTEM_DISK=s3|" .env
sed -i "s|^AWS_ACCESS_KEY_ID=.*|AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID|" .env
sed -i "s|^AWS_SECRET_ACCESS_KEY=.*|AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY|" .env
sed -i "s|^AWS_DEFAULT_REGION=.*|AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION|" .env
sed -i "s|^AWS_BUCKET=.*|AWS_BUCKET=$AWS_BUCKET|" .env

check_postgres

log "Configurando Nginx..."
cp docker/nginx/conf.d/* /etc/nginx/conf.d/
cp docker/nginx/snippets/* /etc/nginx/snippets/
sed -i 's/fpm:9000/unix:\/run\/php\/php-fpm.sock/g' /etc/nginx/conf.d/upstream.conf
rm -f /etc/nginx/sites-enabled/default
nginx -s reload

log "Instalando dependências do projeto..."
if ! composer new-install; then
    error_exit "Falha na instalação do i-Educar (composer)."
fi

log "Populando banco de dados..."
if ! php artisan db:seed; then
    error_exit "Falha ao popular o banco de dados."
fi

log "Instalando módulos e finalizando configuração..."
composer plug-and-play
php artisan community:reports:install
php artisan vendor:publish --tag=reports-assets --ansi
php artisan migrate
php artisan cache:clear

systemctl status nginx --no-pager -l
systemctl status php8.4-fpm --no-pager -l
log "Instalação do i-Educar finalizada." > /var/log/installation-complete.log
