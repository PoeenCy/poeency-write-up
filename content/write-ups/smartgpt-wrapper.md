+++
title = 'SmartGPT Wrapper — Write-up'
date = '2026-08-31T22:08:55+07:00'
draft = false
tags = ['CTF', 'reverse-engineering', 'SmartGPT', 'PyInstaller', 'Python', 'bytecode', 'base64']
categories = ['Reverse Engineering']
description = 'Reverse một PyInstaller binary để khôi phục API key bị chia thành các fragment Base64.'
summary = 'Giải SmartGPT Wrapper bằng cách unpack PyInstaller, đọc bytecode Python và sắp lại các fragment Base64.'
showToc = true
+++

# CTF Write-up: SmartGPT Wrapper

**Category:** Reverse Engineering
**Flag format:** `flag{...}`
**Flag cuối:** `flag{12dde48b-f12b-40e1-b005-1b682ed070b8}`

---

## Mô tả bài

> A free ChatGPT wrapper made by totally legitimate developers.
> Find the hardcoded API key.

File đính kèm: `smartgpt` — một binary duy nhất, không có source, không có gì thêm.

---

## Nhận file và kiểm tra nhanh

Việc đầu tiên với bất kỳ binary lạ nào là `file`:

```bash
$ file smartgpt
smartgpt: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, stripped
```

ELF 64-bit, stripped. Thông thường gặp loại này thì nghĩ ngay đến Ghidra. Tuy nhiên, trước khi đi theo hướng đó, mình thử chạy `strings` trước cho chắc:

```bash
$ strings smartgpt | head -80
```

Trong đống output chạy qua màn hình, mình để ý mấy chuỗi này:

```
_MEIPASS2
base_library.zip
PYZ-00.pyz
libpython3.8.so.1.0
```

Đây là dấu hiệu đặc trưng của **PyInstaller** — công cụ đóng gói ứng dụng Python thành một file thực thi duy nhất. Nói cách khác, lõi của binary này không phải native code C mà là bytecode Python 3.8. Do đó, Ghidra ở đây hoàn toàn vô dụng.

Mình chạy thử một lần xem nó tự giới thiệu như thế nào:

```bash
$ chmod +x smartgpt && echo -e "config\nhelp\nexit\n" | ./smartgpt
```

![Giao diện banner và output khi chạy smartgpt](/images/write-ups/smartgpt-wrapper/smartgpt_runtime_banner.png)

Đáng chú ý hơn cái banner là dòng `offline mode`. App này không gọi mạng thật — AI response chỉ là random string lấy từ list cứng trong code, lệnh `config` in ra một API endpoint dummy. Toàn bộ là màn kịch, không có gì thật.

---

## Unpack PyInstaller và đọc bytecode

Mình dùng `pyinstxtractor` để giải nén:

```bash
$ python3 pyinstxtractor.py smartgpt
[+] Python version: 3.8
[+] Found 49 files in CArchive
[+] Possible entry point: smartgpt.pyc
[+] Successfully extracted pyinstaller archive: smartgpt
```

Thư mục `smartgpt_extracted/` xuất hiện với 49 file — phần lớn là thư viện chuẩn Python. Thứ mình cần là `smartgpt.pyc`, entry point của toàn bộ ứng dụng.

Bytecode Python lưu string constant dưới dạng rõ ràng — không nén, không mã hóa — nên `strings` kéo ra được nguyên si:

```bash
$ strings smartgpt_extracted/smartgpt.pyc
```

```
SmartGPT Wrapper
Free AI Productivity Plugin v2.1.0
A suspicious 'free ChatGPT wrapper' app downloaded by a university student.
Contains a hardcoded API key that is the flag (obfuscated).
Reconstruct the internal API key from build-time signature fragments.
Each fragment was base64-encoded at build time and the order in which
fragments are *declared* in the source above is a permutation of the
real concatenation order. The mapping in _CRED_REASSEMBLY_ORDER tells
us how to put them back together.
...
OGItZjEyYi00MGU=
ZmxhZ3sxMmRkZTQ=
MS1iMDA1LTFiNg==
ODJlZDA3MGI4fQ==
...
_CRED_FRAGMENT_X
_CRED_FRAGMENT_Y
_CRED_FRAGMENT_Z
_CRED_FRAGMENT_W
_CRED_REASSEMBLY_ORDER
```

Docstring trong source mô tả thẳng cơ chế. Có 4 fragment `X, Y, Z, W`, mỗi cái là một mảnh base64 độc lập, và một tuple `_CRED_REASSEMBLY_ORDER` xác định thứ tự ghép thật — **không phải** `X → Y → Z → W` như cách đặt tên gợi ý.

---

## Truy tìm thứ tự ghép thật

`strings` chỉ cho thấy tên biến `_CRED_REASSEMBLY_ORDER`, không cho thấy giá trị của nó. Vì vậy, mình cần đào sâu hơn vào raw bytes của file `.pyc`.

Python marshal protocol lưu string theo cấu trúc: một byte đánh dấu loại (`t`/`u`/`z`/`s`) + 4 byte length dạng little-endian + data. Dựa vào đó, mình viết một parser nhỏ để quét toàn bộ:

```python
import sys
sys.path = [p for p in sys.path if 'smartgpt_extracted' not in p]

with open('smartgpt_extracted/smartgpt.pyc', 'rb') as f:
    raw = f.read()

i = 0
while i < len(raw):
    if raw[i] in (0x74, 0x75, 0x7a, 0x73):
        length = int.from_bytes(raw[i+1:i+5], 'little')
        if 4 <= length <= 200 and i+5+length <= len(raw):
            s = raw[i+5:i+5+length]
            try:
                text = s.decode('utf-8')
                if text.isprintable():
                    print(repr(text))
            except:
                pass
    i += 1
```

Kết quả kéo ra một docstring nằm trong hàm `_load_credentials`, nói thẳng rằng thứ tự ghép là `Y, X, Z, W`.

> Cơ chế obfuscation ở đây không dùng mã hóa gì phức tạp — tên biến được đặt theo thứ tự `X, Y, Z, W` để người đọc thoáng qua tự nhiên nghĩ thứ tự ghép cũng vậy. Thực tế thì bytecode hardcode tuple `("Y", "X", "Z", "W")` và hàm `_load_credentials` duyệt theo tuple đó, không theo tên biến. Đây là kỹ thuật đánh vào kỳ vọng của người đọc, không phải kỹ thuật mã hóa.

---

## Decode flag

Mình viết script decode theo thứ tự đúng:

```python
import base64

fragments = {
    "X": "OGItZjEyYi00MGU=",
    "Y": "ZmxhZ3sxMmRkZTQ=",
    "Z": "MS1iMDA1LTFiNg==",
    "W": "ODJlZDA3MGI4fQ==",
}
order = ("Y", "X", "Z", "W")

flag = "".join(
    base64.b64decode(fragments[label]).decode("utf-8")
    for label in order
)
print(flag)
```

Từng mảnh sau khi decode:

| Nhãn | Base64 | Sau decode |
|------|--------|------------|
| `Y` | `ZmxhZ3sxMmRkZTQ=` | `flag{12dde4` |
| `X` | `OGItZjEyYi00MGU=` | `8b-f12b-40e` |
| `Z` | `MS1iMDA1LTFiNg==` | `1-b005-1b6` |
| `W` | `ODJlZDA3MGI4fQ==` | `82ed070b8}` |

---

## Ghép Flag

```
flag{12dde48b-f12b-40e1-b005-1b682ed070b8}
```
