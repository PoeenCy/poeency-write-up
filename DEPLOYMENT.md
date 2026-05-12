# Portfolio Deployment Guide

## Deployment Methods

### 1. GitHub Pages (Free)

#### Step 1: Create a GitHub Repository

```bash
# Create a new repo on GitHub named: username.github.io
# Or any name if you want to deploy to a subdirectory

git remote add origin https://github.com/username/poeency-portfolio.git
git push -u origin master
```

#### Step 2: Configure GitHub Actions

Create a file `.github/workflows/deploy.yml`:

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

#### Step 3: Enable GitHub Pages

1. Go to Settings → Pages
2. Source: GitHub Actions
3. Save

**URL**: `https://username.github.io/poeency-portfolio/`

---

### 2. Netlify (Free + Custom Domain)

#### Deploy from Git

1. Sign up at [netlify.com](https://netlify.com)
2. Click "Add new site" → "Import an existing project"
3. Select your GitHub repository
4. Build settings:
   - Build command: `hugo --minify`
   - Publish directory: `public`
   - Environment variables:
     - `HUGO_VERSION`: `0.161.1`

#### Deploy from CLI

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy --prod
```

**Features**:
- ✅ Auto HTTPS
- ✅ Free custom domain
- ✅ Global CDN
- ✅ Continuous deployment

---

### 3. Vercel (Free)

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel

# Production deploy
vercel --prod
```

Or import from GitHub at [vercel.com](https://vercel.com)

---

### 4. Cloudflare Pages (Free)

1. Sign up at [pages.cloudflare.com](https://pages.cloudflare.com)
2. Connect GitHub repository
3. Build settings:
   - Framework preset: Hugo
   - Build command: `hugo --minify`
   - Build output: `public`
   - Environment variable: `HUGO_VERSION = 0.161.1`

**Features**:
- ✅ Unlimited bandwidth
- ✅ Blazing fast (Cloudflare CDN)
- ✅ Free SSL

---

### 5. Self-hosted (VPS/Server)

#### Using Nginx

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

#### Using Docker

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

### DNS Configuration

Add DNS records:

```
Type    Name    Value
A       @       <IP-address>
CNAME   www     <deployment-url>
```

### Update baseURL

Edit `hugo.toml`:
```toml
baseURL = 'https://your-domain.com/'
```

---

## Optimization

### 1. Minify HTML/CSS/JS

Already enabled with the `--minify` flag.

### 2. Image Optimization

```bash
# Install imagemin
npm install -g imagemin-cli imagemin-webp

# Convert to WebP
imagemin static/images/*.{jpg,png} --plugin=webp --out-dir=static/images/
```

### 3. Enable Caching

Add to `hugo.toml`:
```toml
[caches]
[caches.getjson]
dir = ":cacheDir/:project"
maxAge = "1h"
```

### 4. Lazy Loading Images

In your markdown:
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

Add to `hugo.toml`:
```toml
[params]
googleAnalytics = "G-XXXXXXXXXX"
```

### Cloudflare Analytics

Free when using Cloudflare Pages/CDN.

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

### Theme not loading

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

Check that the `baseURL` in `hugo.toml` matches your actual domain.

---

## Recommended: Netlify

I recommend using **Netlify** because:
- ✅ Easiest setup
- ✅ Free SSL + Custom domain
- ✅ Auto deploy on push
- ✅ Preview deployments for PRs
- ✅ Form handling (if a contact form is needed)

---

Happy Deploying! 🚀
