+++
title = 'Remedy - Write-up'
date = '2026-07-14T02:20:00+07:00'
draft = false
tags = ['forensics', 'cryptography', 'LYCKNCTF2026', 'exiftool', 'xor', 'known-plaintext']
categories = ['CTF Write-ups', 'Forensics', 'Cryptography']
+++

# CTF Write-up: Remedy

**Category:** Forensics / Cryptography
**Flag format:** `LYKNCTF{...}`
**Flag cuối:** `LYKNCTF{Would_Be_Nice_If_Someone_Grow_Up_One_Day}`

---

## Mô tả bài

> Just a random pic?

File được cung cấp là `challeng.png`. Tên bài là `Remedy`, nhưng mô tả lại cố tình nói như đây chỉ là một bức ảnh bình thường.

**Tải về đề bài:** [challenge files - OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQD-lZ97bYtASK69Q8P0D3F5AX4uildaEsaULM05EomZGrQ?e=oGtPRB)

---

## Nhận file và kiểm tra nhanh

Với một file ảnh trong bài forensics, mình không vội mở bằng viewer trước. Mình kiểm tra kiểu file và metadata vì PNG có thể mang text chunk, EXIF chunk hoặc dữ liệu nén lạ:

```bash
$ file challeng.png
```

```
challeng.png: PNG image data, 968 x 768, 8-bit/color RGB, non-interlaced
```

File đúng là PNG hợp lệ. Bước tiếp theo là đọc metadata:

```bash
$ exiftool challeng.png
```

Những dòng đáng chú ý:

```
Warning                         : Improper "Exif00" header in EXIF chunk
Make                            : Iphone_12_Pro
Camera Model Name               : Normal_Camera
User Comment                    : Gnxvat Cubgbf Znlor Sha
Description                     : 6d14166842b6ecb67622284a65bde8a87e03344564bde3ab7e1e324b648dc4a87e0a2f4976bdffbd7e0233435ea6cbb45c
GPS Position                    : 10 deg 46' 36.84" N, 106 deg 42' 3.24" E
```

`User Comment` và `Description` là hai thứ nổi bật nhất. Một cái là text lạ, một cái là hex dài.

Mình vẫn chạy thêm `binwalk` để chắc không có archive rõ ràng bị append:

```bash
$ binwalk challeng.png
```

```
DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
0             0x0             PNG image, 968 x 768, 8-bit/color RGB, non-interlaced
47            0x2F            TIFF image data, big-endian, offset of first image directory: 8
1592          0x638           Zlib compressed data, best compression
```

Không có ZIP/RAR hoặc payload rõ ràng. Hướng chính nằm ở metadata.

---

## Phần 1: Giải chuỗi trong User Comment

Chuỗi `Gnxvat Cubgbf Znlor Sha` nhìn giống ROT13: chữ cái vẫn là chữ cái, khoảng trắng giữ nguyên, không có alphabet lạ. Mình giải thử:

```bash
$ python3 -c "import codecs; print(codecs.decode('Gnxvat Cubgbf Znlor Sha', 'rot_13'))"
```

```
Taking Photos Maybe Fun
```

Lúc đầu mình tưởng đây là password hoặc key. Nhưng thử nó theo hướng passphrase cho stego/AES/RC4 không đem lại gì rõ ràng. Quan trọng hơn: chuỗi trong `Description` là 49 byte ciphertext, không khớp block size AES và cũng không có IV/salt đi kèm. Vậy `Taking Photos Maybe Fun` nhiều khả năng là mồi nhử hoặc hint rất nhẹ rằng "đọc metadata ảnh là đúng hướng".

---

## Phần 2: Tấn công known-plaintext lên XOR lặp

`Description` là hex:

```
6d14166842b6ecb67622284a65bde8a87e03344564bde3ab7e1e324b648dc4a87e0a2f4976bdffbd7e0233435ea6cbb45c
```

Độ dài sau khi decode là 49 byte. Đây không phải độ dài đẹp cho block cipher, nên mình thử giả thuyết stream cipher đơn giản hơn: XOR lặp.

Trong CTF, flag format chính là known plaintext. Mình biết plaintext bắt đầu bằng `LYKNCTF{`, nên có thể XOR 8 byte đầu của ciphertext với 8 byte này để lấy key:

```bash
$ python3 -c "c=bytes.fromhex('6d14166842b6ecb67622284a65bde8a87e03344564bde3ab7e1e324b648dc4a87e0a2f4976bdffbd7e0233435ea6cbb45c'); k=bytes([c[i]^b'LYKNCTF{'[i] for i in range(8)]); print(k.hex()); print(bytes(c[i]^k[i%len(k)] for i in range(len(c))).decode())"
```

```
214d5d2601e2aacd
LYKNCTF{Would_Be_Nice_If_Someone_Grow_Up_One_Day}
```

Key 8 byte là `21 4d 5d 26 01 e2 aa cd`. Khi lặp key này trên toàn bộ ciphertext thì plaintext ra sạch, không có byte lỗi. Giả thuyết XOR lặp là đúng.

---

## Ghép Flag

| Thành phần | Giá trị | Nguồn |
|---|---|---|
| Ciphertext | `6d1416...bb45c` | EXIF `Description` |
| Known plaintext | `LYKNCTF{` | Flag format |
| XOR key | `214d5d2601e2aacd` | `ciphertext[:8] ^ b"LYKNCTF{"` |

```
LYKNCTF{Would_Be_Nice_If_Someone_Grow_Up_One_Day}
```

---

## Bài học rút ra

**1. Metadata ảnh có thể là payload chính.**
Với PNG/JPEG trong forensics, `exiftool` nên chạy rất sớm. Ở bài này, cả ciphertext lẫn mồi nhử đều nằm trong metadata.

**2. ROT13 không nhất thiết là key.**
`Taking Photos Maybe Fun` nhìn như password nhưng không giải được gì. Khi một hướng chỉ tạo ra đoán mò, mình cần quay lại cấu trúc dữ liệu thật.

**3. Flag format là known plaintext rất mạnh.**
Với XOR lặp hoặc stream cipher yếu, chỉ cần biết prefix đủ dài là có thể khôi phục key và kiểm tra toàn bộ plaintext ngay.
