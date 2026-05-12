# Hướng dẫn đổi tên thư mục dự án

## Tình trạng hiện tại

Tất cả nội dung trong dự án đã được cập nhật từ "Pâu" sang "Poeency", nhưng thư mục vẫn còn tên `pau-portfolio`.

## Cách đổi tên thư mục

### Windows (PowerShell)

**Bước 1**: Đóng tất cả các chương trình đang sử dụng thư mục này:
- Đóng VS Code / Editor
- Đóng Terminal/PowerShell đang ở trong thư mục
- Đóng File Explorer nếu đang mở thư mục này

**Bước 2**: Mở PowerShell mới ở thư mục cha (`D:\write-ups\`)

```powershell
cd D:\write-ups\
Rename-Item -Path "pau-portfolio" -NewName "poeency-portfolio"
```

**Bước 3**: Vào thư mục mới

```powershell
cd poeency-portfolio
```

### Linux/Mac

```bash
cd /path/to/parent/directory
mv pau-portfolio poeency-portfolio
cd poeency-portfolio
```

## Sau khi đổi tên

### Kiểm tra Git

```bash
git status
```

Git sẽ vẫn hoạt động bình thường vì repository được lưu trong `.git/` folder.

### Cập nhật remote URL (nếu cần)

Nếu bạn đã push lên GitHub với tên cũ, bạn có thể:

**Option 1**: Đổi tên repository trên GitHub
1. Vào Settings của repository
2. Đổi tên repository thành `poeency-portfolio`
3. Cập nhật remote URL:

```bash
git remote set-url origin https://github.com/username/poeency-portfolio.git
```

**Option 2**: Giữ nguyên tên repository trên GitHub
- Không cần làm gì, tên thư mục local không ảnh hưởng đến remote

### Cập nhật baseURL trong hugo.toml

Nếu bạn deploy với custom domain:

```toml
baseURL = 'https://poeency-portfolio.com/'
```

Hoặc với GitHub Pages:

```toml
baseURL = 'https://username.github.io/poeency-portfolio/'
```

## Xác nhận thay đổi

```bash
# Kiểm tra Hugo vẫn hoạt động
hugo server -D

# Build test
hugo --minify
```

## Troubleshooting

### Lỗi "The process cannot access the file"

**Nguyên nhân**: Có chương trình đang sử dụng thư mục

**Giải pháp**:
1. Đóng tất cả editors (VS Code, Notepad++, etc.)
2. Đóng tất cả terminals đang ở trong thư mục
3. Đóng File Explorer
4. Restart máy nếu cần
5. Thử lại

### Lỗi Git sau khi đổi tên

Không nên xảy ra, nhưng nếu có:

```bash
# Kiểm tra Git config
git config --list

# Kiểm tra remote
git remote -v

# Nếu cần, set lại remote
git remote set-url origin <your-repo-url>
```

## Tóm tắt các thay đổi đã thực hiện

✅ **Đã cập nhật**:
- `hugo.toml`: author và title
- `content/about.md`: Giới thiệu
- `content/_index.md`: Homepage
- `README.md`: Tên thư mục trong hướng dẫn
- `QUICKSTART.md`: Tên thư mục trong examples
- `DEPLOYMENT.md`: Tên thư mục và URLs
- `PROJECT_SUMMARY.md`: Tên dự án

⏳ **Cần làm thủ công**:
- Đổi tên thư mục từ `pau-portfolio` → `poeency-portfolio`
- Cập nhật baseURL nếu deploy với custom domain

---

**Lưu ý**: Sau khi đổi tên thư mục, file này sẽ nằm ở `poeency-portfolio/RENAME_FOLDER.md`
