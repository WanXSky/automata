#!/bin/bash

# Cek argumen
if [ -z "$1" ]; then
  echo "Usage: $0 <admin_id>"
  echo "Example: $0 1"
  exit 1
fi

ADMIN_ID=$1

# Daftar file target dan baris target
declare -A FILES=(
#  ["/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"]=22
#  ["/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"]=77
  ["/var/www/pterodactyl/app/Services/Users/UserDeletionService.php"]=28
  ["/var/www/pterodactyl/app/Services/Users/UserUpdateService.php"]=21
)

# Snippet
SNIPPET1=$(cat <<PHP
\$authUser  = Auth()->user();
if (\$authUser->id !== $ADMIN_ID && (int)\$server->owner_id !== (int)\$authUser->id) {
    abort(403, "Onokosy Anti Intip Aktif");
}
PHP
)

SNIPPET2=$(cat <<PHP
if(\$user === (int)$ADMIN_ID) {
    throw new \Pterodactyl\Exceptions\DisplayException("Onokosy Protect diaktikan untuk user ini");
}
PHP
)

# Fungsi buat inject
inject_code() {
  local FILE="$1"
  local LINE="$2"
  local SNIPPET="$3"

  if [ ! -f "$FILE" ]; then
    echo "❌ File tidak ditemukan: $FILE"
    return
  fi

  cp -- "$FILE" "$FILE.bak"
  echo "📦 Backup dibuat: $FILE.bak"

  awk -v n="$LINE" -v code="$SNIPPET" '
  NR==n { print; print code; next } { print }
  ' "$FILE" > /tmp/tmp_inject.php && mv /tmp/tmp_inject.php "$FILE"

  echo "✅ Code berhasil disuntik ke $FILE (baris $LINE)"
}

# Eksekusi injection
inject_code "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php" 22 "$SNIPPET1"
inject_code "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php" 77 "$SNIPPET1"
inject_code "/var/www/pterodactyl/app/Services/Users/UserDeletionService.php" 28 "$SNIPPET2"
inject_code "/var/www/pterodactyl/app/Services/Users/UserUpdateService.php" 21 "$SNIPPET2"

# Cek syntax PHP
for FILE in "${!FILES[@]}"; do
  php -l "$FILE"
done

# Clear cache Laravel
cd /var/www/pterodactyl && php artisan optimize:clear
