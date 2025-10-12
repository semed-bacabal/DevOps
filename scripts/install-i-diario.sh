echo "[UserData] Projeto i-diario detectado. Iniciando instalação..."
export DEBIAN_FRONTEND=noninteractive
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf && sysctl -p
if apt install -y curl wget git build-essential libpq-dev shared-mime-info rbenv postgresql-client redis; then
echo "[UserData] Dependências básicas instaladas com sucesso!"
else
echo "[UserData] ERRO: Falha na instalação de dependências básicas!" >&2
exit 1
fi
echo "[UserData] Configurando OpenSSL..."
mkdir -p ~/openssl
cd ~/openssl
wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar -xzvf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w
./config --prefix=/opt/openssl-1.1 --openssldir=/opt/openssl-1.1
make -j$(nproc)
make install
cd ~/ 
echo "[UserData] Instalando Ruby via rbenv..."
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
RUBY_CONFIGURE_OPTS="--with-openssl-dir=/opt/openssl-1.1" rbenv install 2.6.6
rbenv global 2.6.6
ruby -v
gem update --system 3.3.22
gem install bundler -v 2.4.22
echo "[UserData] Instalando Node.js via NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 14
nvm use 14
npm install -g yarn
node -v
yarn -v
echo "[UserData] Clonando repositório do i-Diário..."
if git clone https://github.com/semed-bacabal/i-diario.git /var/www/idiario; then
echo "[UserData] Repositório clonado com sucesso!"
cd /var/www/idiario
chmod -R 777 /var/www/idiario
else
echo "[UserData] ERRO: Falha ao clonar repositório!" >&2
exit 1
fi
echo "[UserData] Instalando i-Diário..."
export RAILS_ENV=production
bundle install
yarn install
cp public/404.html.sample public/404.html
cp public/500.html.sample public/500.html
echo "production:" > config/database.yml
echo "  adapter: postgresql" >> config/database.yml
echo "  encoding: utf8" >> config/database.yml
echo "  database: $DB_NAME" >> config/database.yml
echo "  pool: 5" >> config/database.yml
echo "  username: $DB_USERNAME" >> config/database.yml
echo "  password: $DB_PASSWORD" >> config/database.yml
echo "  host: $DB_HOST" >> config/database.yml
echo "  port: 5432" >> config/database.yml
echo "production:" > config/secrets.yml
echo "  secret_key_base: $(bundle exec rails secret)" >> config/secrets.yml
echo "  REDIS_URL: 'redis://localhost'" >> config/secrets.yml
echo "  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID" >> config/secrets.yml
echo "  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY" >> config/secrets.yml
echo "  AWS_REGION: $AWS_DEFAULT_REGION" >> config/secrets.yml
echo "  AWS_BUCKET: $AWS_BUCKET" >> config/secrets.yml
check_postgres
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails assets:precompile
bundle exec rails entity:setup NAME=idiario DOMAIN="$ALB_DNS_NAME" DATABASE=$DB_NAME
bundle exec rails entity:admin:create NAME=idiario ADMIN_PASSWORD=A123456789$
echo "[UserData] Instalação do i-Diário finalizada."
echo "$(date): i-Diario installation completed successfully" > /var/log/installation-complete.log
bundle exec rails server -b 0.0.0.0 -p 80
