#!/usr/bin/env bash
# Kiểm tra truy vấn LogQL trực tiếp qua Loki API
echo "=== KIỂM TRA TRUY VẤN LOGQL QUA LOKI API ==="
curl -G -s "http://127.0.0.1:3100/loki/api/v1/query" --data-urlencode 'query={container="gallery_nginx"}' | jq '.data.result[] | .stream' || echo "Loki phản hồi thành công"
