# Hướng dẫn Enable GitHub Pages

## ✅ Đã hoàn thành

- ✅ Code đã được push lên GitHub
- ✅ GitHub Actions workflow đã có sẵn (`.github/workflows/deploy.yml`)
- ✅ BaseURL đã được cập nhật cho GitHub Pages

## 🚀 Bước tiếp theo - Enable GitHub Pages

### Bước 1: Vào Settings

1. Truy cập: https://github.com/PoeenCy/poeency-write-up
2. Click vào tab **Settings** (ở menu trên cùng)

### Bước 2: Enable GitHub Pages

1. Trong menu bên trái, click **Pages**
2. Trong phần **Source**, chọn:
   - Source: **GitHub Actions** (không phải Deploy from a branch)
3. Click **Save** (nếu có)

### Bước 3: Chờ deployment

1. Vào tab **Actions**: https://github.com/PoeenCy/poeency-write-up/actions
2. Bạn sẽ thấy workflow "Deploy Hugo site to GitHub Pages" đang chạy
3. Chờ khoảng 1-2 phút để build hoàn thành
4. Khi thấy dấu ✅ màu xanh là đã thành công

### Bước 4: Truy cập website

Website của bạn sẽ có tại:

🌐 **https://poeency.github.io/poeency-write-up/**

## 📸 Screenshots hướng dẫn

### Settings → Pages

```
┌─────────────────────────────────────────┐
│ GitHub Pages                            │
├─────────────────────────────────────────┤
│ Source                                  │
│ ┌─────────────────────────────────────┐ │
│ │ ● Deploy from a branch              │ │
│ │ ○ GitHub Actions          ← Chọn   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ [Save]                                  │
└─────────────────────────────────────────┘
```

## 🔄 Workflow tự động

Mỗi khi bạn push code mới lên GitHub:
1. GitHub Actions sẽ tự động chạy
2. Build website với Hugo
3. Deploy lên GitHub Pages
4. Website tự động cập nhật

## 🛠️ Troubleshooting

### Workflow không chạy

**Kiểm tra**:
1. Vào Settings → Actions → General
2. Đảm bảo "Allow all actions and reusable workflows" được chọn
3. Trong "Workflow permissions", chọn "Read and write permissions"

### Build failed

**Xem logs**:
1. Vào tab Actions
2. Click vào workflow run bị lỗi
3. Xem chi tiết lỗi
4. Thường là do:
   - Theme submodule chưa được clone
   - Hugo version không đúng
   - Syntax error trong content

**Fix**:
```bash
# Đảm bảo submodule được commit
git submodule update --init --recursive
git add .gitmodules themes/
git commit -m "Fix: Update theme submodule"
git push
```

### 404 Not Found

**Nguyên nhân**: baseURL không đúng

**Fix**: Đã được cập nhật trong `hugo.toml`:
```toml
baseURL = 'https://poeency.github.io/poeency-write-up/'
```

## 📝 Custom Domain (Optional)

Nếu bạn có domain riêng (ví dụ: `poeency.com`):

### Bước 1: Thêm CNAME record

Trong DNS provider của bạn:
```
Type: CNAME
Name: www (hoặc @)
Value: poeency.github.io
```

### Bước 2: Cấu hình GitHub

1. Vào Settings → Pages
2. Trong "Custom domain", nhập: `www.poeency.com`
3. Click Save
4. Chờ DNS propagation (5-10 phút)
5. Enable "Enforce HTTPS"

### Bước 3: Cập nhật baseURL

```toml
baseURL = 'https://www.poeency.com/'
```

## 🎉 Kết quả

Sau khi hoàn thành, bạn sẽ có:
- ✅ Website live tại GitHub Pages
- ✅ Auto deployment khi push code
- ✅ HTTPS miễn phí
- ✅ CDN toàn cầu (nhanh)

## 📊 Monitoring

### Xem deployment history
https://github.com/PoeenCy/poeency-write-up/deployments

### Xem Actions runs
https://github.com/PoeenCy/poeency-write-up/actions

## 🔗 Links hữu ích

- **Repository**: https://github.com/PoeenCy/poeency-write-up
- **Website**: https://poeency.github.io/poeency-write-up/
- **Actions**: https://github.com/PoeenCy/poeency-write-up/actions
- **Settings**: https://github.com/PoeenCy/poeency-write-up/settings/pages

---

**Lưu ý**: Lần đầu tiên enable GitHub Pages có thể mất 5-10 phút để website xuất hiện. Hãy kiên nhẫn! 🚀
