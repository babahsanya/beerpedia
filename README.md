# Beerpedia - Private Beer Encyclopedia

Flask + SQLite + Docker deployment with auto-parsing, Basic Auth and Nginx reverse proxy.

## Quick Start (VPS)

```bash
# 1. Clone
 git clone https://github.com/babahsanya/beerpedia.git
 cd beerpedia

# 2. Configure
 cp .env.example .env
 nano .env   # set SECRET_KEY (random hex)

# 3. Change default password
 python -c "from passlib.apache import HtpasswdFile; ht = HtpasswdFile('.htpasswd', new=True); ht.set_password('beerpedia', 'YOUR_NEW_PASSWORD'); ht.save()"

# 4. Load data (download release or copy local DB)
 # Option A: from GitHub Release (data-v1)
 wget -O /tmp/data.zip https://github.com/babahsanya/beerpedia/releases/download/data-v1/beerpedia_data.zip
 unzip /tmp/data.zip -d /tmp/beerpedia_data

 # Option B: copy local files
 # scp beer_database.db user@vps:/path/to/beerpedia/
 # scp -r static/images user@vps:/path/to/beerpedia/static/

 docker compose up -d       # creates volumes
 docker compose down         # stop

 # Copy DB into volume
 docker run --rm    -v $(pwd)/beer_database.db:/source    -v beerpedia_beer_data:/dest    alpine cp /source /dest/beer_database.db

 # Copy images into volume
 docker run --rm    -v /tmp/beerpedia_data/static/images:/source    -v beerpedia_beer_static_images:/dest    alpine sh -c "cp -r /source/* /dest/ 2>/dev/null || true"

 # Copy brewery logos
 docker run --rm    -v /tmp/beerpedia_data/static/breweries:/source    -v beerpedia_beer_static_breweries:/dest    alpine sh -c "cp -r /source/* /dest/ 2>/dev/null || true"

# 5. Start
 docker compose up -d

# 6. Verify
 docker compose logs -f app
 curl -u beerpedia:YOUR_NEW_PASSWORD http://localhost
```

## Architecture

```
VPS
 +-- beerpedia/                  # code (git)
 |   +-- Dockerfile              # python:3.12-slim + gunicorn
 |   +-- docker-compose.yml      # 3 services: app, nginx, cron
 |   +-- nginx.conf              # reverse proxy + Basic Auth
 |   +-- .htpasswd               # login:password
 |   +-- entrypoint.sh           # DB check + gunicorn start
 |   +-- backup.sh               # daily SQLite backup + rotation
 |   +-- app.py                  # Flask app (catalog, search, etc.)
 |   +-- run_full_pipeline.py    # parser + images + styles
 |   +-- craftbeer_global_parser.py  # data parser
 |   +-- image_cache.py          # image downloader
 |   +-- templates/              # Jinja2 HTML
 |   +-- static/                 # CSS, JS
 +-- Docker volumes (persistent):
 |   +-- beer_data/              # beer_database.db (~45 MB)
 |   +-- beer_static_images/     # beer photos (~450 MB)
 |   +-- beer_static_breweries/  # brewery logos (~3 MB)
 +-- Containers:
     +-- beer_app     # Flask + Gunicorn (port 8000, internal)
     +-- beer_nginx   # Nginx reverse proxy (port 80/443)
     +-- beer_cron   # Scheduled tasks (backup + parsing)
```

## Security

- **Basic Auth** - Nginx requires login/password for all requests
- **Security headers** - X-Frame-Options, X-Content-Type-Options, Referrer-Policy
- **Rate limiting** - 10 req/s on API endpoints
- **Read-only methods** - Only GET/HEAD allowed
- **Server tokens hidden** - nginx version not exposed
- **Unprivileged user** - app runs as user `beer` (UID 1000)
- **No debug mode** - FLASK_DEBUG=0 in production

### Default credentials

Login: `beerpedia` / Password: `changeme123` - **change before deploying!**

```bash
# Generate new .htpasswd
python -c "from passlib.apache import HtpasswdFile; ht = HtpasswdFile('.htpasswd', new=True); ht.set_password('beerpedia', 'NEW_PASSWORD'); ht.save()"

# Or install apache2-utils and use htpasswd
apt install apache2-utils
htpasswd -cb .htpasswd beerpedia NEW_PASSWORD

# Restart nginx to apply
docker compose restart nginx
```

## Auto-Updates

Data updates automatically without manual intervention:

| Schedule | Task | Description |
|----------|------|-------------|
| Daily 03:00 | `backup.sh` | SQLite backup (7-day rotation) |
| Sunday 04:00 | `run_full_pipeline.py --refresh` | Full parse + images + styles |

Cron runs in a separate container with the same Python image as the app.

### Manual update

```bash
docker compose exec app python run_full_pipeline.py
docker compose exec app python run_full_pipeline.py --failed-only  # retry errors
```

## HTTPS (Let's Encrypt)

Optional but recommended. Requires a domain pointing to your VPS IP.

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate (replace beer.example.com with your domain)
sudo certbot --nginx -d beer.example.com

# Verify auto-renewal
sudo certbot renew --dry-run
```

After HTTPS is set up, uncomment in `docker-compose.yml`:
```yaml
ports:
  - "80:80"
  - "443:443"   # <-- uncomment this
```

And in `nginx.conf` uncomment HSTS:
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

Then restart: `docker compose up -d`

## Useful Commands

```bash
# Logs
docker compose logs -f app       # Flask/Gunicorn
docker compose logs -f nginx     # Nginx
docker compose logs -f cron      # Cron (backup + parse)

# Update code + rebuild
git pull && docker compose up -d --build

# Stop
docker compose down

# Full reset (DELETES all data!)
docker compose down -v

# Manual backup
docker exec beer_app /app/backup.sh

# Check health
docker compose ps
```

## Routes

| URL | Description |
|-----|-------------|
| `/` | Home: stats, top styles/breweries, random beers |
| `/search?q=` | Search by name/brewery/style/country |
| `/beer/<id>` | Beer card: photo, specs, BJCP info, similar |
| `/styles` | All beer styles |
| `/style/<slug>` | Style page: BJCP + stats |
| `/breweries` | All breweries |
| `/brewery/<slug>` | Brewery page: style distribution + products |
| `/country/<name>` | Country page |
| `/catalog` | Catalog with filters (style/country/ABV/price) |
| `/top` | Collections: strong, light, new, available |
| `/compare?id1=&id2=` | Side-by-side comparison |
| `/random` | Random beer card |

## Local Development

```bash
pip install -r requirements.txt
python app.py  # http://127.0.0.1:8000
```

## Database

- **products_full** (7733 rows, 40+ columns): name, style, ABV, IBU, description, ingredients, price, ratings, etc.
- **beer_styles** - BJCP style reference (31 style)
- **parse_progress** - parser checkpoint for resume

## Tech Stack

- **Backend**: Flask + Gunicorn
- **Database**: SQLite
- **Frontend**: Jinja2 templates + vanilla CSS/JS
- **Reverse Proxy**: Nginx (security headers, rate limiting, static files)
- **Deployment**: Docker Compose (3 containers)
- **Search**: fuzzy matching with typo correction, keyboard layout detection

Styles: BJCP 2021
