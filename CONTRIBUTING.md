# Hướng dẫn đóng góp

Cảm ơn bạn quan tâm đến việc đóng góp cho portfolio này!

## Cách đóng góp

### 1. Báo lỗi (Bug Reports)

Nếu bạn tìm thấy lỗi, vui lòng tạo issue với thông tin:
- Mô tả lỗi
- Các bước để tái hiện
- Kết quả mong đợi vs kết quả thực tế
- Screenshots (nếu có)
- Môi trường (browser, OS, etc.)

### 2. Đề xuất tính năng (Feature Requests)

Tạo issue với:
- Mô tả tính năng
- Lý do cần tính năng này
- Ví dụ sử dụng

### 3. Pull Requests

#### Quy trình

1. Fork repository
2. Tạo branch mới:
   ```bash
   git checkout -b feature/ten-tinh-nang
   ```
3. Thực hiện thay đổi
4. Test kỹ:
   ```bash
   hugo server -D
   ```
5. Commit với message rõ ràng:
   ```bash
   git commit -m "Add: Tính năng XYZ"
   ```
6. Push và tạo Pull Request

#### Commit Message Convention

```
Type: Short description

Longer description if needed

Types:
- Add: Thêm tính năng mới
- Fix: Sửa lỗi
- Update: Cập nhật nội dung
- Refactor: Tái cấu trúc code
- Style: Thay đổi styling
- Docs: Cập nhật documentation
```

### 4. Viết bài (Content Contribution)

#### Tạo bài viết mới

```bash
# Linux/Mac
./scripts/new-post.sh

# Windows
.\scripts\new-post.ps1
```

#### Cấu trúc bài viết

```markdown
+++
title = 'Tiêu đề'
date = '2026-05-12T10:00:00+07:00'
draft = false
tags = ['tag1', 'tag2']
categories = ['Category']
+++

## Giới thiệu

Nội dung...

## Phần chính

### Subsection

Code example:
```python
print("Hello World")
```

## Kết luận

---

**Tags:** #tag1 #tag2

📧 Contact: nhatran.network@gmail.com
```

#### Guidelines cho nội dung

- ✅ Viết rõ ràng, dễ hiểu
- ✅ Có ví dụ code thực tế
- ✅ Thêm screenshots khi cần
- ✅ Cite sources
- ✅ Kiểm tra chính tả
- ❌ Không copy-paste toàn bộ từ nguồn khác
- ❌ Không có nội dung vi phạm bản quyền

### 5. Cải thiện Theme/Styling

Nếu muốn thay đổi giao diện:
1. Tạo custom CSS trong `assets/css/extended/`
2. Override layouts trong `layouts/`
3. Test trên nhiều devices
4. Đảm bảo responsive

## Code Style

### Markdown

- Sử dụng heading hierarchy đúng (h2 → h3 → h4)
- Code blocks phải có language identifier
- Links phải có text mô tả rõ ràng

### TOML (hugo.toml)

- Indent với 2 spaces
- Group related settings
- Comment cho các settings phức tạp

## Testing

Trước khi submit PR:

```bash
# 1. Build test
hugo --minify

# 2. Check for errors
hugo --logLevel info

# 3. Test locally
hugo server -D

# 4. Validate links (optional)
npm install -g broken-link-checker
blc http://localhost:1313 -ro
```

## Review Process

1. Maintainer sẽ review PR trong vòng 2-3 ngày
2. Có thể có yêu cầu thay đổi
3. Sau khi approve, PR sẽ được merge
4. Changes sẽ tự động deploy

## Questions?

Nếu có câu hỏi, liên hệ:
- Email: nhatran.network@gmail.com
- Tạo issue trên GitHub

---

Cảm ơn bạn đã đóng góp! 🙏
