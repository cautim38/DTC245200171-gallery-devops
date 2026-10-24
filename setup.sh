#!/usr/bin/env bash
# ==============================================================================
# SCRIPT CÀI ĐẶT VÀ KHỞI ĐỘNG HỆ THỐNG GALLERY DEVOPS (1-CLICK)
# ==============================================================================
set -e

echo "=== 1. Khởi tạo biến môi trường .env ==="
if [ ! -f .env ]; then
  cp .env.example .env
  echo "-> Đã tạo tệp .env từ .env.example"
fi

echo "=== 2. Tạo chứng chỉ SSL tự ký nếu chưa có ==="
mkdir -p nginx/certs
if [ ! -f nginx/certs/gallery.crt ]; then
  bash scripts/gen-cert.sh
fi

echo "=== 3. Khởi động các container qua Docker Compose ==="
docker compose up -d

echo "=== 4. Đợi hệ thống ổn định trong 10 giây ==="
sleep 10
docker compose ps

echo "=========================================================="
echo "   HỆ THỐNG GALLERY DEVOPS ĐÃ KHỞI CHẠY THÀNH CÔNG!       "
echo "   Website: https://localhost                            "
echo "   phpMyAdmin: http://localhost:8081                     "
echo "   Grafana: http://localhost:3001                        "
echo "   Prometheus: http://localhost:9090                     "
echo "=========================================================="
