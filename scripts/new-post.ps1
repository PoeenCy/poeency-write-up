# PowerShell script để tạo bài viết mới (Windows)

Write-Host "=== Tạo bài viết mới ===" -ForegroundColor Cyan
Write-Host ""

# Nhập tiêu đề
$title = Read-Host "Nhập tiêu đề bài viết"

# Chuyển đổi tiêu đề thành slug
$slug = $title.ToLower() -replace '[^a-z0-9\s-]', '' -replace '\s+', '-' -replace '-+', '-'

# Nhập tags
$tagsInput = Read-Host "Nhập tags (cách nhau bởi dấu phẩy)"
$tags = ($tagsInput -split ',').Trim() | ForEach-Object { "'$_'" }
$tagsString = $tags -join ', '

# Nhập category
$category = Read-Host "Nhập category"

# Tạo filename
$filename = "content/posts/$slug.md"

# Lấy thời gian hiện tại
$date = Get-Date -Format "yyyy-MM-ddTHH:mm:ss+07:00"

# Tạo nội dung
$content = @"
+++
title = '$title'
date = '$date'
draft = false
tags = [$tagsString]
categories = ['$category']
+++

## Giới thiệu

Viết nội dung của bạn ở đây...

## Kết luận

---

**Tags:** #$($tagsInput -replace ',', ' #')

📧 Questions? Contact: nhatran.network@gmail.com
"@

# Ghi file
$content | Out-File -FilePath $filename -Encoding UTF8

Write-Host ""
Write-Host "✅ Đã tạo bài viết: $filename" -ForegroundColor Green
Write-Host ""
Write-Host "Mở file để chỉnh sửa:"
Write-Host "  code $filename" -ForegroundColor Yellow
Write-Host ""
Write-Host "Xem preview:"
Write-Host "  hugo server -D" -ForegroundColor Yellow
