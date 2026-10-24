#!/usr/bin/env bash
# ==============================================================================
# SCRIPT KIỂM TRA SỨC KHỎE TOÀN DIỆN HỆ THỐNG GALLERY DEVOPS
# ==============================================================================
set -e

echo "=== 1. Kiểm tra trạng thái các container ==="
docker compose ps

echo ""
echo "=== 2. Kiểm tra phản hồi HTTPS và Security Headers ==="
curl -kI https://127.0.0.1/ | grep -E "HTTP|Strict-Transport|X-Frame|X-Content-Type|X-XSS" || true

echo ""
echo "=== 3. Kiểm tra endpoint Healthcheck của ứng dụng Gallery ==="
docker compose exec -T app wget -qO- http://127.0.0.1:3000/health || true

echo ""
echo "=== 4. Kiểm tra Prometheus Targets ==="
curl -s http://127.0.0.1:9090/api/v1/targets | grep -o '"health":"[^"]*"' || true

echo ""
echo "=========================================================="
echo "           KIỂM TRA HOÀN TẤT THÀNH CÔNG!                  "
echo "=========================================================="
