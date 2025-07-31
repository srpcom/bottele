#!/bin/bash

# =================================================================
# SKRIP INSTALLER BOT TELEGRAM SRPCOM STORE (VERSI GITHUB)
# Dibuat oleh Gemini
# Versi: 3.0 (Mengunduh langsung dari repositori GitHub)
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

# 2. Meminta Input Konfigurasi dari Pengguna
log_info "Silakan masukkan detail konfigurasi bot Anda."
read -p "$(echo -e ${YELLOW}"Masukkan Token Bot Telegram Anda: "${NC})" BOT_TOKEN
read -p "$(echo -e ${YELLOW}"Masukkan ID Admin Utama (numerik): "${NC})" ADMIN_ID
read -p "$(echo -e ${YELLOW}"Masukkan API Key Tripay Anda: "${NC})" TRIPAY_API_KEY
read -p "$(echo -e ${YELLOW}"Masukkan Private Key Tripay Anda: "${NC})" TRIPAY_PRIVATE_KEY
read -p "$(echo -e ${YELLOW}"Masukkan Kode Merchant Tripay Anda: "${NC})" TRIPAY_MERCHANT_CODE
read -p "$(echo -e ${YELLOW}"Masukkan Port untuk Webhook Callback (contoh: 8443): "${NC})" CALLBACK_PORT

# Validasi input
if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ] || [ -z "$TRIPAY_API_KEY" ] || [ -z "$TRIPAY_PRIVATE_KEY" ] || [ -z "$TRIPAY_MERCHANT_CODE" ] || [ -z "$CALLBACK_PORT" ]; then
    log_error "Semua kolom konfigurasi harus diisi. Instalasi dibatalkan."
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

# 5. Membuat File Konfigurasi (config.ini)
log_info "Membuat file konfigurasi config.ini..."
cat << EOF > "$BOT_DIR/config.ini"
[telegram]
token = $BOT_TOKEN
admin_id = $ADMIN_ID

[tripay]
api_key = $TRIPAY_API_KEY
private_key = $TRIPAY_PRIVATE_KEY
merchant_code = $TRIPAY_MERCHANT_CODE

[webhook]
listen_ip = 0.0.0.0
port = $CALLBACK_PORT
EOF

# 6. Membuat Virtual Environment dan Menginstal Library Python
log_info "Membuat virtual environment dan menginstal library yang dibutuhkan..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip > /dev/null 2>&1
pip install -r "$BOT_DIR/requirements.txt" > /dev/null 2>&1
deactivate
log_info "Library Python berhasil diinstal."

# 7. Membuat Service systemd
log_info "Membuat service systemd ($SERVICE_NAME.service) agar bot berjalan otomatis..."
CURRENT_USER=$(logname)
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
log_warn "LANGKAH SELANJUTNYA:"
log_warn "1. Bot sudah siap dijalankan."
log_warn "2. Jalankan bot dengan perintah: sudo systemctl start $SERVICE_NAME"
log_warn "3. Cek status bot dengan: sudo systemctl status $SERVICE_NAME"
log_warn "4. Untuk melihat log real-time: journalctl -u $SERVICE_NAME -f"
log_warn "PENTING: Pastikan port $CALLBACK_PORT terbuka di firewall VPS Anda."
log_info "========================================================"
