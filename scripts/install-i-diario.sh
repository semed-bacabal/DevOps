#!/bin/bash
source "$(dirname "$0")/setup-common.sh"

log "Iniciando instalação do i-Diário..."

export DEBIAN_FRONTEND=noninteractive
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf && sysctl -p

log "Instalando dependências..."
apt install -y curl wget build-essential libpq-dev shared-mime-info rbenv redis-server git postgresql-client nginx

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
RUBY_CONFIGURE_OPTS="--with-openssl-dir=/opt/openssl-1.1" rbenv install 2.4.10
rbenv global 2.4.10
ruby -v
gem install bundler -v 1.17.3
rbenv rehash
bundler -v

log "Instalando Node.js via NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 12.22.1
nvm use 12.22.1
npm install -g yarn
node -v
yarn -v

log "Clonando repositório..."
git clone https://github.com/semed-bacabal/i-diario.git /var/www/idiario
cd /var/www/idiario
chmod -R 777 .

log "Instalando dependências do projeto..."
export RAILS_ENV=production
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
  secret_key_base: `bundle exec rake secret`
  REDIS_URL: 'redis://127.0.0.1:6379'
  REDIS_DB_CACHE: /0
  REDIS_DB_SESSION: /1
  REDIS_DB_SIDEKIQ: /2
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: $AWS_DEFAULT_REGION
  AWS_BUCKET: $AWS_BUCKET
  EXAM_POSTING_QUEUES: 'exam_posting_1,exam_posting_2,exam_posting_3'
" > config/secrets.yml

log "Configurando Nginx..."
cp /var/www/idiario/DevOps/nginx/* /etc/nginx/sites-available/
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/idiario /etc/nginx/sites-enabled/
nginx -s reload

check_postgres

log "Criando e migrando banco de dados..."
bundle exec rake db:create
bundle exec rake db:migrate

log "Compilando assets..."
bundle exec rake assets:precompile

log "Configurando entidade e admin..."
bundle exec rake entity:setup NAME=idiario DOMAIN="$ALB_DNS_NAME" DATABASE=$DB_NAME

log "Criando usuário administrador..."
DISABLE_SPRING=1 bundle exec rails runner "
Entity.last.using_connection {
  User.create!(
    email: 'admin@domain.com.br',
    password: '123456789',
    password_confirmation: '123456789',
    status: 'active',
    kind: 'employee',
    admin: true,
    first_name: 'Admin'
  )
}
"

log "Iniciando serviços..."
bundle exec rails server &
bundle exec sidekiq -q synchronizer -c 1 --logfile log/sidekiq-synchronizer.log &
bundle exec sidekiq -q synchronizer_full -c 1 --logfile log/sidekiq-synchronizer-full.log &
bundle exec sidekiq -q synchronizer_enqueue_next_job -c 1 -d --logfile log/sidekiq.log &
bundle exec sidekiq -q synchronizer_enqueue_next_job_full -c 1 --logfile log/sidekiq.log &
bundle exec sidekiq -c 10 -d --logfile log/sidekiq.log &
bundle exec sidekiq -q critical -c 1 -d --logfile log/critical.log &
bundle exec sidekiq -q exam_posting_1 -c 1 -d --logfile log/sidekiq_exam_posting.log &
bundle exec sidekiq -q exam_posting_2 -c 1 -d --logfile log/sidekiq_exam_posting.log &
bundle exec sidekiq -q exam_posting_3 -c 1 -d --logfile log/sidekiq_exam_posting.log &

log "Instalação do i-Diário finalizada." > /var/log/installation-complete.log
