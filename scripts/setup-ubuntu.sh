#!/usr/bin/env bash
# ==============================================================================
# SCRIPT CÀI ĐẶT TỰ ĐỘNG DỰ ÁN TRÊN UBUNTU (VMware / VPS / Server)
# Đề tài: 31 - Hệ thống Thư viện Ảnh / Gallery
# Sinh viên: Nguyễn Thành Long - MSSV: DTC245200171
# ==============================================================================
set -e

# Màu hiển thị terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${CYAN}       BẮT ĐẦU SETUP HỆ THỐNG GALLERY DEVOPS TRÊN UBUNTU                      ${NC}"
echo -e "${CYAN}       Sinh viên: Nguyễn Thành Long - MSSV: DTC245200171 - Mã đề: 31          ${NC}"
echo -e "${CYAN}==============================================================================${NC}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

# 1. KIỂM TRA QUYỀN SỞ HỮU & CÀI ĐẶT DOCKER
echo -e "\n${BLUE}[1/6] Kiểm tra môi trường Docker & Docker Compose...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker chưa được cài đặt. Đang tiến hành cài đặt Docker Engine chính thức...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Thêm user hiện tại vào docker group
    sudo usermod -aG docker "$USER" || true
    echo -e "${GREEN}Đã cài đặt Docker thành công!${NC}"
else
    echo -e "${GREEN}Docker đã có sẵn: $(docker --version)${NC}"
fi

# Kiểm tra docker compose
if docker compose version &> /dev/null; then
    echo -e "${GREEN}Docker Compose plugin đã sẵn sàng: $(docker compose version)${NC}"
else
    echo -e "${RED}Không tìm thấy docker compose plugin. Đang cài đặt bổ sung...${NC}"
    sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin
fi

# 2. KHỞI TẠO FILE .ENV TỰ ĐỘNG
echo -e "\n${BLUE}[2/6] Kiểm tra cấu hình file biến môi trường .env...${NC}"
if [ ! -f .env ]; then
    echo -e "${YELLOW}Chưa có file .env, đang tự động tạo từ .env.example với mật khẩu bảo mật...${NC}"
    cp .env.example .env

    # Sinh mật khẩu ngẫu nhiên mạnh (Hardening Biện pháp 3)
    ROOT_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)
    APP_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)
    EXP_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)
    SESS_SEC=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 36)
    GRAF_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)

    sed -i "s/SuperSecureRootPass2026!#/${ROOT_PASS}#26/g" .env
    sed -i "s/GalleryAppPass2026!#/${APP_PASS}#26/g" .env
    sed -i "s/ExporterSecretPass2026!/${EXP_PASS}#26/g" .env
    sed -i "s/VerySecretSessionKey_ChangeMeInProduction_987654321/${SESS_SEC}/g" .env
    sed -i "s/GrafanaAdminSecurePass2026!#/${GRAF_PASS}#26/g" .env

    echo -e "${GREEN}Đã tạo file .env với mật khẩu bảo mật ngẫu nhiên!${NC}"
else
    echo -e "${GREEN}File .env đã tồn tại.${NC}"
fi

# 3. SINH CHỨNG CHỈ SSL TỰ KÝ
echo -e "\n${BLUE}[3/6] Sinh chứng chỉ SSL/TLS tự ký cho Nginx...${NC}"
chmod +x scripts/gen-cert.sh
./scripts/gen-cert.sh

# 4. PHÂN QUYỀN THƯ MỤC UPLOADS & LOGS
echo -e "\n${BLUE}[4/6] Thiết lập quyền thư mục...${NC}"
mkdir -p nginx/certs
chmod 755 scripts/*.sh

# 5. TẢI CÁC IMAGE VÀ KHỞI ĐỘNG DOCKER COMPOSE
echo -e "\n${BLUE}[5/6] Tiến hành tải các Docker Image và khởi chạy hệ thống...${NC}"

# Cấu hình DNS Docker để kết nối mạng quốc tế ổn định
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

echo -e "${YELLOW}Đang tải tuần tự từng image để chống nghẽn mạng...${NC}"
for img in "${IMAGES[@]}"; do
  echo -e "--> Đang tải ${img}..."
  until docker pull "${img}"; do
    echo -e "--> Thử lại ${img}..."
    sleep 2
  done
done

docker compose down || true
docker compose up -d --build

# 6. KIỂM TRA TRẠNG THÁI HỆ THỐNG
echo -e "\n${BLUE}[6/6] Đang đợi các dịch vụ khởi động và kiểm tra sức khỏe (Healthcheck)...${NC}"
sleep 10

echo -e "\n${GREEN}=== DANH SÁCH CÁC CONTAINER ĐANG CHẠY ===${NC}"
docker compose ps

# Lấy địa chỉ IP máy Ubuntu hiện tại
HOST_IP=$(hostname -I | awk '{print $1}')

echo -e "\n${CYAN}==============================================================================${NC}"
echo -e "${GREEN}             TRIỂN KHAI HỆ THỐNG HOÀN TẤT THÀNH CÔNG!                         ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e "Các địa chỉ truy cập dịch vụ:"
echo -e " 1. ${YELLOW}Gallery Website (HTTPS):${NC} https://localhost hoặc https://${HOST_IP}"
echo -e " 2. ${YELLOW}phpMyAdmin (Database):${NC}   http://localhost:8081 (hoặc bind 127.0.0.1)"
echo -e " 3. ${YELLOW}Prometheus (Metrics):${NC}    http://localhost:9090"
echo -e " 4. ${YELLOW}Grafana (Dashboards):${NC}    http://localhost:3001"
echo -e " 5. ${YELLOW}Healthcheck Endpoint:${NC}    https://localhost/health (hoặc http://localhost:3000/health)"
echo -e " 6. ${YELLOW}Metrics Endpoint:${NC}        https://localhost/metrics"
echo -e "\nTài khoản kiểm tra nhanh:"
echo -e " - Gallery App Demo:   username: ${GREEN}demo${NC} / password: ${GREEN}DemoUser@2026${NC}"
echo -e " - Grafana Admin:      username: ${GREEN}admin${NC} / xem mật khẩu trong file .env"
echo -e " - phpMyAdmin MySQL:   user: ${GREEN}gallery_app_user${NC} / xem mật khẩu trong file .env"
echo -e "${CYAN}==============================================================================${NC}"
