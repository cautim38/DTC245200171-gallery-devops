-- ==============================================================================
-- DATABASE INITIALIZATION SCRIPT - GALLERY SYSTEM
-- Mã sinh viên: DTC245200171 - Mã đề: 31
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS `gallery_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `gallery_db`;

-- 1. Bảng người dùng
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) NOT NULL UNIQUE,
    `email` VARCHAR(100) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` ENUM('admin', 'user') DEFAULT 'user',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Bảng phân loại (Categories)
CREATE TABLE IF NOT EXISTS `categories` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Bảng Album
CREATE TABLE IF NOT EXISTS `albums` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `category_id` INT DEFAULT NULL,
    `title` VARCHAR(150) NOT NULL,
    `description` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Bảng Ảnh (Photos)
CREATE TABLE IF NOT EXISTS `photos` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `album_id` INT NOT NULL,
    `filename` VARCHAR(255) NOT NULL,
    `original_name` VARCHAR(255) NOT NULL,
    `mime_type` VARCHAR(50) NOT NULL,
    `size` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`album_id`) REFERENCES `albums`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Bảng Chia sẻ (Shares)
CREATE TABLE IF NOT EXISTS `shares` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `album_id` INT NOT NULL,
    `token` VARCHAR(64) NOT NULL UNIQUE,
    `expires_at` DATETIME DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`album_id`) REFERENCES `albums`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Thêm một số danh mục mặc định
INSERT IGNORE INTO `categories` (`id`, `name`) VALUES
(1, 'Thiên nhiên & Phong cảnh'),
(2, 'Du lịch & Khám phá'),
(3, 'Gia đình & Bạn bè'),
(4, 'Công việc & Dự án'),
(5, 'Nghệ thuật & Thiết kế');

-- Thêm user demo (Mật khẩu mặc định: DemoUser@2026 hash bcrypt)
INSERT IGNORE INTO `users` (`id`, `username`, `email`, `password_hash`, `role`) VALUES
(1, 'demo', 'demo@gallery.local', '$2b$12$dEWaUrKhuO7wgaqPyyMjrOOEQL0hk3khw.xDorftB74GE3tCyQIW2', 'user');

-- Tạo tài khoản mysqld_exporter với quyền tối thiểu (Hardening Biện pháp 4)
CREATE USER IF NOT EXISTS 'mysqld_exporter'@'%' IDENTIFIED BY 'ExporterSecretPass2026!';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'%';
FLUSH PRIVILEGES;
