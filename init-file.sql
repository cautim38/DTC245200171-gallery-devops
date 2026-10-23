-- ==============================================================================
-- KHỞI TẠO VÀ ĐỒNG BỘ MẬT KHẨU MYSQL CHO DỰ ÁN GALLERY DEVOPS
-- File này được MySQL thực thi qua cờ --init-file mỗi khi container khởi động
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS `gallery_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 1. Đặt mật khẩu cho root = 123456
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '123456';

-- 2. Đặt mật khẩu cho gallery_app_user = 123456
CREATE USER IF NOT EXISTS 'gallery_app_user'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
ALTER USER 'gallery_app_user'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
GRANT ALL PRIVILEGES ON `gallery_db`.* TO 'gallery_app_user'@'%';

-- 3. Đặt mật khẩu cho mysqld_exporter = 123456 (Quyền tối thiểu: Hardening Biện pháp 4)
CREATE USER IF NOT EXISTS 'mysqld_exporter'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
ALTER USER 'mysqld_exporter'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'%';

FLUSH PRIVILEGES;
