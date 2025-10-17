#!/bin/bash

CONFIG_FILE2="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
CONFIG_FILE3="/var/www/pterodactyl/app/Services/Users/UserDeletionService.php"
CONFIG_FILE4="/var/www/pterodactyl/app/Services/Users/UserUpdateService.php"

mv "$CONFIG_FILE2.bak" "$CONFIG_FILE2"
mv "$CONFIG_FILE3.bak" "$CONFIG_FILE3"
mv "$CONFIG_FILE4.bak" "$CONFIG_FILE4"
chown -R www-data:www-data /var/www/pterodactyl
cd /var/www/pterodactyl && php artisan config:cache
