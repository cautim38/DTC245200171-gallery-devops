#!/usr/bin/env bash
# ==============================================================================
# SCRIPT TỰ ĐỘNG TẢI TỪNG DOCKER IMAGE VỚI CƠ CHẾ AUTO-RETRY
# Giúp khắc phục triệt để lỗi nghẽn mạng TLS timeout khi tải nhiều image cùng lúc
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Đang tối ưu cấu hình DNS cho Docker để tăng tốc độ tải... ===${NC}"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF
sudo systemctl restart docker
sleep 2

IMAGES=(
  "nginxinc/nginx-unprivileged:1.25-alpine"
  "phpmyadmin:5.2.1-apache"
  "prom/prometheus:v2.51.0"
  "grafana/grafana:10.4.1"
  "gcr.io/cadvisor/cadvisor:v0.49.1"
  "nginx/nginx-prometheus-exporter:1.1.0"
  "prom/mysqld-exporter:v0.15.1"
  "grafana/loki:2.9.5"
  "grafana/promtail:2.9.5"
  "mysql:8.0.36"
)

TOTAL=${#IMAGES[@]}
INDEX=1

echo -e "\n${BLUE}=== Bắt đầu tải lần lượt từng image (Tổng cộng: ${TOTAL} images) ===${NC}\n"

for img in "${IMAGES[@]}"; do
  echo -e "${YELLOW}[${INDEX}/${TOTAL}] Đang tải: ${img}...${NC}"
  RETRIES=0
  until docker pull "${img}"; do
    RETRIES=$((RETRIES+1))
    echo -e "${YELLOW}--> Mạng bị nghẽn, tự động thử lại lần ${RETRIES} cho image: ${img}...${NC}"
    sleep 3
    if [ ${RETRIES} -ge 5 ]; then
      echo -e "Đã thử 5 lần, tiếp tục thử..."
    fi
  done
  echo -e "${GREEN}✓ Hoàn tất tải: ${img}${NC}\n"
  INDEX=$((INDEX+1))
done

echo -e "${CYAN}=== Tất cả 10/10 Docker Image đã được tải về máy thành công! ===${NC}"
echo -e "${GREEN}Đang tiến hành khởi chạy hệ thống...${NC}"
docker compose up -d --build

echo -e "\n${GREEN}=== DANH SÁCH CONTAINER ĐANG CHẠY ===${NC}"
docker compose ps
