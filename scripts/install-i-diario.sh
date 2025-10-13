#!/bin/bash
# i-Diário installation script

# Running common setup script
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/setup-common.sh"

log "Projeto i-diario detectado. Iniciando instalação..."

export DEBIAN_FRONTEND=noninteractive
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf && sysctl -p

log "Instalando dependências..."
if ! apt install -y curl wget build-essential libpq-dev shared-mime-info rbenv redis; then
    error_exit "Falha na instalação de dependências."
fi

log "Configurando OpenSSL..."
mkdir -p ~/openssl
cd ~/openssl
if ! wget -q https://www.openssl.org/source/openssl-1.1.1w.tar.gz || ! tar -xzvf openssl-1.1.1w.tar.gz; then
    error_exit "Falha ao baixar ou extrair OpenSSL."
fi
cd openssl-1.1.1w
./config --prefix=/opt/openssl-1.1 --openssldir=/opt/openssl-1.1
make -j$(nproc)
make install
cd ~/

log "Instalando Ruby via rbenv..."
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
if ! RUBY_CONFIGURE_OPTS="--with-openssl-dir=/opt/openssl-1.1" rbenv install 2.6.6; then
    error_exit "Falha ao instalar Ruby 2.6.6."
fi
rbenv global 2.6.6
ruby -v
gem update --system 3.3.22
gem install bundler -v 2.4.22

log "Instalando Node.js via NVM..."
if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; then
    error_exit "Falha ao baixar script de instalação do NVM."
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 14
nvm use 14
npm install -g yarn
node -v
yarn -v

log "Clonando repositório..."
if ! git clone https://github.com/semed-bacabal/i-diario.git /var/www/idiario; then
    error_exit "Falha ao clonar repositório."
fi
cd /var/www/idiario
chmod -R 777 /var/www/idiario

log "Instalando dependências do projeto..."
export RAILS_ENV=production
bundle install || error_exit "Falha no bundle install."
yarn install || error_exit "Falha no yarn install."

log "Configurando aplicação..."
cp public/404.html.sample public/404.html
cp public/500.html.sample public/500.html

log "Configurando banco de dados e segredos..."
echo -e "
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

check_postgres

log "Criando e migrando banco de dados..."
bundle exec rails db:create || error_exit "Falha ao criar o banco de dados."
bundle exec rails db:migrate || error_exit "Falha ao migrar o banco de dados."

log "Pré-compilando assets..."
bundle exec rails assets:precompile || error_exit "Falha ao pré-compilar assets."

log "Configurando entidade e admin..."
bundle exec rails entity:setup NAME=idiario DOMAIN="$ALB_DNS_NAME" DATABASE=$DB_NAME || error_exit "Falha ao configurar entidade."
bundle exec rails entity:admin:create NAME=idiario ADMIN_PASSWORD=A123456789$ || error_exit "Falha ao criar usuário admin."

log "Instalação do i-Diário finalizada."
log "$(date): i-Diario installation completed successfully" > /var/log/installation-complete.log

log "Iniciando serviços..."
mkdir -p log

bundle exec rails server -b 0.0.0.0 -p 80 &
bundle exec sidekiq -q synchronizer_enqueue_next_job -c 1 --logfile log/sidekiq.log &
bundle exec sidekiq -c 10 --logfile log/sidekiq.log &

log "Instalação do i-Diário finalizada." > /var/log/installation-complete.log
