# Hướng dẫn Deploy Portfolio

## Các phương pháp deploy

### 1. GitHub Pages (Miễn phí)

#### Bước 1: Tạo GitHub Repository

```bash
# Tạo repo mới trên GitHub với tên: username.github.io
# Hoặc tên bất kỳ nếu muốn deploy ở subdomain

git remote add origin https://github.com/username/poeency-portfolio.git
git push -u origin master
```

#### Bước 2: Cấu hình GitHub Actions

Tạo file `.github/workflows/deploy.yml`:

```yaml
name: Deploy Hugo site to GitHub Pages

on:
  push:
    branches:
      - master

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
          fetch-depth: 0

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: 'latest'
          extended: true

      - name: Build
        run: hugo --minify

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: ./public

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v2
```

#### Bước 3: Enable GitHub Pages

1. Vào Settings → Pages
2. Source: GitHub Actions
3. Save

**URL**: `https://username.github.io/poeency-portfolio/`

---

### 2. Netlify (Miễn phí + Custom Domain)

#### Deploy từ Git

1. Đăng ký tài khoản tại [netlify.com](https://netlify.com)
2. Click "Add new site" → "Import an existing project"
3. Chọn GitHub repository
4. Build settings:
   - Build command: `hugo --minify`
   - Publish directory: `public`
   - Environment variables:
     - `HUGO_VERSION`: `0.161.1`

#### Deploy từ CLI

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy --prod
```

**Features**:
- ✅ HTTPS tự động
- ✅ Custom domain miễn phí
- ✅ CDN toàn cầu
- ✅ Continuous deployment

---

### 3. Vercel (Miễn phí)

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel

# Production deploy
vercel --prod
```

Hoặc import từ GitHub tại [vercel.com](https://vercel.com)

---

### 4. Cloudflare Pages (Miễn phí)

1. Đăng ký tại [pages.cloudflare.com](https://pages.cloudflare.com)
2. Connect GitHub repository
3. Build settings:
   - Framework preset: Hugo
   - Build command: `hugo --minify`
   - Build output: `public`
   - Environment variable: `HUGO_VERSION = 0.161.1`

**Features**:
- ✅ Unlimited bandwidth
- ✅ Cực nhanh (Cloudflare CDN)
- ✅ Free SSL

---

### 5. Self-hosted (VPS/Server)

#### Sử dụng Nginx

```bash
# Build static files
hugo --minify

# Copy to web server
scp -r public/* user@server:/var/www/poeency-portfolio/

# Nginx config
server {
    listen 80;
    server_name poeency-portfolio.com;
    
    root /var/www/poeency-portfolio;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/poeency-portfolio /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### Sử dụng Docker

```dockerfile
# Dockerfile
FROM klakegg/hugo:0.161.1-ext-alpine AS builder

WORKDIR /src
COPY . .
RUN hugo --minify

FROM nginx:alpine
COPY --from=builder /src/public /usr/share/nginx/html
EXPOSE 80
```

```bash
# Build and run
docker build -t poeency-portfolio .
docker run -d -p 80:80 poeency-portfolio
```

---

## Custom Domain

### Cấu hình DNS

Thêm DNS records:

```
Type    Name    Value
A       @       <IP-address>
CNAME   www     <deployment-url>
```

### Update baseURL

Sửa `hugo.toml`:
```toml
baseURL = 'https://your-domain.com/'
```

---

## Tối ưu hóa

### 1. Minify HTML/CSS/JS

Đã được bật với flag `--minify`

### 2. Image Optimization

```bash
# Install imagemin
npm install -g imagemin-cli imagemin-webp

# Convert to WebP
imagemin static/images/*.{jpg,png} --plugin=webp --out-dir=static/images/
```

### 3. Enable Caching

Thêm vào `hugo.toml`:
```toml
[caches]
[caches.getjson]
dir = ":cacheDir/:project"
maxAge = "1h"
```

### 4. Lazy Loading Images

Trong markdown:
```html
<img src="image.jpg" loading="lazy" alt="Description">
```

---

## CI/CD Pipeline

### GitLab CI

`.gitlab-ci.yml`:
```yaml
image: klakegg/hugo:0.161.1-ext-alpine

pages:
  script:
    - hugo --minify
  artifacts:
    paths:
      - public
  only:
    - master
```

---

## Monitoring & Analytics

### Google Analytics

Thêm vào `hugo.toml`:
```toml
[params]
googleAnalytics = "G-XXXXXXXXXX"
```

### Cloudflare Analytics

Miễn phí khi dùng Cloudflare Pages/CDN

---

## Backup

```bash
# Backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
tar -czf pau-portfolio-backup-$DATE.tar.gz \
    content/ static/ themes/ hugo.toml

# Upload to cloud storage
# aws s3 cp pau-portfolio-backup-$DATE.tar.gz s3://backups/
```

---

## Troubleshooting

### Theme không load

```bash
git submodule update --init --recursive
```

### Build failed

```bash
# Check Hugo version
hugo version

# Clean cache
hugo --gc
rm -rf public/ resources/
```

### 404 errors

Kiểm tra `baseURL` trong `hugo.toml` phải khớp với domain

---

## Recommended: Netlify

Tôi khuyên dùng **Netlify** vì:
- ✅ Setup đơn giản nhất
- ✅ Free SSL + Custom domain
- ✅ Auto deploy khi push code
- ✅ Preview deployments cho PRs
- ✅ Form handling (nếu cần contact form)

---

Chúc bạn deploy thành công! 🚀
