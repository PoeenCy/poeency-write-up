# Trần Thanh Nhã - Portfolio & Write-ups

Portfolio cá nhân và blog về An toàn thông tin, được xây dựng bằng Hugo với theme PaperMod.

## 🚀 Giới thiệu

Website này bao gồm:
- **Portfolio**: Các dự án và thành tựu trong lĩnh vực cybersecurity
- **Write-ups**: Bài viết về CTF, network analysis, AI/ML in security
- **Research**: Ghi chú nghiên cứu về IoT Security và các chủ đề liên quan

## 🛠️ Công nghệ sử dụng

- **Hugo**: Static site generator
- **PaperMod**: Hugo theme
- **Git**: Version control

## 📦 Cài đặt

### Yêu cầu
- Hugo Extended (v0.161.1 hoặc mới hơn)
- Git

### Clone repository

```bash
git clone <repository-url>
cd poeency-portfolio
git submodule update --init --recursive
```

## 🏃 Chạy local

```bash
hugo server -D
```

Website sẽ chạy tại: `http://localhost:1313`

## 📝 Tạo nội dung mới

### Tạo bài viết mới

```bash
hugo new posts/ten-bai-viet.md
```

### Tạo trang portfolio mới

```bash
hugo new portfolio/ten-du-an.md
```

## 🔨 Build production

```bash
hugo --minify
```

File build sẽ được tạo trong thư mục `public/`

## 📂 Cấu trúc thư mục

```
poeency-portfolio/
├── content/
│   ├── about.md          # Trang giới thiệu
│   ├── portfolio/        # Các dự án
│   └── posts/            # Bài viết blog
├── themes/
│   └── PaperMod/         # Theme
├── static/               # Static files (images, css, js)
├── hugo.toml             # File cấu hình
└── README.md
```

## 🎨 Tùy chỉnh

Chỉnh sửa file `hugo.toml` để thay đổi:
- Thông tin cá nhân
- Menu navigation
- Social links
- Theme settings

## 📧 Liên hệ

- **Email**: nhatran.network@gmail.com
- **GitHub**: [github.com/tranthanhnh](https://github.com/tranthanhnh)

## 📄 License

© 2026 Trần Thanh Nhã. All rights reserved.
