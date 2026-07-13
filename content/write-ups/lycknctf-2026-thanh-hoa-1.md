+++
title = 'Thanh Hoa 1 - Write-up'
date = '2026-07-14T02:22:00+07:00'
draft = false
tags = ['forensics', 'LYCKNCTF2026', 'mp4', 'audio', 'spectrogram', 'zip-carving']
categories = ['CTF Write-ups', 'Forensics']
+++

# CTF Write-up: Thanh Hoa 1

**Category:** Forensics
**Flag format:** `LYKNCTF{...}`
**Flag cuối:** `LYKNCTF{NGU01_TH4NH_H04_4N_R4U_M4_PH4_DU0NG_T4U}`

---

## Mô tả bài

> Hint: `36 Thanh Hoa`

File được cung cấp là `lyknctf.mp4`.

**Tải về đề bài:** [challenge files - OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQCSmuUJ-bIvTrcXl1g5IGRVAUffVZPDrS-gk5Dyhx3g-i0?e=S3H02a)

---

## Nhận file và kiểm tra nhanh

Tên bài và hint đều nhắc Thanh Hóa. `36` là biển số Thanh Hóa, nhưng mình chưa biết nó dùng để chỉ flag, password hay một lớp stego nào đó. Vì artifact là video, mình bắt đầu bằng việc kiểm tra container và stream.

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
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'lyknctf.mp4':
  Duration: 00:06:26.94, start: 0.000000, bitrate: 659 kb/s
  Stream #0:0[0x1](und): Video: h264 (Main), yuv420p, 1280x720, 29.97 fps
  Stream #0:1[0x2](und): Audio: aac (LC), 44100 Hz, stereo, fltp, 197 kb/s
```

Video có một stream hình và một stream audio. Không có attached picture riêng như một số bài MP4 khác, nên nếu có dữ liệu ẩn thì khả năng cao nằm trong audio hoặc trailer cuối file.

---

## Phần 1: Âm thanh có một dải tần bất thường

Mình tách audio ra WAV để xem spectrogram. Lý do dùng WAV là để tránh phân tích trực tiếp trên AAC container:

```bash
$ ffmpeg -hide_banner -y -i lyknctf.mp4 -vn -ac 2 -ar 44100 lyknctf_audio.wav
```

Sau đó tạo spectrogram:

```bash
$ ffmpeg -hide_banner -y -i lyknctf_audio.wav \
  -lavfi showspectrumpic=s=1920x1080:legend=1:mode=combined:color=intensity \
  lyknctf_audio_spectrogram.png
```

![Spectrogram audio gốc của `lyknctf.mp4`](/images/write-ups/lycknctf-2026-thanh-hoa-1/lyknctf_audio_spectrogram.png)

Ở spectrogram gốc, phần âm thanh tự nhiên nằm dày ở dải thấp, nhưng có một dải tín hiệu đỏ rất đều nằm khoảng `6.5 kHz - 11.5 kHz`. Nó kéo dài gần như xuyên suốt timeline và có dạng nét thẳng/dọc lặp lại, khác hẳn nhiễu nền hoặc nhạc bình thường. Đây là dấu hiệu mạnh rằng dữ liệu đã được "vẽ" vào miền tần số.

Dải đó quá cao để đọc trực tiếp bằng mắt nếu nhìn toàn bộ spectrogram, nên mình lọc riêng nó ra:

```bash
$ ffmpeg -hide_banner -y -i lyknctf_audio.wav \
  -af highpass=f=6200,lowpass=f=11800,volume=6dB \
  lyknctf_audio_hidden_band.wav
```

Nghe trực tiếp thì tín hiệu quá cao và khó đọc. Mình hạ pitch xuống khoảng 5 lần để chữ nếu có sẽ rơi vào vùng dễ nhìn hơn trên spectrogram:

```bash
$ sox lyknctf_audio_hidden_band.wav lyknctf_sstv_down_5x.wav \
  pitch -2786 sinc 1000-2500 gain -n -3
```

`-2786` cents xấp xỉ `log2(1/5) * 1200`, tức hạ tần số về khoảng một phần năm. Sau bước này, dải `6.5 kHz - 11.5 kHz` rơi xuống khoảng `1.3 kHz - 2.3 kHz`, vừa đủ để nét chữ trên spectrogram dễ đọc hơn.

![Spectrogram sau khi lọc dải cao và hạ pitch 5 lần](/images/write-ups/lycknctf-2026-thanh-hoa-1/lyknctf_sstv_down_5x_spectrogram.png)

Nhìn toàn cảnh thì chữ vẫn bị kéo rất dài theo trục thời gian, nên mình crop một đoạn đầu để đọc rõ từng ký tự:

![Crop đoạn chữ ẩn trong spectrogram: `RAUMAPHATAU`](/images/write-ups/lycknctf-2026-thanh-hoa-1/lyknctf_down_5x_text_0_60_crop.png)

Sau khi crop, chuỗi hiện ra lặp lại:

```
RAUMAPHATAU
```

Đây là khoảnh khắc hint `36 Thanh Hoa` bắt đầu có nghĩa. `RAUMAPHATAU` đọc thành `rau ma pha tau`, một meme gắn với Thanh Hóa.

### Sai lầm: tưởng đây là flag

Vì chuỗi này hiện ra rất rõ, mình thử nghĩ nó là flag hoặc phần chính của flag:

```
LYKNCTF{RAUMAPHATAU}
LYKNCTF{rau_ma_pha_tau}
```

Sai. `RAUMAPHATAU` không phải flag, mà giống password cho lớp tiếp theo hơn.

---

## Phần 2: ZIP bị append vào cuối MP4

Sau audio, mình quay lại kiểm tra container. `exiftool` báo một dòng rất đáng nghi:

```bash
$ exiftool lyknctf.mp4
```

```
Warning                         : Unknown trailer with truncated '\x14\x00\x01\x00' data at offset 0x1e6ea8d
```

`Unknown trailer` thường nghĩa là sau phần MP4 hợp lệ còn dữ liệu thừa. Mình chạy `binwalk` để xem đó là gì:

```bash
$ binwalk lyknctf.mp4
```

Các dòng quan trọng:

```
31910541      0x1E6EA8D       Zip archive data, encrypted at least v2.0 to extract, compressed size: 79, uncompressed size: 49, name: flag.txt
31910734      0x1E6EB4E       End of Zip archive, footer length: 22
```

Có một ZIP bắt đầu đúng tại offset `0x1E6EA8D`, chứa `flag.txt` và bị mã hóa.

Mình cắt ZIP từ offset đó:

```bash
$ dd if=lyknctf.mp4 of=hidden_flag.zip bs=1 skip=31910541 status=none
```

Kiểm tra archive:

```bash
$ 7z l hidden_flag.zip
```

```
Path = hidden_flag.zip
Type = zip
Physical Size = 215

   Date      Time    Attr         Size   Compressed  Name
------------------- ----- ------------ ------------  ------------------------
2026-07-05 19:40:20 .....           49           79  flag.txt
```

`unzip` thường báo lỗi với method `99` vì đây là ZIP AES, nên mình dùng `7z`.

---

## Phần 3: Dùng chuỗi từ audio làm password

Password hợp lý nhất lúc này là chuỗi đọc được từ spectrogram: `RAUMAPHATAU`.

```bash
$ 7z x -y -pRAUMAPHATAU hidden_flag.zip -oextracted
```

```
Extracting archive: hidden_flag.zip
--
Path = hidden_flag.zip
Type = zip
Physical Size = 215

Everything is Ok

Size:       49
Compressed: 215
```

Đọc file bên trong:

```bash
$ cat extracted/flag.txt
```

```
LYKNCTF{NGU01_TH4NH_H04_4N_R4U_M4_PH4_DU0NG_T4U}
```

---

## Ghép Flag

| Thành phần | Giá trị | Nguồn |
|---|---|---|
| Password ZIP | `RAUMAPHATAU` | Spectrogram audio sau khi lọc và hạ pitch |
| ZIP ẩn | Offset `0x1E6EA8D` | Trailer cuối MP4 |
| File flag | `flag.txt` | ZIP AES trong trailer |

```
LYKNCTF{NGU01_TH4NH_H04_4N_R4U_M4_PH4_DU0NG_T4U}
```

---

## Bài học rút ra

**1. Video forensics nên kiểm cả stream lẫn trailer.**
`ffprobe` cho biết có những stream nào, còn `exiftool`/`binwalk` giúp phát hiện dữ liệu nối thêm cuối file.

**2. Spectrogram không nhất thiết chứa flag trực tiếp.**
Ở bài này spectrogram chỉ cho password. Nếu submit chuỗi hiện ra ngay lập tức thì dễ đi sai.

**3. ZIP method 99 nên dùng `7z`.**
`unzip` có thể không xử lý ZIP AES tốt, trong khi `7z` nhận ra và giải nén đúng.
