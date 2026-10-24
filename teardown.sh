#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DỪNG VÀ GIẢI PHÓNG HỆ THỐNG GALLERY DEVOPS
# ==============================================================================
set -e

echo "=== Dừng toàn bộ các container hệ thống ==="
docker compose down

echo "Đã dừng và giải phóng an toàn tài nguyên hệ thống (dữ liệu CSDL và ảnh vẫn được bảo toàn)!"
