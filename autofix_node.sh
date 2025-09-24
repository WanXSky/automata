#!/bin/bash

wings 2>&1 | while read line; do
  echo "$line"
  
  case "$line" in 
    *"failed to configure HTTPS server auto_tls=false error=open /etc/letsencrypt/live/"*)
      echo "[AUTO FIX] Mencoba memperbaiki"
      DOMAIN=$(echo "$line" | awk -F '/etc/letsencrypt/live/|/fullchain.pem' '{print $2}') # ambil isi dari | yang ada di antara 2 kata
      echo "[AUTO FIX] Domain: $DOMAIN"
      if [ -n "$DOMAIN" ]; then # Jika variable DOMAIM tidak kosong
        systemctl stop nginx
        certbot certonly --standalone -d "$DOMAIN" \
        --non-interactive --agree-tos -m ono@g.com
        systemctl start nginx
        systemctl restart wings
        echo "[AUTO FIX] Berhasil memperbaiki"
      else 
        echo "[AUTO FIX] Gagal memperbaiki"
      fi
      ;;
    esac
  done
