#!/bin/bash

# Script để tạo bài viết mới nhanh chóng

echo "=== Tạo bài viết mới ==="
echo ""

# Nhập tiêu đề
read -p "Nhập tiêu đề bài viết: " title

# Chuyển đổi tiêu đề thành slug (lowercase, replace spaces with hyphens)
slug=$(echo "$title" | iconv -t ascii//TRANSLIT | sed -r 's/[^a-zA-Z0-9]+/-/g' | sed -r 's/^-+\|-+$//g' | tr A-Z a-z)

# Nhập tags
read -p "Nhập tags (cách nhau bởi dấu phẩy): " tags_input

# Nhập category
read -p "Nhập category: " category

# Tạo file
filename="content/posts/${slug}.md"

# Tạo nội dung front matter
cat > "$filename" << EOF
+++
title = '${title}'
date = '$(date +"%Y-%m-%dT%H:%M:%S+07:00")'
draft = false
tags = [$(echo "$tags_input" | sed "s/,/', '/g" | sed "s/^/'/;s/$/'/")]
categories = ['${category}']
+++

## Giới thiệu

Viết nội dung của bạn ở đây...

## Kết luận

---

**Tags:** #$(echo "$tags_input" | sed 's/,/ #/g')

📧 Questions? Contact: nhatran.network@gmail.com
EOF

echo ""
echo "✅ Đã tạo bài viết: $filename"
echo ""
echo "Mở file để chỉnh sửa:"
echo "  code $filename"
echo ""
echo "Xem preview:"
echo "  hugo server -D"
