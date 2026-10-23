#!/usr/bin/env bash
# ==============================================================================
# SCRIPT SINH CHỨNG CHỈ SSL/TLS TỰ KÝ CHO NGINX
# Sinh viên: Nguyễn Thành Long - MSSV: DTC245200171
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../nginx/certs"

mkdir -p "${CERTS_DIR}"

CRT_FILE="${CERTS_DIR}/gallery.crt"
KEY_FILE="${CERTS_DIR}/gallery.key"

echo "=== Đang sinh chứng chỉ SSL tự ký cho Gallery DevOps ==="

if [ -f "${CRT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    echo "[INFO] Chứng chỉ SSL đã tồn tại tại ${CERTS_DIR}. Bỏ qua bước tạo lại."
    exit 0
fi

# Tạo file cấu hình OpenSSL với SAN (Subject Alternative Names) để trình duyệt không báo lỗi SAN
OPENSSL_CNF=$(mktemp)
cat <<EOF > "${OPENSSL_CNF}"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = VN
ST = Thai Nguyen
L = Thai Nguyen
O = DTC245200171 DevOps
OU = Gallery System
CN = localhost

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = gallery.local
IP.1 = 127.0.0.1
EOF

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CRT_FILE}" \
    -config "${OPENSSL_CNF}"

rm -f "${OPENSSL_CNF}"

# Phân quyền cho file chứng chỉ (unprivileged nginx user UID 101 có thể đọc)
chmod 644 "${CRT_FILE}"
chmod 644 "${KEY_FILE}"

echo "=== Chứng chỉ SSL đã được tạo thành công! ==="
echo " Certificate: ${CRT_FILE}"
echo " Private Key: ${KEY_FILE}"
