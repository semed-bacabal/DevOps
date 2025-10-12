echo "[UserData] Projeto i-educar detectado. Iniciando instalação..."
add-apt-repository ppa:openjdk-r/ppa -y
add-apt-repository ppa:ondrej/php -y
if apt install -y nginx redis openjdk-8-jdk openssl unzip php8.4-common php8.4-cli php8.4-fpm php8.4-bcmath php8.4-curl php8.4-mbstring php8.4-pgsql php8.4-xml php8.4-zip php8.4-gd git postgresql-client; then
echo "[UserData] Dependências instaladas com sucesso!"
else
echo "[UserData] ERRO: Falha na instalação de dependências!" >&2
exit 1
fi
export HOME=/root
export COMPOSER_ALLOW_SUPERUSER=1
if php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php --install-dir=/usr/bin --filename=composer && php -r "unlink('composer-setup.php');"; then
echo "[UserData] Composer instalado com sucesso!"
else
echo "[UserData] ERRO: Falha na instalação do Composer!" >&2
exit 1
fi
if git clone https://github.com/semed-bacabal/i-educar.git /var/www/ieducar; then
echo "[UserData] Repositório clonado com sucesso!"
cd /var/www/
chmod -R 777 ieducar/
cd /var/www/ieducar/
cp .env.example .env
else
echo "[UserData] ERRO: Falha ao clonar repositório!" >&2
exit 1
fi
echo "[UserData] Configurando i-Educar..."
sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/" /var/www/ieducar/.env
sed -i "s/^DB_HOST=.*/DB_HOST=$DB_HOST/" /var/www/ieducar/.env
sed -i "s/^DB_PORT=.*/DB_PORT=5432/" /var/www/ieducar/.env
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" /var/www/ieducar/.env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" /var/www/ieducar/.env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" /var/www/ieducar/.env
sed -i "s/^FILESYSTEM_DISK=.*/FILESYSTEM_DISK=s3/" /var/www/ieducar/.env
sed -i "s/^AWS_ACCESS_KEY_ID=.*/AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID/" /var/www/ieducar/.env
sed -i "s/^AWS_SECRET_ACCESS_KEY=.*/AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY/" /var/www/ieducar/.env
sed -i "s/^AWS_DEFAULT_REGION=.*/AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION/" /var/www/ieducar/.env
sed -i "s/^AWS_BUCKET=.*/AWS_BUCKET=$AWS_BUCKET/" /var/www/ieducar/.env
check_postgres
cp /var/www/ieducar/docker/nginx/conf.d/* /etc/nginx/conf.d/
cp /var/www/ieducar/docker/nginx/snippets/* /etc/nginx/snippets/
sed -i 's/fpm:9000/unix:\/run\/php\/php-fpm.sock/g' /etc/nginx/conf.d/upstream.conf
rm /etc/nginx/sites-enabled/default
nginx -s reload
echo "[UserData] Instalando i-Educar..."
if composer new-install; then
echo "[UserData] i-Educar instalado com sucesso!"
echo "[UserData] Populando banco de dados com os dados iniciais necessários para o funcionamento..."
if php artisan db:seed; then
    echo "[UserData] Banco de dados populado com sucesso!"
    echo "[UserData] Instalando módulos adicionais..."
    composer plug-and-play
    php artisan community:reports:install
    php artisan vendor:publish --tag=reports-assets --ansi
    php artisan migrate
    php artisan cache:clear
    echo "[UserData] Módulos adicionais instalados com sucesso!"
else
    echo "[UserData] ERRO: Falha ao popular o banco de dados!" >&2
    exit 1
fi
else
echo "[UserData] ERRO: Falha na instalação do i-Educar!" >&2
exit 1
fi
echo "[UserData] Instalação do i-Educar finalizada."
systemctl status nginx --no-pager -l
systemctl status php8.4-fpm --no-pager -l
echo "$(date): i-Educar installation completed successfully" > /var/log/installation-complete.log
