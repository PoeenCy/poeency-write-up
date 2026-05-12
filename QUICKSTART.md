# Quick Start Guide

Hướng dẫn nhanh để bắt đầu với portfolio Hugo của bạn.

## 🚀 Bắt đầu trong 5 phút

### 1. Clone và Setup

```bash
# Clone repository
git clone <your-repo-url>
cd poeency-portfolio

# Update theme submodule
git submodule update --init --recursive
```

### 2. Chạy Development Server

```bash
hugo server -D
```

Mở trình duyệt tại: **http://localhost:1313**

## 📝 Tạo nội dung mới

### Tạo bài viết

**Linux/Mac:**
```bash
chmod +x scripts/new-post.sh
./scripts/new-post.sh
```

**Windows:**
```powershell
.\scripts\new-post.ps1
```

**Hoặc dùng Hugo CLI:**
```bash
hugo new posts/ten-bai-viet.md
```

### Tạo trang Portfolio

```bash
hugo new portfolio/ten-du-an.md
```

## ✏️ Chỉnh sửa nội dung

### Cấu hình chính

File: `hugo.toml`

```toml
baseURL = 'https://your-domain.com/'  # Đổi domain của bạn
title = 'Your Name | Portfolio'        # Đổi tên của bạn
```

### Thông tin cá nhân

1. **About page**: `content/about.md`
2. **Portfolio**: `content/portfolio/_index.md`
3. **Home page**: `content/_index.md`

### Social Links

Trong `hugo.toml`:

```toml
[[params.socialIcons]]
name = "github"
url = "https://github.com/your-username"

[[params.socialIcons]]
name = "linkedin"
url = "https://linkedin.com/in/your-profile"

[[params.socialIcons]]
name = "email"
url = "mailto:your-email@example.com"
```

## 🎨 Tùy chỉnh giao diện

### Thay đổi màu sắc

Tạo file: `assets/css/extended/custom.css`

```css
:root {
    --primary: #007bff;
    --secondary: #6c757d;
}
```

### Thêm logo/avatar

1. Thêm ảnh vào `static/images/`
2. Cập nhật `hugo.toml`:

```toml
[params.profileMode]
imageUrl = "/images/avatar.jpg"
```

## 🔨 Build Production

```bash
hugo --minify
```

Files sẽ được tạo trong thư mục `public/`

## 🚀 Deploy

### Option 1: GitHub Pages (Recommended)

1. Push code lên GitHub
2. Enable GitHub Pages trong Settings
3. GitHub Actions sẽ tự động deploy

### Option 2: Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod
```

### Option 3: Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

Chi tiết xem: [DEPLOYMENT.md](DEPLOYMENT.md)

## 📁 Cấu trúc thư mục

```
poeency-portfolio/
├── content/              # Nội dung website
│   ├── posts/           # Blog posts
│   ├── portfolio/       # Portfolio items
│   ├── about.md         # Trang About
│   └── _index.md        # Homepage
├── static/              # Static files (images, files)
├── themes/              # Hugo themes
│   └── PaperMod/       # PaperMod theme
├── scripts/             # Utility scripts
├── hugo.toml            # Cấu hình chính
└── README.md
```

## 🎯 Workflow thông thường

### 1. Viết bài mới

```bash
# Tạo bài viết
hugo new posts/my-new-post.md

# Chỉnh sửa
code content/posts/my-new-post.md

# Preview
hugo server -D
```

### 2. Publish

```bash
# Đổi draft = false trong front matter
# Hoặc xóa dòng draft

# Commit
git add .
git commit -m "Add: New blog post"
git push
```

### 3. Auto Deploy

GitHub Actions sẽ tự động build và deploy!

## 🛠️ Các lệnh hữu ích

```bash
# Chạy server với drafts
hugo server -D

# Build production
hugo --minify

# Clean cache
hugo --gc

# Check version
hugo version

# List all content
hugo list all

# Create new content
hugo new posts/my-post.md
```

## 🐛 Troubleshooting

### Theme không hiển thị

```bash
git submodule update --init --recursive
```

### Port 1313 đã được sử dụng

```bash
hugo server -D -p 1314
```

### Build errors

```bash
# Clean và rebuild
rm -rf public/ resources/
hugo --gc
hugo --minify
```

## 📚 Tài liệu

- [Hugo Documentation](https://gohugo.io/documentation/)
- [PaperMod Theme](https://github.com/adityatelange/hugo-PaperMod)
- [Markdown Guide](https://www.markdownguide.org/)

## 💡 Tips

1. **Viết thường xuyên**: Consistency is key
2. **SEO**: Thêm description và tags cho mỗi bài
3. **Images**: Optimize images trước khi upload
4. **Backup**: Commit code thường xuyên
5. **Analytics**: Thêm Google Analytics để track visitors

## 🆘 Cần giúp đỡ?

- 📧 Email: nhatran.network@gmail.com
- 📖 Đọc [CONTRIBUTING.md](CONTRIBUTING.md)
- 🐛 Tạo issue trên GitHub

---

Happy blogging! 🎉
