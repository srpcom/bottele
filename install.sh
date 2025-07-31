#!/bin/bash

# =================================================================
# SKRIP INSTALLER BOT TELEGRAM SRPCOM STORE (VERSI GITHUB)
# Versi: 3.2 (Instalasi Sederhana)
# =================================================================

# --- Warna untuk Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Variabel Konfigurasi ---
BOT_DIR="/opt/srpcom_bot"
VENV_DIR="$BOT_DIR/venv"
SERVICE_NAME="srpcom-bot"
REPO_URL="https://github.com/srpcom/bottele.git"

# --- Fungsi untuk menampilkan pesan ---
log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[PERINGATAN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# --- Memastikan skrip dijalankan sebagai root ---
if [ "$(id -u)" -ne 0 ]; then
    log_error "Skrip ini harus dijalankan sebagai root. Coba gunakan 'sudo' atau jalankan sebagai user root."
    exit 1
fi

# --- Memulai Instalasi ---
log_info "Memulai instalasi Bot Telegram SRPCOM STORE dari GitHub..."
sleep 2

# 1. Menghentikan dan Membersihkan Instalasi Lama (jika ada)
if systemctl is-active --quiet $SERVICE_NAME; then
    log_warn "Service lama ($SERVICE_NAME) ditemukan. Menghentikan service..."
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
fi

if [ -d "$BOT_DIR" ]; then
    log_warn "Direktori instalasi lama ditemukan. Menghapus $BOT_DIR..."
    rm -rf "$BOT_DIR"
fi

# 2. Meminta Input Konfigurasi dari Pengguna (Disederhanakan)
log_info "Silakan masukkan Token Bot Telegram Anda."
read -p "$(echo -e ${YELLOW}"Masukkan Token Bot Telegram Anda: "${NC})" BOT_TOKEN

# Validasi input
if [ -z "$BOT_TOKEN" ]; then
    log_error "Token Bot tidak boleh kosong. Instalasi dibatalkan."
    exit 1
fi

# 3. Update Sistem dan Instal Dependensi
log_info "Memperbarui sistem dan menginstal dependensi (git, python3-pip, python3-venv)..."
apt-get update > /dev/null 2>&1
apt-get install -y python3-pip python3-venv git > /dev/null 2>&1
log_info "Dependensi sistem berhasil diinstal."

# 4. Mengkloning Repositori dari GitHub
log_info "Mengunduh file bot dari repositori GitHub..."
git clone "$REPO_URL" "$BOT_DIR"
if [ $? -ne 0 ]; then
    log_error "Gagal mengkloning repositori dari GitHub. Pastikan URL repositori benar dan dapat diakses."
    exit 1
fi
log_info "File bot berhasil diunduh ke $BOT_DIR."

# 5. Membuat File Konfigurasi (config.ini) dengan Placeholder
log_info "Membuat file konfigurasi config.ini dengan placeholder..."
cat << EOF > "$BOT_DIR/config.ini"
[telegram]
token = $BOT_TOKEN
admin_id = GANTI_DENGAN_ID_ADMIN_ANDA

[tripay]
api_key = GANTI_DENGAN_API_KEY_TRIPAY
private_key = GANTI_DENGAN_PRIVATE_KEY_TRIPAY
merchant_code = GANTI_DENGAN_KODE_MERCHANT_TRIPAY

[webhook]
listen_ip = 0.0.0.0
port = 8443
EOF

# 6. Membuat Virtual Environment dan Menginstal Library Python
log_info "Membuat virtual environment dan menginstal library yang dibutuhkan..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
log_info "Memulai instalasi library dari requirements.txt..."
pip install -r "$BOT_DIR/requirements.txt"

if [ $? -ne 0 ]; then
    log_error "Gagal menginstal library Python. Silakan periksa error di atas."
    log_error "Instalasi dibatalkan."
    deactivate
    exit 1
fi

deactivate
log_info "Library Python berhasil diinstal."

# 7. Membuat Service systemd
log_info "Membuat service systemd ($SERVICE_NAME.service) agar bot berjalan otomatis..."
CURRENT_USER=$(logname)
if [ -z "$CURRENT_USER" ]; then
    CURRENT_USER=$(who | awk '{print $1}')
fi
CURRENT_GROUP=$(id -gn "$CURRENT_USER")
cat << EOF > "/etc/systemd/system/$SERVICE_NAME.service"
[Unit]
Description=Telegram Bot SRPCOM STORE (Modular)
After=network.target

[Service]
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$BOT_DIR
ExecStart=$VENV_DIR/bin/python3 $BOT_DIR/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 8. Mengaktifkan Service
log_info "Mengaktifkan service bot..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

# --- Selesai ---
log_info "========================================================"
log_info "INSTALASI SELESAI!"
log_warn "LANGKAH SELANJUTNYA (WAJIB):"
log_warn "1. Edit file konfigurasi untuk memasukkan detail Anda."
log_warn "   Jalankan: nano $BOT_DIR/config.ini"
log_warn "2. Ganti semua nilai 'GANTI_DENGAN_...' dengan nilai Anda yang sebenarnya."
log_warn "3. Simpan file (Ctrl+X, lalu Y, lalu Enter)."
log_warn "4. Setelah konfigurasi selesai, jalankan bot dengan: sudo systemctl start $SERVICE_NAME"
log_warn "5. Cek status bot dengan: sudo systemctl status $SERVICE_NAME"
log_info "========================================================"
