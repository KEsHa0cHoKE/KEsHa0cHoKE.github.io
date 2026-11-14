cat > /tmp/setup-xray-reality.sh <<'OUTER_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# ---------- проверка xray ----------
if ! command -v xray >/dev/null 2>&1; then
  echo "[!] xray не найден в PATH. Установите Xray-core и повторите." >&2
  exit 1
fi

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PORT=443
SNI="swdist.apple.com"
DEST="${SNI}:443"

# ---------- генерация UUID ----------
UUID="$(xray uuid | tr -d '[:space:]')"

# ---------- генерация X25519 ----------
KEYS="$(xray x25519)"
PRIVATE_KEY="$(printf '%s\n' "$KEYS" | grep -i private | awk '{print $NF}' | tr -d '[:space:]')"
PUBLIC_KEY="$(printf '%s\n' "$KEYS" | grep -i public | awk '{print $NF}' | tr -d '[:space:]')"

if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
  echo "[!] Не удалось извлечь X25519-ключи. Вывод xray x25519:" >&2
  printf '%s\n' "$KEYS" >&2
  exit 1
fi

# ---------- shortId (8 байт hex = 16 символов) ----------
SHORT_ID="$(openssl rand -hex 8)"

# ---------- запись config.json ----------
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${DEST}",
          "xver": 0,
          "serverNames": [
            "${SNI}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

echo "[+] config.json записан: ${CONFIG_FILE}"

# ---------- сохраняем значения для генератора ссылки ----------
printf '%s\n' "$UUID"        > /tmp/xray_uuid.txt
printf '%s\n' "$PUBLIC_KEY"  > /tmp/xray_pub.txt
printf '%s\n' "$SHORT_ID"   > /tmp/xray_sid.txt

# ---------- проверка JSON ----------
if command -v jq >/dev/null 2>&1; then
  if ! jq empty "$CONFIG_FILE"; then
    echo "[!] JSON невалиден. Проверьте файл вручную." >&2
    exit 1
  fi
  echo "[+] JSON валиден."
fi

# ---------- перезапуск ----------
systemctl restart xray

# ---------- статус и порт ----------
sleep 1
systemctl --no-pager --full status xray | sed -n '1,12p'

if command -v ss >/dev/null 2>&1; then
  ss -lntp | grep -E ":${PORT}\b" || {
    echo "[!] Порт ${PORT} не прослушивается. Смотрите journalctl -u xray -n 50" >&2
    exit 1
  }
fi

echo "[+] Готово. UUID: ${UUID}"
echo "[+] Public key: ${PUBLIC_KEY}"
echo "[+] Short ID:  ${SHORT_ID}"
OUTER_SCRIPT

chmod +x /tmp/setup-xray-reality.sh
/tmp/setup-xray-reality.sh
