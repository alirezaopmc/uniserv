# uniserv

زنجیرهٔ پروکسی چندلایه با Docker: OpenVPN → SSH SOCKS → Xray (VLESS).

## معماری

```
کلاینت → Gateway:1090 → OpenVPN (relay) → Xray SOCKS → VLESS
                              ↑                ↑
                         تونل VPN          SSH SOCKS → سرور داخلی
```

| سرویس | نقش |
|--------|-----|
| **openvpn** | اتصال VPN دانشگاهی + killswitch + relay پورت ۱۰۹۰ |
| **ssh** | تونل SOCKS به سرور داخلی (از شبکهٔ VPN) |
| **xray** | پروکسی VLESS از طریق SSH SOCKS |
| **gateway** | درگاه عمومی `localhost:1090` |

## راه‌اندازی

```bash
cp config.example.yaml config.yaml
# پروفایل .ovpn را در openvpn/profiles/ بگذارید
# کلید SSH در ~/.ssh یا ssh/keys/
docker compose up -d --build
```

پروکسی SOCKS5: `127.0.0.1:1090`

## Docker Hub

اگر به Docker Hub دسترسی ندارید، mirror تنظیم کنید:

- [آروان‌کلاد](https://www.arvancloud.ir/fa/dev/docker)
- [Runflare](https://runflare.com/mirrors/docker-mirror/) — `https://mirror-docker.runflare.com`

```json
{ "registry-mirrors": ["https://mirror-docker.runflare.com"] }
```
