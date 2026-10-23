# BÀI TẬP LỚN TRIỂN KHAI VÀ QUẢN TRỊ HỆ THỐNG PHẦN MỀM
## Đề tài: 31 – Hệ thống Thư viện Ảnh / Gallery System bằng Docker Compose

| Thông tin | Chi tiết |
|---|---|
| **Họ và tên sinh viên** | Nguyễn Thành Long |
| **Mã số sinh viên (MSSV)**| **DTC245200171** |
| **Ngày sinh** | 05/09/2006 |
| **Mã đề** | **31 – Hệ thống Thư viện Ảnh / Gallery** |
| **Môn học** | Triển khai và Quản trị Hệ thống Phần mềm |
| **Repository GitHub** | [https://github.com/cautim38/DTC245200171-gallery-devops](https://github.com/cautim38/DTC245200171-gallery-devops) |

---

## 1. Sơ đồ Kiến trúc Hệ thống

```
                         Internet / Trình duyệt Người Dùng
                                   │  HTTPS :443 (TLS Tự ký)
                           ┌───────▼────────┐
                           │  Nginx Proxy   │  (nginx-unprivileged, Security Headers, Rate Limit)
                           └───┬────────┬───┘
               mạng "frontend" │        │ mạng "frontend"
                     ┌─────────▼──┐  ┌──▼─────────────┐
                     │ Gallery App│  │   phpMyAdmin   │ (bind 127.0.0.1:8081)
                     │ (Node.js)  │  └──┬─────────────┘
                     └─────┬──────┘     │
               mạng "backend" (internal: true, cách ly hoàn toàn)
                     ┌─────▼────────────▼──┐
                     │      MySQL 8.0      │
                     └─────────────────────┘

  Mạng "monitoring":
   Prometheus ◄── cAdvisor (Metrics CPU/RAM Containers)
              ◄── nginx-prometheus-exporter ◄── Nginx (stub_status)
              ◄── mysqld-exporter ◄── MySQL (user exporter đặc quyền tối thiểu)
              ◄── Gallery App (/metrics qua thư viện prom-client)
   Grafana ──► Prometheus (Trực quan hóa 3 Dashboard Container / Web / DB)
   Grafana ──► Loki (Truy vấn Logs tập trung)
   Promtail ──► Loki (Thu thập logs từ Docker containers & Nginx JSON access log)
```

---

## 2. Danh sách Container & Phân chia Mạng

| Container | Image | Vai trò | Mạng kết nối |
|---|---|---|---|
| `gallery_nginx` | `nginxinc/nginx-unprivileged:1.25-alpine` | Reverse proxy, HTTPS, Security headers, Rate limit | `frontend`, `monitoring` |
| `gallery_app` | `gallery-app:1.0.0` (build từ `node:20-alpine`) | Ứng dụng Gallery (Node.js/Express) | `frontend`, `backend`, `monitoring` |
| `gallery_mysql` | `mysql:8.0.36` | Cơ sở dữ liệu chính | `backend` *(internal)* |
| `gallery_phpmyadmin` | `phpmyadmin:5.2.1-apache` | Quản trị giao diện CSDL | `backend`, `frontend` |
| `gallery_prometheus` | `prom/prometheus:v2.51.0` | Thu thập chỉ số định kỳ | `monitoring` |
| `gallery_grafana` | `grafana/grafana:10.4.1` | Dashboard trực quan hóa | `monitoring` |
| `gallery_cadvisor` | `gcr.io/cadvisor/cadvisor:v0.49.1` | Giám sát tài nguyên container | `monitoring` |
| `gallery_nginx_exporter` | `nginx/nginx-prometheus-exporter:1.1.0` | Xuất chỉ số Nginx | `monitoring`, `frontend` |
| `gallery_mysqld_exporter` | `prom/mysqld-exporter:v0.15.1` | Xuất chỉ số MySQL | `monitoring`, `backend` |
| `gallery_loki` | `grafana/loki:2.9.5` | Lưu trữ Logs tập trung | `monitoring` |
| `gallery_promtail` | `grafana/promtail:2.9.5` | Thu thập và đẩy Logs | `monitoring` |

---

## 3. Yêu cầu Hệ thống

- Hệ điều hành: **Ubuntu 20.04 / 22.04 / 24.04 LTS** (trên VMware Workstation, VPS hoặc máy chủ vật lý).
- Phần mềm: **Docker Engine ≥ 24.0** và **Docker Compose plugin ≥ 2.20**.
- Các cổng cần trống trên máy chủ: `80`, `443`, `3001`, `8081`, `9090`.

---

## 4. Hướng dẫn Cài đặt & Khởi chạy Nhanh trên Ubuntu

### Cách 1: Sử dụng Script tự động hóa 100% (Khuyến nghị)

Chỉ cần chạy lệnh sau trong thư mục dự án trên Ubuntu:
```bash
chmod +x scripts/setup-ubuntu.sh
./scripts/setup-ubuntu.sh
```
Script sẽ tự động:
1. Cài đặt Docker & Docker Compose plugin (nếu máy chưa có).
2. Tạo file `.env` với các mật khẩu ngẫu nhiên an toàn.
3. Sinh chứng chỉ SSL/TLS tự ký với SAN (Subject Alternative Names).
4. Phân quyền và khởi động hệ thống bằng `docker compose up -d --build`.

---

### Cách 2: Các bước thực hiện thủ công

**Bước 1: Chuẩn bị file môi trường**
```bash
cp .env.example .env
# Chỉnh sửa mật khẩu bảo mật trong .env nếu muốn
```

**Bước 2: Sinh chứng chỉ SSL tự ký**
```bash
chmod +x scripts/gen-cert.sh
./scripts/gen-cert.sh
```

**Bước 3: Khởi chạy toàn bộ hệ thống**
```bash
docker compose up -d --build
```

**Bước 4: Kiểm tra trạng thái hoạt động**
```bash
docker compose ps
```

---

## 5. Bảng Địa chỉ Dịch vụ & Tài khoản Mặc định

| Dịch vụ | URL Truy cập | Tài khoản / Mật khẩu |
|---|---|---|
| **Website Gallery (HTTPS)** | `https://localhost` hoặc `https://<IP-Ubuntu>` | Demo: `demo` / `DemoUser@2026` (hoặc tự đăng ký tài khoản mới) |
| **phpMyAdmin** | `http://localhost:8081` | User: `gallery_app_user` hoặc `root` (mật khẩu xem trong file `.env`) |
| **Grafana Dashboard** | `http://localhost:3001` | User: `admin` / Password trong file `.env` |
| **Prometheus Targets** | `http://localhost:9090/targets` | Không cần mật khẩu (đã bind nội bộ 127.0.0.1) |
| **Endpoint Healthcheck** | `https://localhost/health` | Trả về JSON trạng thái hệ thống và sinh viên thực hiện |
| **Endpoint Metrics** | `https://localhost/metrics` | Trả về Prom-client metrics phục vụ Prometheus |

---

## 6. Các Truy vấn LogQL Mẫu (Grafana Explore -> Loki)

| # | Mục đích truy vấn | Câu lệnh LogQL |
|---|---|---|
| 1 | Xem toàn bộ log của Nginx Reverse Proxy | `{container="nginx"}` |
| 2 | Lọc các thông báo lỗi trong ứng dụng Node.js | `{container="app"} \|= "error"` |
| 3 | Đếm số lượng request HTTP 4xx hoặc 5xx trong 5 phút | `sum(count_over_time({container="nginx"} \|~ " (4\|5)[0-9]{2} " [5m]))` |
| 4 | Tốc độ phát sinh log theo từng container | `sum by (container) (rate({job="docker"}[1m]))` |
| 5 | Lọc log cảnh báo hoặc lỗi của MySQL | `{container="mysql"} \|~ "(?i)warning\|error"` |

---

## 7. Các Biện Pháp Hardening & Bảo Mật (≥ 8 Biện pháp)

1. **Non-root Container:**
   - Ứng dụng Node.js chạy dưới user `node` (UID 1000) thông qua Dockerfile multi-stage.
   - Nginx chạy image `nginxinc/nginx-unprivileged` (UID 101).
   - Grafana chạy user `472`, Prometheus chạy user `nobody`.
2. **Network Isolation (Cách ly mạng):**
   - Mạng `backend` được cấu hình `internal: true`. MySQL hoàn toàn không kết nối ra Internet và không publish cổng 3306 ra ngoài máy chủ.
   - Tách biệt rõ ràng 3 mạng: `frontend`, `backend`, `monitoring`.
3. **Mật khẩu mạnh & Không lưu bí mật lên Git:**
   - Tất cả mật khẩu cấu hình qua file `.env` được loại trừ trong `.gitignore`.
   - File `.env.example` chỉ chứa mẫu.
4. **Nguyên tắc Đặc quyền Tối thiểu cho CSDL:**
   - User `gallery_app_user` chỉ được cấp quyền thao tác DML (`SELECT, INSERT, UPDATE, DELETE`).
   - User `mysqld_exporter` chỉ có quyền đọc `PROCESS, REPLICATION CLIENT, SELECT` phục vụ giám sát, không thể sửa đổi dữ liệu.
5. **Security Headers & Ẩn thông tin phiên bản:**
   - Nginx thiết lập `server_tokens off;`
   - Bổ sung các header: `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Content-Security-Policy`, `Referrer-Policy`.
6. **Thu hồi đặc quyền Container:**
   - Nginx áp dụng `cap_drop: [ALL]`, chỉ thêm lại `NET_BIND_SERVICE`.
   - Bật `security_opt: [no-new-privileges:true]`.
7. **Giới hạn Tài nguyên (Resource Quota):**
   - Mọi container trong `docker-compose.yml` đều được giới hạn CPU và RAM (`cpus`, `memory`) để chống cạn kiệt tài nguyên máy chủ.
8. **Hạn chế cổng công khai:**
   - Chỉ mở cổng `80` và `443` cho Nginx ra ngoài.
   - Các dịch vụ quản trị nội bộ (`phpmyadmin`, `prometheus`, `grafana`, `loki`) chỉ bind vào `127.0.0.1`.
9. **Bảo vệ Upload & Chống tấn công thực thi file:**
   - Whitelist định dạng ảnh (`jpeg`, `png`, `webp`, `gif`), chặn file có extension nguy hiểm (.php, .sh, .exe).
   - Đổi tên file tải lên thành chuỗi UUID ngẫu nhiên.
   - Nginx chặn toàn bộ request thực thi file trong thư mục `/uploads/`.
10. **Chống Brute-force bằng Rate Limiting:**
    - Nginx cấu hình `limit_req` áp dụng cho endpoint `/auth/login` (giới hạn 5 request/phút) để ngăn chặn tấn công dò mật khẩu.
11. **Healthcheck & Restart Policy:**
    - Cấu hình `healthcheck` tự động cho App, MySQL, Nginx.
    - `restart: unless-stopped` đảm bảo hệ thống tự phục hồi khi gặp sự cố hoặc máy chủ khởi động lại.

---

## 8. Lịch sử Git Commit Chuẩn Bài Tập Lớn (Theo Tiến Độ Đề Bài)

Khi thực hiện commit lên repository GitHub cá nhân theo yêu cầu giảng viên:

- **Commit 1:**
  `git commit -m "feat: deploy gallery app with MySQL, phpMyAdmin and Nginx reverse proxy (HTTPS + security headers)"`
- **Commit 2:**
  `git commit -m "feat: add Prometheus, Grafana, cAdvisor, nginx and mysqld exporters with dashboards"`
- **Commit 3:**
  `git commit -m "feat: add Loki + Promtail centralized logging with LogQL queries"`
- **Commit 4 (Hardening & Documentation):**
  `git commit -m "chore: apply hardening measures, healthchecks and finalize documentation"`

---

## 9. Hướng dẫn Quản lý Dữ liệu

- **Dừng hệ thống (giữ nguyên dữ liệu):**
  ```bash
  docker compose down
  ```
- **Khởi động lại:**
  ```bash
  docker compose up -d
  ```
- **Backup CSDL MySQL (mysqldump):**
  ```bash
  docker compose exec mysql mysqldump -u gallery_app_user -p gallery_db > backup_$(date +%F).sql
  ```
- **Xóa toàn bộ hệ thống và dữ liệu volume:**
  ```bash
  docker compose down -v
  ```
