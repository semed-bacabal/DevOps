service nginx status

cat /var/log/user-data.log
tail -n 200 /var/log/user-data.log
head -n 200 /var/log/user-data.log

cat /var/www/ieducar/.env
cat /var/www/idiario/config/database.yml
cat /var/www/idiario/config/secrets.yml

ps aux | grep -E 'puma|sidekiq' | grep -v grep



sudo apt update
sudo apt install nginx

sudo nano /etc/nginx/sites-available/idiario

sudo rm /etc/nginx/sites-enabled/default

sudo ln -s /etc/nginx/sites-available/idiario /etc/nginx/sites-enabled/

sudo nginx -t

sudo systemctl restart nginx