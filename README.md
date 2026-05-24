# uniserv

زنجیرهٔ پروکسی با Docker: OpenVPN → Xray (VLESS) → Gateway.

## معماری

```
کلاینت → Gateway:1090 → OpenVPN (relay) → Xray SOCKS → VLESS
                              ↑
                         تونل VPN
```

| سرویس | نقش |
|--------|-----|
| **openvpn** | اتصال VPN + killswitch + relay پورت ۱۰۹۰ |
| **xray** | پروکسی VLESS (از شبکهٔ VPN) |
| **gateway** | درگاه عمومی `localhost:1090` |

## راه‌اندازی

```bash
cp config.example.yaml config.yaml
# پروفایل .ovpn را در openvpn/profiles/ بگذارید
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
