#!/bin/bash

# --- Konfigurasi ---
# ID admin yang akan dikecualikan dari batasan.
ADMIN_ID=$1
# Direktori root Pterodactyl.
BASE_DIR="/var/www/pterodactyl"

# --- Validasi Awal ---
set -e  # Hentikan skrip jika ada perintah yang gagal.
set -o pipefail # Hentikan jika perintah dalam pipeline gagal.

if [ -z "$ADMIN_ID" ]; then
  echo "Kesalahan: Anda harus menyertakan ID Admin."
  echo "Contoh: $0 1"
  exit 1
fi

echo "Skrip patch Pterodactyl dimulai untuk ADMIN_ID: $ADMIN_ID"

# --- Definisi File dan Snippet ---

# Buat file snippet sementara dengan nama unik untuk menghindari konflik.
SNIPPET_FILE_1=$(mktemp)
SNIPPET_FILE_2=$(mktemp)
SNIPPET_FILE_3=$(mktemp)

# Gunakan 'trap' untuk memastikan file sementara selalu dihapus, bahkan jika skrip gagal.
trap 'rm -f "$SNIPPET_FILE_1" "$SNIPPET_FILE_2" "$SNIPPET_FILE_3"; echo "File sementara telah dibersihkan."' EXIT

# Snippet 1: Mencegah user lain melihat server admin.
cat > "$SNIPPET_FILE_1" <<PHP
\$authUser  = \Illuminate\Support\Facades\Auth::user();
if (\$authUser->id !== $ADMIN_ID && (int)\$server->owner_id !== (int)\$authUser->id) {
    abort(403, "Onokosy Anti Intip Aktif");
}
PHP

# Snippet 2: Melindungi user admin dari penghapusan atau modifikasi.
cat > "$SNIPPET_FILE_2" <<PHP
if(\$user->id === (int)$ADMIN_ID) {
    throw new \Pterodactyl\Exceptions\DisplayException("Onokosy Protect diaktifkan untuk user ini");
}
PHP

cat > "$SNIPPET_FILE_3" <<PHP
if(\$user === (int)$ADMIN_ID) {
    throw new \Pterodactyl\Exceptions\DisplayException("Onokosy Protect diaktifkan untuk user ini");
}
PHP

# Definisikan file target, baris, dan snippet yang akan digunakan dalam sebuah array.
# Format: "path/ke/file:nomor_baris:file_snippet"
declare -a PATCH_TARGETS=(
  "app/Http/Controllers/Api/Client/Servers/FileController.php:44:${SNIPPET_FILE_1}"
  "app/Http/Controllers/Api/Client/Servers/FileController.php:82:${SNIPPET_FILE_1}"
  "app/Services/Users/UserDeletionService.php:33:${SNIPPET_FILE_3}"
  "app/Services/Users/UserUpdateService.php:26:${SNIPPET_FILE_2}"
)

# --- Fungsi untuk Memasukkan Kode ---
patch_file() {
  local target_file="$1"
  local line_number="$2"
  local snippet_file="$3"
  local temp_file

  temp_file=$(mktemp)
  
  echo "-> Memasukkan patch ke: $target_file di baris $line_number"
  awk -v snippet="$snippet_file" '
    NR == '$line_number' {
      print;
      while ((getline line < snippet) > 0) print line;
      close(snippet);
      next
    }
    { print }
  ' "$target_file" > "$temp_file" && mv "$temp_file" "$target_file"
}

# --- Eksekusi ---

# 1. Cek keberadaan semua file target terlebih dahulu.
for target in "${PATCH_TARGETS[@]}"; do
  FILE_PATH="${BASE_DIR}/$(echo $target | cut -d: -f1)"
  if [ ! -f "$FILE_PATH" ]; then
    echo "ERROR: File tidak ditemukan: $FILE_PATH"
    exit 1
  fi
done
echo "Semua file target ditemukan."

# 2. Buat backup untuk semua file.
echo "Membuat backup..."
for target in "${PATCH_TARGETS[@]}"; do
  FILE_PATH="${BASE_DIR}/$(echo $target | cut -d: -f1)"
  cp -- "$FILE_PATH" "$FILE_PATH.bak"
done
echo "Backup berhasil dibuat (.bak)."

# 3. Lakukan patching menggunakan loop.
echo "Memulai proses patching..."
for target in "${PATCH_TARGETS[@]}"; do
  # Pecah string target menjadi variabel
  IFS=':' read -r file_path line_num snippet_ref <<< "$target"
  
  # Panggil fungsi patch_file
  patch_file "${BASE_DIR}/${file_path}" "$line_num" "$snippet_ref"
done
echo "Proses patching selesai."

# 4. Validasi sintaks PHP untuk semua file yang diubah.
echo "Memvalidasi sintaks PHP..."
for target in "${PATCH_TARGETS[@]}"; do
  FILE_PATH="${BASE_DIR}/$(echo $target | cut -d: -f1)"
  php -l "$FILE_PATH"
done
echo "Validasi sintaks berhasil."

# 5. Bersihkan cache konfigurasi Pterodactyl.
echo "Membersihkan cache konfigurasi Pterodactyl..."
cd "$BASE_DIR" && php artisan config:cache

echo "Skrip berhasil dijalankan!"
