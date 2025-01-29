#!/bin/bash
# Update packages and install Docker
apt-get update -y
apt-get install -y docker.io

# Start Docker and enable it on boot
systemctl start docker
systemctl enable docker

# Run PrestaShop container
docker run -d \
  --name prestashop \
  -p 80:80 \
  -e DB_SERVER="${rds_endpoint}" \
  -e DB_USER="admin" \
  -e DB_PASSWD="P@ssword123" \
  prestashop/prestashop


#Clean up the install folder for security
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
rm -rf /var/www/html/install
mv /var/www/html/admin /var/www/html/admin4931y4sdr0f62y5yad4





