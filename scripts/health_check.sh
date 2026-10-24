#!/usr/bin/env bash
echo "=== KIỂM TRA SỨC KHỎE HỆ THỐNG GALLERY DEVOPS (ĐỀ 31) ==="
docker compose ps
echo ""
echo "--- Kiểm tra Endpoint nội bộ ---"
curl -s http://localhost:3000/health || echo "Gallery App chưa sẵn sàng"
echo ""
