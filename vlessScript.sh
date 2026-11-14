python3 - <<'PY'
import urllib.parse

def read_clean(path):
    with open(path, 'r') as f:
        return "".join(f.read().split())

try:
    uuid = read_clean('/tmp/xray_uuid.txt')
    pbk = read_clean('/tmp/xray_pub.txt')
    sid = read_clean('/tmp/xray_sid.txt')
except FileNotFoundError:
    print("Ошибка: Файлы с ключами не найдены. Запустили ли вы первый скрипт?")
    exit(1)

params = {
    "encryption": "none",
    "type": "tcp",
    "security": "reality",
    "sni": "swdist.apple.com",
    "fp": "chrome",
    "pbk": pbk,
    "sid": sid,
    "flow": "xtls-rprx-vision"
}

query = "&".join(f"{k}={urllib.parse.quote(v, safe='')}" for k, v in params.items())
link = f"vless://{urllib.parse.quote(uuid, safe='')}@144.31.157.12:443?{query}#MyVPN"

print("\n" + "="*60)
print("ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ:")
print("="*60)
print(link)
print("="*60 + "\n")
PY
