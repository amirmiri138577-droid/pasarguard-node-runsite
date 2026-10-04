# PasarGuard Node روی Runsite + Relay روی Railway

این معماری دو سرویس دارد:

- **این مخزن روی Runsite** اجرا می‌شود و PasarGuard Node را بالا می‌آورد.
- **مخزن `node-relay` روی Railway** به‌عنوان Rathole server اجرا می‌شود.
- Node از Runsite به‌صورت outbound به Relay وصل می‌شود؛ بنابراین Runsite لازم نیست پورت TCP خام 62050 را عمومی کند.

## 1. استقرار Relay روی Railway

از مخزن `node-relay` یک Service بساز و Dockerfile پیش‌فرض را استفاده کن.

Environment variable:

```text
RATHOLE_TOKEN=<یک مقدار تصادفی طولانی و یکسان برای هر دو سرویس>
RATHOLE_CONTROL_PORT=2333
RATHOLE_DATA_PORT=62050
RATHOLE_USER_PORT=8443
```

روی Service در Railway سه TCP Proxy بساز:

| کاربرد | پورت داخلی | متغیر/استفاده |
|---|---:|---|
| کنترل Rathole | 2333 | `RATHOLE_SERVER_ADDR` در Runsite |
| API نود PasarGuard | 62050 | آدرس Node در پنل |
| ترافیک کاربر | 8443 | `RATHOLE_USER_PORT` و ورودی‌های کاربر |

از هر Proxy مقدار `host:public-port` را یادداشت کن. `RATHOLE_SERVER_ADDR` باید آدرس Proxy کنترل باشد، نه private domain.

## 2. استقرار Node روی Runsite

Repository همین پروژه را به Runsite وصل کن. Runsite به‌دلیل وجود Dockerfile آن را build می‌کند.

Environment variables:

```text
PORT=8080
SERVICE_PORT=62050
SERVICE_PROTOCOL=grpc
NODE_HOST=0.0.0.0
TUNNEL_ENABLED=true
RATHOLE_SERVER_ADDR=<آدرس عمومی TCP پروکسی کنترل Railway، مثل host:port>
RATHOLE_TOKEN=<دقیقاً همان مقدار Railway>
RATHOLE_LOCAL_PORT=62050
RATHOLE_USER_PORT=8443
NODE_PUBLIC_HOST=<دامنه‌ای که برای Proxy داده Railway به پنل می‌دهی>
API_KEY=<یک UUID معتبر>
AUTO_GENERATE_CERT=true
REGENERATE_CERT_ON_HOST_CHANGE=true
PRINT_CONNECTION_INFO=true
```

`NODE_PUBLIC_HOST` باید فقط hostname باشد، بدون `https://` و بدون پورت. بهتر است hostname پروکسی دادهٔ Railway باشد؛ گواهی خودامضای Node برای همین نام ساخته می‌شود.

Runsite settings:

```text
Build & Deploy port: 8080
Health check path: /health
Minimum instances: 1
Sleep on idle: Disabled
Autoscaling: Disabled یا حداکثر 1 instance
```

اگر Runsite اجازهٔ Persistent Disk می‌دهد، آن را روی مسیر زیر Mount کن:

```text
/var/lib/pg-node
```

بدون Volume، بعد از restart یا redeploy ممکن است API key و certificate عوض شوند و لازم باشد اطلاعات Node را دوباره در پنل وارد کنی.

## 3. اطلاعات اتصال در پنل PasarGuard

از Log سرویس Runsite یا فایل `connection-info.txt` اطلاعات زیر را بردار:

```text
Address: hostname پروکسی دادهٔ Railway
Port: public port پروکسی دادهٔ Railway
Protocol: grpc
API Key: مقدار API_KEY
Certificate: کل PEM شامل BEGIN/END CERTIFICATE
```

پورت پنل، پورت داخلی `62050` نیست؛ باید **public port پروکسی دادهٔ Railway** را وارد کنی.

## 4. نکتهٔ Engine و محدودیت پلتفرم

این wrapper فقط Node رسمی PasarGuard را اجرا می‌کند و Engine پنل را داخل Runsite نصب نمی‌کند. Rathole نیز از binary آمادهٔ رسمی استفاده می‌کند و دیگر در هر Deploy با Rust build نمی‌شود؛ این تغییر برای جلوگیری از build سنگین و Block شدن Deploy انجام شده است.

اگر API نود بالا آمد اما WireGuard یا data-plane کار نکرد، مشکل از محدودیت kernel/capability سرویس‌های managed است، نه از health endpoint. برای قابلیت‌هایی که نیاز به `NET_ADMIN` یا interface واقعی دارند، VPS یا ماشین اختصاصی مطمئن‌تر است.
