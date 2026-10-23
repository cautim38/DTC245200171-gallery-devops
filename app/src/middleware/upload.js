const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');

const uploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../../uploads');

// Đảm bảo thư mục uploads tồn tại
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Cấu hình lưu trữ an toàn: Đổi tên file thành UUID ngẫu nhiên (Hardening Biện pháp 9)
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname).toLowerCase();
    const safeFilename = `${uuidv4()}${ext}`;
    cb(null, safeFilename);
  }
});

// Whitelist định dạng MIME & phần mở rộng (Hardening Biện pháp 9)
const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif'
];

const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

function fileFilter(req, file, cb) {
  const ext = path.extname(file.originalname).toLowerCase();
  
  if (!ALLOWED_EXTENSIONS.includes(ext) || !ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    const error = new Error('Chỉ chấp nhận các định dạng ảnh hợp lệ (.jpg, .jpeg, .png, .webp, .gif)!');
    error.code = 'INVALID_FILE_TYPE';
    return cb(error, false);
  }
  
  cb(null, true);
}

const maxFileSizeMB = parseInt(process.env.UPLOAD_MAX_SIZE_MB || '10', 10);

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: maxFileSizeMB * 1024 * 1024 // Giới hạn kích thước file
  }
});

module.exports = {
  upload,
  uploadDir
};
