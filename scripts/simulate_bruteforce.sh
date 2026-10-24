#!/usr/bin/env bash
# ==============================================================================
# Kịch bản kiểm thử mô phỏng brute-force đăng nhập để kích hoạt Nginx Rate Limiting
# ==============================================================================
echo "[+] Bắt đầu mô phỏng tấn công Brute-force vào endpoint /auth/login..."
for i in {1..12}; do
    STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST https://localhost/auth/login -d "username=admin&password=wrongpassword$i")
    echo "Attempt $i: HTTP Status $STATUS"
    sleep 0.2
done
echo "[+] Hoàn tất kiểm thử brute-force. Xem nhật ký ghi nhận: docker compose logs nginx"
