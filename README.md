# Đề 31: Hệ thống Thư viện Ảnh / Gallery Management System

### Báo cáo Môn học: Quản trị và Triển khai Hệ thống Phần mềm
**Trường Đại học Công nghệ Thông tin và Truyền thông Thái Nguyên (ICTU)**  
**Khoa Công nghệ Thông tin**

---

## Thông tin sinh viên & Đề tài

- **Sinh viên thực hiện:** Nguyễn Thành Long
- **Mã số sinh viên (MSSV):** DTC245200171
- **Lớp / Khóa:** CNTT K23C
- **Học phần:** Quản trị và Triển khai Hệ thống Phần mềm
- **Giảng viên hướng dẫn:** ThS. Vũ Việt Dũng
- **Kho lưu trữ mã nguồn:** [https://github.com/cautim38/DTC245200171-gallery-devops](https://github.com/cautim38/DTC245200171-gallery-devops)
- **Học kỳ / Năm học:** Học kỳ I – Năm học 2026

---

## 1. Tổng quan hệ thống

Hệ thống được xây dựng và triển khai theo kiến trúc vi dịch vụ container hóa (Docker Compose) nhằm cung cấp giải pháp lưu trữ, phân loại và chia sẻ thư viện ảnh số trực tuyến an toàn với đầy đủ các phân hệ:

1. **Phần mềm ứng dụng Web (Gallery App):** Ứng dụng web viết trên nền tảng Node.js v20 (Express Framework, view engine EJS, giao diện Glassmorphism hiện đại), hỗ trợ đầy đủ các chức năng: Đăng ký, Đăng nhập (băm mật khẩu Bcrypt an toàn), Tạo/sửa/xóa Album, Tải lên nhiều ảnh (kiểm tra kép whitelist MIME type, đổi tên UUID an toàn), Phân loại theo 5 Danh mục, và Tạo liên kết chia sẻ công khai qua Token ngẫu nhiên (Crypto API).
2. **Cơ sở dữ liệu:** Hệ quản trị cơ sở dữ liệu MySQL 8.0 lưu trữ bền vững qua Docker volume `gallery_mysql_data`, bảng mã ký tự chuẩn `utf8mb4_unicode_ci` hỗ trợ hoàn hảo tiếng Việt có dấu; đi kèm công cụ quản trị trực quan phpMyAdmin 5.2 được định tuyến an toàn.
3. **Cổng giao tiếp biên (Reverse Proxy):** Nginx (unprivileged Alpine) đóng vai trò điểm tiếp nhận duy nhất, định tuyến toàn bộ lưu lượng cổng 80 (HTTP chuyển hướng 301), cổng 443 (HTTPS TLS 1.2/1.3 tự ký), áp dụng đầy đủ các HTTP Security Headers và giới hạn tần suất truy cập (Rate Limiting).
4. **Hệ thống giám sát hiệu năng (Observability):** Bộ ba Prometheus 2.51, cAdvisor và Grafana 10.4 thu thập chỉ số container, web server, database và ứng dụng Node.js (`prom-client`) theo thời gian thực; tích hợp sẵn 3 bộ Dashboard quản trị trực quan.
5. **Quản lý nhật ký tập trung (Centralized Logging):** Promtail tự động thu thập log từ tất cả các Docker container đẩy về Loki Server 2.9, hỗ trợ truy vấn lọc lỗi và phân tích sự cố an toàn thông tin bằng ngôn ngữ LogQL trên Grafana Explore.
6. **Bảo mật và gia cố hệ thống (Hardening):** Áp dụng toàn diện hơn 8 biện pháp gia cố: Chạy non-root user, cô lập mạng nội bộ `backend` (`internal: true`), ẩn thông tin phiên bản, loại bỏ đặc quyền container (`cap_drop`, `no-new-privileges`), giới hạn hạn ngạch tài nguyên CPU/RAM, chặn thực thi mã độc trong thư mục tải lên.

---

## 2. Sơ đồ kiến trúc tổng thể

```
[ Người dùng / Trình duyệt Client ]
             │
             │ Port 80 (HTTP -> 301 HTTPS), Port 443 (HTTPS TLS)
             ▼
┌────────────────────────────────────────────────────────┐
│               NGINX REVERSE PROXY                     │
│  - Điều hướng: /           -> Gallery Node.js App (:3000)│
│  - Điều hướng: /stub_status-> Stub status nội bộ       │
│  - HTTPS SSL TLS 1.2/1.3 tự ký (certs/gallery.crt, key)│
│  - HTTP Security Headers, Rate Limiting, Chặn file độc │
└──────┬───────────────────────┬─────────────────────────┘
       │ Network: frontend     │ Network: frontend
       ▼                       ▼
┌──────────────┐        ┌─────────────┐        ┌──────────────┐
│ Gallery App  │        │ phpMyAdmin  │        │   Grafana    │
│  (Node.js)   │        │   (:8081)   │        │  Dashboard   │
└──────┬───────┘        └──────┬──────┘        └──────▲───────┘
       │ Network: backend      │ Network: backend     │
       └──────────────┬────────┘                      │
                      ▼                               │
              ┌────────────────┐       Network:       │
              │   MySQL 8.0    │      monitoring      │
              │ (Data Volume)  │                      │
              └────────────────┘                      │
                                                      │
┌─────────────────────────────────────────────────────┼──────┐
│                  HỆ THỐNG GIÁM SÁT                  │      │
│  [cAdvisor]          ──┐                            │      │
│  [nginx-exporter]    ──┼─> [Prometheus :9090] ──────┘      │
│  [mysqld-exporter]   ──┤                                   │
│  [Gallery /metrics]  ──┘                                   │
│                                                            │
│  [Promtail Agent]    ────> [Loki Server :3100] ────────────┘
└────────────────────────────────────────────────────────────┘
```

---

## 3. Danh mục dịch vụ (Service Matrix)

Toàn bộ 11 container được điều phối tập trung qua `docker-compose.yml`:

| STT | Tên Service | Container Name | Docker Image | Cổng nội bộ | Cổng Host | Vai trò |
|:---:|:---|:---|:---|:---:|:---:|:---|
| 1 | **nginx** | `gallery_nginx` | nginxinc/nginx-unprivileged:1.25-alpine | 8080, 8443 | **80, 443** | Cổng tiếp nhận duy nhất, reverse proxy, SSL HTTPS, bảo mật HTTP |
| 2 | **app** | `gallery_app` | build (node:20-alpine) | 3000 | Không | Ứng dụng Quản lý Thư viện Ảnh (Express, EJS, Bcrypt, Multer) |
| 3 | **mysql** | `gallery_mysql` | mysql:8.0.36 | 3306 | Không | Lưu trữ CSDL `gallery_db`, cô lập mạng backend không ra internet |
| 4 | **phpmyadmin** | `gallery_phpmyadmin` | phpmyadmin:5.2.1-apache | 80 | **127.0.0.1:8081** | Giao diện web quản trị CSDL MySQL, chỉ bind localhost |
| 5 | **prometheus** | `gallery_prometheus` | prom/prometheus:v2.51.0 | 9090 | **127.0.0.1:9090** | Thu thập và lưu trữ metrics từ các exporter định kỳ 30s |
| 6 | **grafana** | `gallery_grafana` | grafana/grafana:10.4.1 | 3000 | **127.0.0.1:3001** | Trực quan hóa dashboard giám sát, cảnh báo và LogQL |
| 7 | **loki** | `gallery_loki` | grafana/loki:2.9.5 | 3100 | **127.0.0.1:3100** | Máy chủ lưu trữ và lập chỉ mục nhật ký (log) tập trung |
| 8 | **promtail** | `gallery_promtail` | grafana/promtail:2.9.5 | Không | Không | Thu thập log từ Docker containers qua docker.sock đẩy về Loki |
| 9 | **cadvisor** | `gallery_cadvisor` | gcr.io/cadvisor/cadvisor:v0.49.1 | 8080 | Không | Thu thập chỉ số tài nguyên phần cứng (CPU, RAM, Disk) từng container |
| 10 | **nginx-exporter** | `gallery_nginx_exporter` | nginx/nginx-prometheus-exporter:1.1.0 | 9113 | Không | Đọc `/stub_status` của Nginx xuất chỉ số kết nối cho Prometheus |
| 11 | **mysqld-exporter** | `gallery_mysqld_exporter` | prom/mysqld-exporter:v0.15.1 | 9104 | Không | Kết nối MySQL qua quyền tối thiểu, xuất số liệu truy vấn DB |

---

## 4. Bảng thông tin truy cập & Tài khoản mặc định

| Dịch vụ | Địa chỉ URL | Tài khoản mặc định | Mật khẩu mặc định | Ghi chú |
|:---|:---|:---|:---|:---|
| **Website Thư viện Ảnh (HTTP)** | `http://<SERVER_IP>/` | *(Khách xem)* | *(Công khai)* | Tự động chuyển hướng 301 sang HTTPS |
| **Website Thư viện Ảnh (HTTPS)** | `https://<SERVER_IP>/` | `long` / `demo` | `123456` | Giao thức mã hóa SSL TLS 1.3 an toàn |
| **phpMyAdmin** | `http://<SERVER_IP>:8081` | `root` | `123456` | Quản lý toàn diện database `gallery_db` |
| **phpMyAdmin (App user)** | `http://<SERVER_IP>:8081` | `gallery_app_user` | `123456` | Tài khoản ứng dụng giới hạn quyền dữ liệu |
| **Grafana Dashboard** | `http://<SERVER_IP>:3001` | `admin` | `123456` | Theo dõi 3 dashboards và tra cứu log |
| **Prometheus Targets** | `http://<SERVER_IP>:9090/targets` | *(Không)* | *(Không)* | Kiểm tra trạng thái các thành phần giám sát |

> [!NOTE]
> **Hướng dẫn truy cập hệ thống:**
> - `<SERVER_IP>` là địa chỉ IP của máy chủ / máy ảo Ubuntu của bạn. Trên terminal máy ảo Ubuntu, chạy lệnh `hostname -I` (hoặc `ip a`) để lấy IP (ví dụ: `192.168.1.50`).
> - **Truy cập trực tiếp trên máy ảo Ubuntu:** Thay `<SERVER_IP>` bằng `localhost`:
>   - Web Gallery: [https://localhost/](https://localhost/) hoặc [http://localhost/](http://localhost/)
>   - phpMyAdmin: [http://localhost:8081](http://localhost:8081)
>   - Grafana Dashboard: [http://localhost:3001](http://localhost:3001)
>   - Prometheus Targets: [http://localhost:9090/targets](http://localhost:9090/targets)
> - **Truy cập từ trình duyệt máy tính Windows:** Nhập `https://<IP_Ubuntu>/` (ví dụ `https://192.168.1.50/`). Nếu trình duyệt cảnh báo chứng chỉ SSL tự ký, bấm **Nâng cao (Advanced) -> Tiếp tục truy cập (Proceed)**.

---

## 5. Hướng dẫn cài đặt và triển khai

### Yêu cầu môi trường tối thiểu
- Hệ điều hành: Ubuntu 22.04 LTS hoặc Ubuntu 24.04 LTS
- Docker Engine >= 24.0.0, Docker Compose Plugin >= 2.20.0
- Phần cứng tối thiểu: 2 vCPU, 4GB RAM, 20GB dung lượng đĩa khả dụng

### Cách 1: Cài đặt tự động 1 lệnh duy nhất (Khuyên dùng)
Mở cửa sổ Terminal trên máy chủ Ubuntu và thực thi lệnh sau:

```bash
sudo apt update && sudo apt install -y git && git clone https://github.com/cautim38/DTC245200171-gallery-devops.git ~/gallery-devops && cd ~/gallery-devops && bash setup.sh
```

### Cách 2: Triển khai thủ công từng bước

```bash
# 1. Tải mã nguồn dự án từ GitHub
git clone https://github.com/cautim38/DTC245200171-gallery-devops.git ~/gallery-devops
cd ~/gallery-devops

# 2. Khởi tạo tệp cấu hình biến môi trường
cp .env.example .env

# 3. Tạo chứng chỉ SSL tự ký cho HTTPS (nếu chưa có)
bash scripts/gen-cert.sh

# 4. Khởi động toàn bộ các container ở chế độ chạy ngầm
docker compose up -d

# 5. Kiểm tra sức khỏe toàn bộ hệ thống
bash verify.sh
```

---

## 6. Cấu hình Nginx Reverse Proxy & Bảo mật HTTP

Tệp cấu hình Nginx (`nginx/conf.d/gallery.conf`) áp dụng các chuẩn cấu hình biên an toàn:

- **Hỗ trợ SSL HTTPS:** Cổng 443 nạp chứng chỉ SSL X.509 (`nginx/certs/gallery.crt`, `gallery.key`), bật giao thức TLSv1.2, TLSv1.3.
- **Định tuyến Stub Status:** Cấu hình riêng `location /stub_status` tại cổng 8080 cho phép exporter nội bộ thu thập số liệu mà không bị chuyển hướng.
- **Bảo vệ thư mục Uploads:** Chặn triệt để nguy cơ thực thi mã độc trong thư mục ảnh tải lên:
  ```nginx
  location ~* ^/uploads/.*.(php|sh|pl|py|cgi|exe|bat|js)$ {
      deny all;
      return 403;
  }
  ```
- **HTTP Security Headers áp dụng:**
  ```nginx
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-XSS-Protection "1; mode=block" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob:; connect-src 'self';" always;
  add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
  server_tokens off;
  ```
  - `Strict-Transport-Security`: Bắt buộc trình duyệt ghi nhớ và chỉ sử dụng kết nối HTTPS an toàn.
  - `X-Frame-Options: SAMEORIGIN`: Chống tấn công Clickjacking lồng frame lừa đảo.
  - `X-Content-Type-Options: nosniff`: Ngăn chặn trình duyệt đoán định sai MIME-type để thực thi tệp tin giả mạo.
  - `X-XSS-Protection: 1; mode=block`: Bật bộ lọc chống Cross-Site Scripting.
  - `server_tokens off`: Ẩn thông tin phiên bản máy chủ Nginx trong header phản hồi HTTP.

---

## 7. Giám sát hệ thống & Quản lý Log tập trung

### Prometheus Metrics
Prometheus tự động cào chỉ số định kỳ mỗi 30 giây từ các mục tiêu:
- `cadvisor`: Đo lường chi tiết mức tiêu thụ CPU, RAM, Network I/O của từng container.
- `nginx-exporter`: Đo lường chỉ số kết nối máy chủ web Nginx (`/stub_status`).
- `mysqld-exporter`: Đo lường hiệu năng truy vấn, kết nối CSDL MySQL.
- `gallery-app`: Đo lường số request, độ trễ và số ảnh upload qua `/metrics`.
- `prometheus`: Tự giám sát tiến trình nội bộ.

### Grafana Dashboard
Hệ thống nạp tự động qua cơ chế provisioning 3 bộ Dashboard quản trị chuyên biệt:
- **Gallery - Containers Dashboard:** Trực quan hóa CPU, RAM tiêu thụ theo thời gian thực của toàn bộ 11 container.
- **Gallery - Nginx Dashboard:** Theo dõi lưu lượng truy cập web, kết nối hoạt động và chuyển hướng HTTPS.
- **Gallery - MySQL Dashboard:** Theo dõi số lượng câu lệnh SQL thực thi, lưu lượng đọc/ghi và trạng thái kết nối CSDL.

### Loki & Các câu truy vấn LogQL tiêu biểu
Trên giao diện **Grafana -> Explore**, chọn nguồn dữ liệu **Loki** để tra cứu nhật ký hoạt động:

```logql
# 1. Xem toàn bộ log truy cập máy chủ web Nginx
{container="gallery_nginx"}

# 2. Lọc các thông điệp cảnh báo hoặc lỗi trong ứng dụng Gallery
{container="gallery_app"} |= "error"

# 3. Lọc toàn bộ sự kiện đăng nhập thất bại phục vụ điều tra an toàn thông tin
{container="gallery_app"} |= "LOGIN_FAILED"

# 4. Đo tần suất ghi log theo từng container để phát hiện bất thường
sum by (container) (rate({job="docker"}[1m]))
```

---

## 8. Các biện pháp Hardening (Gia cố an toàn thông tin)

Hệ thống được gia cố toàn diện thông qua thiết kế kiến trúc và cấu hình container:

| STT | Biện pháp bảo mật | Công cụ / Cấu hình | Mục đích & Hiệu quả đạt được |
|:---:|:---|:---|:---|
| 1 | **Phân tách mạng nội bộ** | Docker Networks | Phân chia thành 3 mạng độc lập: `frontend`, `backend` (`internal: true`), `monitoring`. MySQL hoàn toàn cách ly, không ra ngoài internet và không mở cổng 3306 ra máy chủ. |
| 2 | **Chạy Non-root User** | `USER node` / `nobody` | Gallery App chạy bằng UID 1000 (`node`), Nginx unprivileged chạy UID 101, Prometheus chạy UID 65534 (`nobody`). Tuyệt đối không chạy container bằng quyền root. |
| 3 | **Bảo vệ biến môi trường** | `.env` & `.gitignore` | Mật khẩu và khóa bí mật lưu trong file `.env` được bảo mật, tuyệt đối không commit lên kho lưu trữ GitHub công khai. |
| 4 | **Quyền CSDL tối thiểu** | MySQL Grants | Tài khoản `gallery_app_user` chỉ được cấp quyền `SELECT, INSERT, UPDATE, DELETE` trên `gallery_db`; tài khoản exporter chỉ có quyền giám sát. |
| 5 | **Giới hạn quyền Container** | `security_opt` & `cap_drop` | Áp dụng `no-new-privileges: true` trên tất cả container; Nginx áp dụng `cap_drop: [ALL]` và chỉ bật `NET_BIND_SERVICE`. |
| 6 | **Giới hạn tài nguyên** | Resource Quotas | Cấu hình `cpus` và `memory` limits chặt chẽ cho từng container, chống cạn kiệt tài nguyên máy chủ do tấn công DoS/OOM. |
| 7 | **Hạn chế cổng mở** | Minimal Attack Surface | Chỉ công khai cổng 80 và 443 của Nginx ra ngoài; phpMyAdmin (8081), Prometheus (9090), Grafana (3001) chỉ bind duy nhất `127.0.0.1`. |
| 8 | **Bảo vệ tệp tin upload** | Whitelist & UUID | Kiểm tra kép MIME type và extension (.jpg, .jpeg, .png, .webp, .gif), đổi tên file thành UUID ngẫu nhiên, chặn thực thi mã độc trong `/uploads`. |
| 9 | **Giới hạn tần suất** | Nginx Rate Limiting | Cấu hình `limit_req` tại `/auth/login` giới hạn 5 request/phút, ngăn chặn triệt để tấn công dò quét mật khẩu Brute-force. |
| 10 | **Tự phục hồi hệ thống** | Healthcheck & Restart | Cấu hình `healthcheck` tự động cho App, MySQL, Nginx kết hợp `restart: unless-stopped` đảm bảo hệ thống tự phục hồi khi có sự cố. |

---

## 9. Cấu trúc thư mục mã nguồn

```
DTC245200171-gallery-devops/
├── docker-compose.yml          # Cấu hình điều phối toàn bộ 11 container microservices
├── .env.example                # Tệp mẫu cấu hình biến môi trường và mật khẩu an toàn
├── .gitignore                  # Danh sách tệp loại trừ khỏi Git (.env, node_modules, uploads)
├── README.md                   # Báo cáo môn học và tài liệu hướng dẫn kỹ thuật chi tiết
├── setup.sh                    # Kịch bản tự động hóa cài đặt và khởi động toàn bộ hệ thống
├── verify.sh                   # Kịch bản tự động kiểm tra sức khỏe hệ thống
├── teardown.sh                 # Kịch bản dừng và giải phóng an toàn tài nguyên
├── test-ratelimit.sh           # Kịch bản kiểm thử giới hạn tần suất đăng nhập (HTTP 429)
├── init-file.sql               # Script khởi tạo mật khẩu và quyền MySQL chuẩn tự động
├── app/                        # Ứng dụng Quản lý Thư viện Ảnh (Node.js/Express)
│   ├── Dockerfile              # Multi-stage build tối ưu, bảo mật non-root USER node
│   ├── package.json            # Khai báo thư viện phụ thuộc (Express, Bcrypt, Multer, Prom-client)
│   ├── db/
│   │   └── init.sql            # Script tạo cấu trúc 5 bảng CSDL và danh mục mặc định
│   └── src/
│       ├── server.js           # Khởi tạo HTTP server, tích hợp middleware và healthcheck
│       ├── db.js               # Kết nối MySQL Pool bảng mã utf8mb4 hỗ trợ tiếng Việt
│       ├── metrics.js          # Khởi tạo Prom-client thu thập số liệu Prometheus
│       ├── middleware/         # Middleware xác thực phiên và bộ lọc upload an toàn
│       ├── routes/             # Định tuyến nghiệp vụ: auth, albums, photos, shares
│       └── views/              # Giao diện Glassmorphism hiện đại (EJS view engine)
├── nginx/                      # Cổng tiếp nhận biên Reverse Proxy
│   ├── nginx.conf              # Cấu hình chính của máy chủ Nginx
│   ├── conf.d/
│   │   └── gallery.conf        # Định tuyến HTTP (80), HTTPS SSL (443), Security Headers, Rate Limiting
│   └── certs/                  # Thư mục lưu trữ chứng chỉ SSL tự ký
├── prometheus/                 # Hệ thống thu thập chỉ số hiệu năng (Metrics)
│   └── prometheus.yml          # Cấu hình scrape interval 30s và 5 targets giám sát
├── grafana/                    # Trực quan hóa Dashboard quản trị
│   └── provisioning/
│       ├── datasources/        # Tự động kết nối Prometheus và Loki datasources
│       └── dashboards/         # Tự động nạp 3 dashboard giám sát Containers, Web, Database
├── loki/                       # Hệ thống quản lý nhật ký tập trung (Centralized Logging)
│   └── loki-config.yml         # Cấu hình lưu trữ và phân vùng log của Loki Server
├── promtail/                   # Bộ thu gom log đẩy về Loki (Log Shipper)
│   └── promtail-config.yml     # Cấu hình đường dẫn Docker socket và gắn nhãn log
└── scripts/                    # Các kịch bản kiểm thử và hỗ trợ vận hành
    ├── gen-cert.sh             # Script OpenSSL tự động tạo chứng chỉ SSL X.509 tự ký
    └── pull-images.sh          # Kịch bản tải trước toàn bộ Docker images
```

---

## 10. Lệnh dừng và gỡ bỏ hệ thống

```bash
# Dừng hệ thống nhưng giữ nguyên dữ liệu CSDL và ảnh đã upload
docker compose down

# Dừng và giải phóng toàn bộ dịch vụ thông qua script
bash teardown.sh
```

---

## Giấy phép & Tác quyền

Đề tài Báo cáo Môn học được xây dựng và hoàn thiện bởi sinh viên **Nguyễn Thành Long (MSSV: DTC245200171)** thuộc Khoa Công nghệ Thông tin – Trường Đại học Công nghệ Thông tin và Truyền thông Thái Nguyên (ICTU). Mã nguồn phát hành dưới giấy phép MIT License nhằm phục vụ mục đích học tập và nghiên cứu học phần.
