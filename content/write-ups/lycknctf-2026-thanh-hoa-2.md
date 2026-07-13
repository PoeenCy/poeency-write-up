+++
title = 'Thanh Hoa 2 - Write-up'
date = '2026-07-14T02:23:00+07:00'
draft = false
tags = ['LYCKNCTF2026', 'mp4', 'png', 'lsb', 'zip-carving']
categories = ['Forensics']
+++

# CTF Write-up: Thanh Hoa 2

**Category:** Forensics
**Flag format:** `LYKNCTF{...}`
**Flag cuối:** `LYKNCTF{N3M_CHU4_TH4NH_H04_D4C_S4N_XU_TH4NH}`

---

## Mô tả bài

File được cung cấp là `lyknctf.mp4`. Vì đây là phần 2 của Thanh Hoa, mình giữ lại giả thuyết từ phần 1: có thể vẫn là MP4 nhiều lớp, password gắn với đặc sản hoặc meme Thanh Hóa.

**Tải về đề bài:** [challenge files - OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQAB25m9gvzURpxbNHB_8UmpAZU1WcS2K1K3KYNvZYavthA?e=klSz0e)

---

## Nhận file và kiểm tra nhanh

Mình bắt đầu bằng `file` và `ffprobe` để xem MP4 này khác gì bài Thanh Hoa 1:

```bash
$ file lyknctf.mp4
```

```
lyknctf.mp4: ISO Media, MP4 Base Media v1 [ISO 14496-12:2003]
```

```bash
$ ffprobe -hide_banner -i lyknctf.mp4
```

```
[mov,mp4,m4a,3gp,3g2,mj2 @ ...] stream 0, timescale not set
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'lyknctf.mp4':
  Duration: 00:06:26.94, start: 0.000000, bitrate: 595 kb/s
  Stream #0:0[0x1](und): Video: h264 (Main), yuv420p, 1280x720, 29.97 fps
  Stream #0:1[0x2](eng): Audio: aac (LC), 44100 Hz, stereo, fltp, 127 kb/s
  Stream #0:2[0x0]: Video: png, rgb24, 1280x720, 90k tbr, 90k tbn (attached pic)
```

Khác biệt lớn so với phần 1 là có `Stream #0:2` dạng PNG attached picture. Đây là hướng rất đáng chú ý vì PNG lossless phù hợp để giấu LSB.

---

## Phần 1: Trailer ZIP ở cuối MP4

Trước khi đi vào ảnh, mình kiểm tra metadata toàn file. `exiftool` báo cả cover art và trailer lạ:

```bash
$ exiftool lyknctf.mp4
```

```
Cover Art                       : (Binary data 262918 bytes, use -b option to extract)
Warning                         : Unknown trailer with truncated '\x14\x00\x01\x00' data at offset 0x1b7b70c
```

`Unknown trailer` cho thấy có dữ liệu nối thêm ở cuối. Chạy `binwalk`:

```bash
$ binwalk lyknctf.mp4
```

Các dòng quan trọng:

```
28554246      0x1B3B406       PNG image, 1280 x 720, 8-bit/color RGB, non-interlaced
28554287      0x1B3B42F       Zlib compressed data, default compression
28817164      0x1B7B70C       Zip archive data, encrypted at least v2.0 to extract, compressed size: 71, uncompressed size: 45, name: flag.txt
28817349      0x1B7B7C5       End of Zip archive, footer length: 22
```

Có hai thứ cần xử lý:

- PNG nhúng trong MP4.
- ZIP mã hóa ở offset `28817164`.

Mình cắt ZIP ra trước:

```bash
$ dd if=lyknctf.mp4 of=trailer.zip bs=1 skip=28817164 status=none
```

Kiểm tra bằng `7z`:

```bash
$ 7z l -slt trailer.zip
```

```
Path = trailer.zip
Type = zip
Physical Size = 207

----------
Path = flag.txt
Size = 45
Packed Size = 71
Encrypted = +
Method = AES-256 Deflate
```

Vậy bài vẫn có ZIP AES chứa `flag.txt`, nhưng cần password.

---

## Phần 2: Sai hướng audio và quay lại attached PNG

Do phần 1 dùng spectrogram audio, mình thử hướng audio trước. Nhưng lần này `ffprobe` đã chỉ ra một chi tiết mới rõ hơn: attached PNG. Nếu tác giả đã nhúng PNG lossless vào MP4, khả năng password nằm ở ảnh này cao hơn việc lặp lại y hệt trick audio của phần 1.

Mình trích ảnh attached ra:

```bash
$ ffmpeg -hide_banner -y -i lyknctf.mp4 -map 0:2 -frames:v 1 -update 1 attached.png
```

Output xác nhận stream PNG được ghi ra:

```
Stream #0:2 -> #0:0 (png (native) -> png (native))
Output #0, image2, to 'attached.png':
  Stream #0:0: Video: png, rgb24, 1280x720
frame=    1 ... video:446KiB
```

![Attached PNG được trích từ stream `#0:2` của MP4](/images/write-ups/lycknctf-2026-thanh-hoa-2/attached.png)

Nhìn bằng mắt thường, ảnh chỉ giống một frame/cover bị out-of-focus, không có chữ hay QR rõ ràng. Đây là điểm hợp lý với LSB steganography: phần nhìn thấy của ảnh vẫn bình thường, còn dữ liệu nằm ở bit thấp nhất của từng kênh màu.

Kiểm tra file:

```bash
$ file attached.png
```

```
attached.png: PNG image data, 1280 x 720, 8-bit/color RGB, non-interlaced
```

PNG RGB, không nén mất dữ liệu. Đây là định dạng rất tiện cho LSB.

---

## Phần 3: Quét LSB để lấy password

Nếu có `zsteg`, mình sẽ thử nó trước. Ở đây mình dùng Python để đọc bit thấp nhất của từng kênh RGB, gom lại thành byte rồi tìm chuỗi ASCII.

```python
import re
from PIL import Image

img = Image.open("attached.png").convert("RGB")

bits = []
for r, g, b in img.getdata():
    bits.extend((r & 1, g & 1, b & 1))

data = bytearray()
for i in range(0, len(bits) - 7, 8):
    value = 0
    for bit in bits[i:i + 8]:
        value = (value << 1) | bit
    data.append(value)

hits = re.findall(rb"NEMCHUATHANHHOA", bytes(data))
print("matches =", len(hits))
print(hits[0].decode() if hits else "no match")
```

Chạy script:

```bash
$ python3 lsb_scan.py
```

```
matches = 21600
NEMCHUATHANHHOA
```

![Preview ASCII đầu tiên decode từ RGB LSB stream](/images/write-ups/lycknctf-2026-thanh-hoa-2/lsb-password-preview.png)

Preview này không phải ảnh minh họa thủ công; nó được render từ chính byte stream sau khi gom các bit `R LSB -> G LSB -> B LSB`. Việc `NEMCHUATHANHHOA` lặp lại `21600` lần giúp mình tự tin rằng đây không phải nhiễu ngẫu nhiên. Chuỗi cũng khớp chủ đề Thanh Hóa: nem chua Thanh Hóa.

---

## Phần 4: Giải nén ZIP

Dùng chuỗi từ LSB làm password:

```bash
$ 7z x -y -pNEMCHUATHANHHOA trailer.zip -oextracted
```

```
Extracting archive: trailer.zip
--
Path = trailer.zip
Type = zip
Physical Size = 207

Everything is Ok

Size:       45
Compressed: 207
```

Đọc `flag.txt`:

```bash
$ cat extracted/flag.txt
```

```
LYKNCTF{N3M_CHU4_TH4NH_H04_D4C_S4N_XU_TH4NH}
```

---

## Ghép Flag

| Thành phần | Giá trị | Nguồn |
|---|---|---|
| ZIP ẩn | Offset `0x1B7B70C` | Trailer cuối MP4 |
| Password | `NEMCHUATHANHHOA` | LSB RGB của attached PNG |
| File flag | `flag.txt` | ZIP AES |

```
LYKNCTF{N3M_CHU4_TH4NH_H04_D4C_S4N_XU_TH4NH}
```

---

## Bài học rút ra

**1. Phần 2 không nhất thiết dùng lại trick phần 1.**
Thanh Hoa 1 dùng audio spectrogram, nhưng Thanh Hoa 2 chuyển sang attached PNG. Dựa quá mạnh vào pattern cũ sẽ mất thời gian.

**2. `ffprobe` giúp nhìn thấy stream ẩn trong container.**
`Stream #0:2: Video: png ... (attached pic)` là tín hiệu quan trọng nhất của bài.

**3. PNG lossless rất hợp với LSB.**
Khi ảnh PNG được nhúng trong MP4 và không có metadata rõ ràng, quét LSB RGB là bước nên làm sớm.
