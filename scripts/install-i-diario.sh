#!/bin/bash
source "$(dirname "$0")/setup-common.sh"

log "Iniciando instalação do i-Diário..."

export DEBIAN_FRONTEND=noninteractive
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf && sysctl -p

log "Instalando dependências..."
apt install -y curl wget build-essential libpq-dev shared-mime-info rbenv redis git postgresql-client nginx
# apt install -y curl wget build-essential libpq-dev shared-mime-info rbenv redis-server redis-tools git postgresql-client nginx
log "Configurando OpenSSL..."
mkdir -p ~/openssl
cd ~/openssl
wget -q https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar -xzvf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w
./config --prefix=/opt/openssl-1.1 --openssldir=/opt/openssl-1.1
make -j$(nproc)
make install
cd ~/

log "Instalando Ruby via rbenv..."
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
RUBY_CONFIGURE_OPTS="--with-openssl-dir=/opt/openssl-1.1" rbenv install 2.6.6
rbenv global 2.6.6
ruby -v
gem update --system 3.3.22
gem install bundler -v 2.4.22

log "Instalando Node.js via NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 14
nvm use 14
npm install -g yarn
node -v
yarn -v

log "Clonando repositório..."
git clone https://github.com/semed-bacabal/i-diario.git /var/www/idiario
cd /var/www/idiario
chmod -R 777 .

log "Instalando dependências do projeto..."
export RAILS_ENV=production
export REDIS_URL=redis://localhost:6379
bundle install
yarn install

log "Configurando aplicação..."
cp public/404.html.sample public/404.html
cp public/500.html.sample public/500.html

log "Configurando banco de dados e segredos..."
echo "
production:
  adapter: postgresql
  encoding: utf8
  database: $DB_NAME
  pool: 5
  username: $DB_USERNAME
  password: $DB_PASSWORD
  host: $DB_HOST
  port: 5432
" > config/database.yml
echo "
production:
  secret_key_base: `bundle exec rails secret`
  REDIS_URL: 'redis://localhost'
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: $AWS_DEFAULT_REGION
  AWS_BUCKET: $AWS_BUCKET
" > config/secrets.yml

log "Configurando Nginx..."
cp /var/www/idiario/DevOps/nginx/* /etc/nginx/sites-available/
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/idiario /etc/nginx/sites-enabled/
nginx -s reload

# log "Habilitando e iniciando o Redis..."
# systemctl enable --now redis-server

check_postgres

log "Criando e migrando banco de dados..."
bundle exec rails db:create
bundle exec rails db:migrate

log "Pré-compilando assets..."
bundle exec rails assets:precompile

log "Configurando entidade e admin..."
bundle exec rails entity:setup NAME=idiario DOMAIN="$ALB_DNS_NAME" DATABASE=$DB_NAME
bundle exec rails entity:admin:create NAME=idiario ADMIN_PASSWORD=A123456789$

log "Iniciando serviços..."
bundle exec rails server -b 0.0.0.0 -p 3000 &
bundle exec sidekiq -q synchronizer_enqueue_next_job -c 1 --logfile log/sidekiq.log &
bundle exec sidekiq -c 10 --logfile log/sidekiq.log &

log "Instalação do i-Diário finalizada." > /var/log/installation-complete.log
