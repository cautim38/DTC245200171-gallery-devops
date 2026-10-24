#!/usr/bin/env bash
# ==============================================================================
# SCRIPT KIỂM THỬ GIỚI HẠN TẦN SUẤT ĐĂNG NHẬP (RATE LIMITING)
# ==============================================================================
echo "=== Gửi liên tiếp 10 yêu cầu vào endpoint /auth/login ==="
for i in {1..10}; do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" https://127.0.0.1/auth/login)
  echo "Request #$i: HTTP Code = $CODE"
  sleep 0.1
done
echo "Nếu thấy các mã HTTP 503 hoặc 429 xuất hiện -> Cơ chế Rate Limit của Nginx hoạt động hoàn hảo!"
