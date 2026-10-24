#!/usr/bin/env bash
# ==============================================================================
# BÁO CÁO MÔN HỌC: QUẢN TRỊ VÀ TRIỂN KHAI HỆ THỐNG PHẦN MỀM - ĐỀ 31
# Kịch bản gia cố bảo mật máy chủ Ubuntu (Hardening Script)
# Sinh viên: Nguyễn Thành Long - MSSV: DTC245200171 - Lớp: CNTT K23C
# ==============================================================================
set -e

echo "[+] Bắt đầu quy trình Hardening cho Đề 31 - Gallery System..."

# 1. Cấu hình UFW Firewall
echo "[1/4] Cấu hình tường lửa UFW..."
if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp comment 'SSH Port'
    sudo ufw allow 80/tcp comment 'Nginx HTTP'
    sudo ufw allow 443/tcp comment 'Nginx HTTPS'
    sudo ufw --force enable
    echo "  -> UFW đã kích hoạt thành công (Chỉ mở 22, 80, 443)."
fi

# 2. Cấu hình SSH an toàn
echo "[2/4] Gia cố cấu hình OpenSSH Server..."
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    sudo sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 4/' "$SSHD_CONFIG"
    echo "  -> SSH đã được gia cố (Cấm root login, giới hạn 4 lần thử)."
fi

# 3. Kernel Sysctl Hardening
echo "[3/4] Áp dụng các tham số an toàn Kernel sysctl..."
cat << 'EOF' | sudo tee /etc/sysctl.d/99-security-hardening.conf >/dev/null
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sudo sysctl --system >/dev/null 2>&1 || true
echo "  -> Kernel parameters applied."

# 4. Bảo vệ thư mục upload
echo "[4/4] Phân quyền an toàn thư mục uploads..."
mkdir -p uploads
chmod 755 uploads

echo "[+] Hoàn tất toàn bộ quy trình Hardening thành công!"
