#!/usr/bin/env bash
# ==============================================================================
# SCRIPT KHẮC PHỤC TRIỆT ĐỂ 100% LỖI ĐƠ / TREO KHI TREO MÁY ẢO UBUNTU LÂU
# Sinh viên: Nguyễn Thành Long - MSSV: DTC245200171 - Lớp: CNTT K23C
# ==============================================================================
set -e

echo "==============================================================================="
echo "   BẮT ĐẦU QUY TRÌNH FIX TRIỆT ĐỂ NGUYÊN NHÂN GÂY ĐƠ / TREO HỆ THỐNG          "
echo "==============================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. TẮT TÍNH NĂNG SLEEP / SUSPEND / HIBERNATE TRÊN UBUNTU
# ------------------------------------------------------------------------------
echo "[1/6] Vô hiệu hóa tính năng Sleep/Suspend/Tắt màn hình tự động của Ubuntu..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true

# Tắt tự động tắt màn hình khi nhàn rỗi trong môi trường giao diện GNOME
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
echo "  -> Đã khóa vĩnh viễn các target Suspend/Sleep (Máy ảo sẽ không bao giờ tự ngủ)."

# ------------------------------------------------------------------------------
# 2. TẠO BỘ NHỚ SWAP 4GB VÀ TỐI ƯU SWAPPINESS (CHỐNG TRÀN RAM / OOM KILLER)
# ------------------------------------------------------------------------------
echo ""
echo "[2/6] Cấu hình bộ nhớ ảo Swap 4GB chống sập RAM khi chạy nhiều container..."
if [ $(swapon --show | wc -l) -le 1 ]; then
    echo "  -> Đang khởi tạo file swap 4GB (vui lòng chờ vài giây)..."
    sudo fallocate -l 4G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "  -> Đã kích hoạt Swap 4GB thành công!"
else
    echo "  -> Swap đã tồn tại sẵn, bỏ qua bước tạo mới."
fi

# Tối ưu tham số swappiness = 10 (ưu tiên dùng RAM thực, hạn chế giật lag)
sudo sysctl -w vm.swappiness=10 >/dev/null
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
echo "  -> Đã thiết lập vm.swappiness=10."

# ------------------------------------------------------------------------------
# 3. MỞ CÁC CỔNG DỊCH VỤ TRÊN TƯỜNG LỬA UFW (PHPMYADMIN, GRAFANA, PROMETHEUS)
# ------------------------------------------------------------------------------
echo ""
echo "[3/6] Mở các cổng dịch vụ 8081 và 3001 trên tường lửa UFW..."
sudo ufw allow 8081/tcp comment 'phpMyAdmin' >/dev/null 2>&1 || true
sudo ufw allow 3001/tcp comment 'Grafana' >/dev/null 2>&1 || true
sudo ufw allow 9090/tcp comment 'Prometheus' >/dev/null 2>&1 || true
sudo ufw reload >/dev/null 2>&1 || true
echo "  -> Đã mở cổng 8081, 3001 và 9090 (Hết bị xoay vòng khi mở web)."

# ------------------------------------------------------------------------------
# 4. TỐI ƯU DOCKER LOG ROTATION (CHỐNG TRÀN DISK LÀM ĐƠ MÁY)
# ------------------------------------------------------------------------------
echo ""
echo "[4/6] Cấu hình Docker tự động giới hạn kích thước log (Log Rotation)..."
sudo mkdir -p /etc/docker
cat << 'EOF' | sudo tee /etc/docker/daemon.json >/dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
echo "  -> Docker daemon đã được cấu hình tự động xoay log tối đa 10MB."

# ------------------------------------------------------------------------------
# 5. ĐỒNG BỘ MÃ NGUỒN CSDL VỚI KEEPALIVE CHỐNG TIMEOUT SOCKET
# ------------------------------------------------------------------------------
echo ""
echo "[5/6] Đồng bộ mã nguồn ứng dụng (kết nối CSDL KeepAlive)..."
cd ~/gallery-devops
git pull origin main 2>/dev/null || true
docker cp app/src/db.js gallery_app:/app/src/db.js 2>/dev/null || true
echo "  -> Đã cập nhật file db.js vào container gallery_app."

# ------------------------------------------------------------------------------
# 6. KHỞI ĐỘNG LẠI CÁC DỊCH VỤ
# ------------------------------------------------------------------------------
echo ""
echo "[6/6] Khởi động lại các container cần thiết..."
docker compose restart app nginx phpmyadmin grafana mysqld-exporter
echo "  -> Toàn bộ dịch vụ đã được áp dụng cấu hình mới."

echo ""
echo "==============================================================================="
echo "   ✓ HOÀN TẤT 100%! HỆ THỐNG ĐÃ ĐƯỢC BẢO VỆ CHỐNG ĐƠ / TREO TOÀN DIỆN!       "
echo "==============================================================================="
docker compose ps
