#!/bin/bash

# Cek argumen
if [ $# -ne 2 ]; then
    echo "Usage: $0 <new_domain> <old_domain>"
    echo "Example: $0 newdomain.com olddomain.com"
    exit 1
fi

NEW_DOMAIN=$1
OLD_DOMAIN=$2
CONFIG_FILE="/etc/pterodactyl/config.yml"
NGINX_CONF="/etc/nginx/sites-available/pterodactyl.conf"

# Validasi file konfigurasi
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Pterodactyl config not found at $CONFIG_FILE"
    exit 1
fi

if [ ! -f "$NGINX_CONF" ]; then
    echo "ERROR: Nginx config not found at $NGINX_CONF"
    exit 1
fi

echo "Changing domain from $OLD_DOMAIN to $NEW_DOMAIN"

# 1. Matikan nginx
echo "Stopping nginx..."
systemctl stop nginx

# 2. Buat sertifikat SSL baru
echo "Creating SSL certificate for $NEW_DOMAIN..."
certbot certonly --standalone -d "$NEW_DOMAIN" --non-interactive --agree-tos --email admin@$NEW_DOMAIN
certbot certonly --standalone -d node"$NEW_DOMAIN" --non-interactive --agree-tos --email admin@$NEW_DOMAIN

# Cek keberhasilan certbot
if [ $? -ne 0 ]; then
    echo "ERROR: Certbot failed! Check domain DNS and port 80 accessibility."
    exit 1
fi

# 3. Update domain di config.yml (hanya URL lengkap)
echo "Updating Pterodactyl configuration..."
sed -i "s|https://$OLD_DOMAIN|https://$NEW_DOMAIN|g" "$CONFIG_FILE"

# 4. Update domain di konfigurasi nginx (ganti semua kemunculan)
echo "Updating Nginx configuration..."
sed -i "s|$OLD_DOMAIN|$NEW_DOMAIN|g" "$NGINX_CONF"

# 5. Update path sertifikat SSL di nginx
echo "Updating SSL certificate paths..."
sed -i "s|/etc/letsencrypt/live/$OLD_DOMAIN|/etc/letsencrypt/live/$NEW_DOMAIN|g" "$NGINX_CONF"

# 6. Start nginx
echo "Starting nginx..."
systemctl start nginx

# 7. Restart Pterodactyl services
echo "Restarting Pterodactyl services..."
systemctl restart pterodactyl
systemctl restart wings

echo "Domain change completed successfully!"
echo "Old domain: $OLD_DOMAIN"
echo "New domain: $NEW_DOMAIN"
