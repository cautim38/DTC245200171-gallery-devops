# BÁO CÁO BÀI TẬP LỚN
## Học phần: Quản trị và Triển khai Hệ thống Phần mềm
**Trường Đại học Công nghệ Thông tin và Truyền thông Thái Nguyên (ICTU)**  
**Khoa Công nghệ Thông tin**

---

| Thông tin | Chi tiết |
|---|---|
| **Sinh viên thực hiện** | Nguyễn Thành Long |
| **Mã sinh viên (MSSV)** | DTC245200171 |
| **Lớp / Khóa** | CNTT K23C |
| **Tên đề tài** | Đề 31: Hệ thống Thư viện Ảnh / Gallery Management System |
| **Giảng viên hướng dẫn** | ThS. Vũ Việt Dũng |
| **Kho lưu trữ GitHub** | [https://github.com/cautim38/DTC245200171-gallery-devops](https://github.com/cautim38/DTC245200171-gallery-devops) |
| **Học kỳ / Năm học** | Học kỳ I – Năm học 2026 |

---

## CHƯƠNG 1: TỔNG QUAN VÀ PHÂN TÍCH YÊU CẦU

### 1.1 Giới thiệu bài toán và phạm vi đề tài
Trong kỷ nguyên số, nhu cầu lưu trữ, phân loại và chia sẻ hình ảnh số chất lượng cao ngày càng mở rộng. Đề tài **Hệ thống Thư viện Ảnh (Gallery Management System)** xây dựng giải pháp nền tảng web hiện đại cho phép người dùng cá nhân và tổ chức quản lý bộ sưu tập ảnh an toàn, bảo mật và trực quan.

### 1.2 Yêu cầu chức năng
1. **Quản lý xác thực người dùng:** Đăng ký tài khoản mới, Đăng nhập hệ thống (băm mật khẩu bằng Bcrypt muối 10 rounds), Đăng xuất và quản lý phiên làm việc Session an toàn qua cookie HttpOnly.
2. **Quản lý Album ảnh:** Tạo Album mới có tên, mô tả và gắn với Danh mục; Chỉnh sửa thông tin Album; Xóa Album kèm cơ chế dọn sạch ảnh con.
3. **Quản lý và Tải lên hình ảnh (Uploads):** Hỗ trợ tải lên nhiều ảnh đồng thời (Multi-file upload); Lọc kiểm tra định dạng ảnh (MIME Type: JPEG, PNG, WEBP, GIF); Tự động đổi tên tệp theo UUID v4 chống xung đột và chống tấn công Path Traversal.
4. **Phân loại theo Danh mục:** 5 danh mục chính thống (Thiên nhiên, Du lịch, Chân dung, Kiến trúc, Sự kiện) hỗ trợ lọc ảnh nhanh chóng.
5. **Chia sẻ Album công khai:** Tạo liên kết chia sẻ (Public Share Link) kèm token bảo mật ngẫu nhiên (Crypto Token), cho phép người ngoài xem mà không cần tài khoản.

### 1.3 Yêu cầu phi chức năng và Triển khai hệ thống
- **Container hóa:** Đóng gói toàn bộ các dịch vụ bằng Docker và điều phối qua Docker Compose.
- **Bảo mật biên:** Cổng giao tiếp Nginx Reverse Proxy hỗ trợ SSL/TLS 1.2 & 1.3 (HTTPS), áp dụng đầy đủ các HTTP Security Headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options) và Rate Limiting chống Brute-force.
- **Giám sát thời gian thực:** Prometheus thu thập chỉ số container (cAdvisor), web server (nginx-exporter), cơ sở dữ liệu (mysqld-exporter) và ứng dụng Node.js (prom-client); Trực quan hóa qua 3 Dashboard Grafana.
- **Quản lý Log tập trung:** Promtail thu gom nhật ký từ Docker daemon đẩy về Loki Server, hỗ trợ truy vấn LogQL trên Grafana Explore.
- **Gia cố an toàn (Hardening):** Chạy người dùng phi đặc quyền (Non-root user: `node`, `nginx`, `nobody`), cô lập mạng nội bộ CSDL (`internal: true`), giới hạn tài nguyên CPU/RAM và tường lửa UFW.

---

## CHƯƠNG 2: THIẾT KẾ KIẾN TRÚC VÀ CƠ SỞ DỮ LIỆU

### 2.1 Kiến trúc hệ thống
Hệ thống gồm 11 dịch vụ container hóa độc lập được kết nối qua 3 mạng Docker (`frontend`, `backend`, `monitoring`):
- `gallery_nginx`: Reverse Proxy tiếp nhận cổng 80 và 443.
- `gallery_app`: Ứng dụng Node.js v20 / Express.js.
- `gallery_mysql`: CSDL MySQL 8.0 lưu trữ bền vững.
- `gallery_phpmyadmin`: Quản trị CSDL trực quan.
- `gallery_prometheus`: Máy chủ giám sát và lưu trữ Metrics.
- `gallery_grafana`: Trực quan hóa biểu đồ và tra cứu log.
- `gallery_loki`: Lưu trữ và lập chỉ mục nhật ký tập trung.
- `gallery_promtail`: Bộ vận chuyển log từ Docker về Loki.
- `gallery_cadvisor`, `gallery_nginx_exporter`, `gallery_mysqld_exporter`: Các bộ thu thập chỉ số chuyên biệt.

### 2.2 Thiết kế Cơ sở dữ liệu
CSDL `gallery_db` gồm 5 bảng chuẩn hóa:
1. `users`: Lưu trữ thông tin tài khoản (id, username, email, password_hash, created_at).
2. `categories`: 5 danh mục mặc định (id, name, slug, description).
3. `albums`: Bộ sưu tập ảnh của người dùng (id, user_id, category_id, title, description, created_at).
4. `photos`: Tệp ảnh chi tiết (id, album_id, filename, original_name, mime_type, file_size, caption, created_at).
5. `shares`: Liên kết chia sẻ công khai (id, album_id, share_token, is_active, created_at).

---

## CHƯƠNG 3: TRIỂN KHAI VÀ THỰC NGHIỆM

Toàn bộ quá trình triển khai được tự động hóa qua kịch bản `setup.sh` và `docker-compose.yml`. Kết quả kiểm thử trên 6 bước đạt 100% tiêu chí đề ra:
1. Máy chủ Ubuntu 24.04 LTS hoạt động ổn định, đủ tài nguyên (4 CPU, 6GB RAM, 50GB Disk).
2. Toàn bộ 11 container ở trạng thái `Up (healthy)`.
3. Nginx định tuyến chính xác, chuyển hướng HTTP 301 sang HTTPS, chứng chỉ SSL hợp lệ, Rate Limiting chặn brute-force trả mã HTTP 429.
4. Prometheus Scrape Targets đạt trạng thái `UP 5/5`, 3 Dashboard Grafana hiển thị trực quan các chỉ số CPU, RAM, Network và số liệu nghiệp vụ.
5. Loki ghi nhận đầy đủ log Nginx và Gallery App, 4 câu truy vấn LogQL thực thi phản hồi nhanh chóng dưới 50ms.
6. Máy chủ được bảo mật tường lửa UFW (chỉ mở cổng 22, 80, 443), các container chạy non-root user và CSDL MySQL được cô lập nội bộ.

---

## CHƯƠNG 4: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

### 4.1 Kết quả đạt được
- Xây dựng thành công ứng dụng Thư viện Ảnh hoàn chỉnh với kiến trúc vi dịch vụ container hóa an toàn.
- Thiết lập đầy đủ ngăn xếp giám sát và quản lý nhật ký tập trung chuẩn DevOps (Prometheus + Grafana + Loki).
- Tuân thủ toàn diện các quy chuẩn an toàn thông tin và hardening hệ thống.

### 4.2 Hướng phát triển tiếp theo
- Tích hợp thêm dịch vụ lưu trữ phân tán Object Storage (MinIO / S3) để mở rộng dung lượng lưu trữ ảnh không giới hạn.
- Xây dựng cụm Kubernetes (K8s) với cơ chế tự động mở rộng (Horizontal Pod Autoscaler) khi lưu lượng tăng đột biến.
