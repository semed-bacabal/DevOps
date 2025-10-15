systemctl status postgresql.service

sudo -u postgres psql
list \l
permissions \du
quit \q

service nginx status

cat /var/log/user-data.log
tail -n 200 /var/log/user-data.log

cat /var/www/ieducar/.env
cat /var/www/idiario/config/database.yml
cat /var/www/idiario/config/secrets.yml

ps aux | grep -E 'puma|sidekiq' | grep -v grep

export RAILS_ENV=production
echo $RAILS_ENV

sudo apt update
sudo update-ca-certificates
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
gem update --system 3.3.22

sudo su
apt install -y awscli

aws s3 ls
S3_BUCKET_NAME=$(aws s3 ls | grep "storage" | awk '{print $3}')
S3_BUCKET_NAME=i-educar-dev-storage

BACKUP_DIR="/var/backups/postgres"
mkdir -p "$BACKUP_DIR"
DATE_FORMAT=$(date +"%Y-%m-%d_%Hh%Mm")
databases \l
users \du
quit \q
psql -U postgres
DB_NAME="ieducar"
BACKUP_FILENAME="${DB_NAME}_${DATE_FORMAT}.sql.gz"
BACKUP_FILENAME=ieducar_2025-10-14_07h23m.sql.gz

sudo -u postgres pg_dump -U postgres -d "$DB_NAME" -F c | gzip > "$BACKUP_DIR/$BACKUP_FILENAME"

ls $BACKUP_DIR
ieducar_2025-10-14_07h23m.sql.gz

aws s3 cp "$BACKUP_DIR/$BACKUP_FILENAME" "s3://$S3_BUCKET_NAME/backups/$BACKUP_FILENAME"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILENAME" "s3://${S3_BUCKET_NAME}/backups/manual/${BACKUP_FILENAME}"

aws s3 cp s3://NOME-DO-SEU-BUCKET/backups/daily/nome-do-arquivo-de-backup.sql.gz /tmp/


aws s3 ls s3://NOME_DO_BUCKET/
aws s3 ls s3://i-educar-dev-storage/
aws s3 cp s3://i-educar-dev-storage/backups/manual/ieducar_2025-10-14_07h23m.sql.gz /tmp/backup/


gunzip /tmp/ieducar_2025-10-14_07h23m.sql.gz

sudo -u postgres pg_restore --verbose --clean --if-exists -U postgres -d semed_db /tmp/ieducar_2025-10-14_07h23m.sql


root@ip-10-0-1-219:/var/www/ieducar/public/storage/ieducar# ls

aws s3 cp /var/www/ieducar/public/storage/ieducar s3://NOME_DO_BUCKET/ --recursive

aws s3 cp /var/www/ieducar/public/storage/ieducar s3://i-educar-dev-storage/semed_db/ --recursive
