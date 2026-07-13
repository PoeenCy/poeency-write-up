+++
title = 'Hash & Dash - Write-up'
date = '2026-07-14T03:05:00+07:00'
draft = false
tags = ['LYCKNCTF2026', 'sha256', 'hash-length-extension', 'parameter-pollution', 'hashpumpy']
categories = ['Cryptography', 'Web']
+++

# CTF Write-up: Hash & Dash

**Category:** Crypto / Web
**Flag format:** `LYKNCTF{...}`
**Flag cuối:** không còn lưu lại được sau khi instance kết thúc

---

## Mô tả bài

> A tiny access-token service is waiting for your request. You are given a valid guest token. Your goal is to submit a valid token for a message that grants admin access. Start an instance and connect to the provided host and port:
>
> `nc 51.79.140.18 11275`
>
> `{"message": "user=guest&role=viewer", "message_hex": "757365723d677565737426726f6c653d766965776572", "token": "988de84ef757890f2efbe3678c76458cd7e5120234a4a4e4da8dcfd0d133004c"}`
>
> Submit one JSON line with msg and tag.

Bài này là black-box. Mình không có source backend, chỉ có một service TCP cấp sẵn một message guest và một token hợp lệ. Nhiệm vụ là gửi lại một JSON line có `msg` và `tag` sao cho server hiểu message đó có quyền admin.

Port trong mô tả là port của instance lúc mình ghi note ban đầu. Instance CTF dạng này có thể đổi port khi start lại; exploit cuối của mình lưu port `10770`.

---

## Nhận file và kiểm tra nhanh

Trong thư mục local của bài, mình chỉ còn lại note cũ và script exploit. Không có source server:

```bash
$ ls -la
```

```
total 24
drwxrwxr-x  3 poeency poeency 4096 Jul 14 03:03 .
drwxrwxr-x 12 poeency poeency 4096 Jul  7 02:19 ..
-rw-rw-r--  1 poeency poeency 2776 Jul  6 14:43 exploit.py
drwxrwxr-x  6 poeency poeency 4096 Jul  6 14:19 myenv
-rw-rw-r--  1 poeency poeency 7053 Jul 14 03:03 write-up.md
```

File note cũ bị lỗi encoding, nhưng vẫn giữ được các dữ kiện chính. Script exploit thì còn nguyên UTF-8:

```bash
$ file write-up.md exploit.py
```

```
write-up.md: data
exploit.py:  Python script, Unicode text, UTF-8 text executable
```

Điểm mình nhìn vào đầu tiên là token trong đề:

```bash
$ ./myenv/bin/python - <<'PY'
import json
orig_msg = b'user=guest&role=viewer'
orig_hash = '988de84ef757890f2efbe3678c76458cd7e5120234a4a4e4da8dcfd0d133004c'
print('message length:', len(orig_msg))
print('token hex length:', len(orig_hash))
print('token bytes:', len(bytes.fromhex(orig_hash)))
print(json.dumps({'message': orig_msg.decode(), 'message_hex': orig_msg.hex(), 'token': orig_hash}, indent=2))
PY
```

```
message length: 22
token hex length: 64
token bytes: 32
{
  "message": "user=guest&role=viewer",
  "message_hex": "757365723d677565737426726f6c653d766965776572",
  "token": "988de84ef757890f2efbe3678c76458cd7e5120234a4a4e4da8dcfd0d133004c"
}
```

Token dài 64 hex tức là 32 byte. Trong một bài crypto/web kiểu access-token, đây là dấu hiệu rất mạnh của SHA-256.

---

## Phần 1: Nhận ra hướng length extension

Vì service đưa cho mình:

```text
message = user=guest&role=viewer
token   = 988de84ef757890f2efbe3678c76458cd7e5120234a4a4e4da8dcfd0d133004c
```

Mình đặt giả thuyết backend ký message bằng cách tự nối secret với message rồi hash:

```text
token = SHA256(secret || message)
```

Nếu đúng là dạng này, SHA-256 dính lỗi kinh điển của cấu trúc Merkle-Damgard: biết `SHA256(secret || message)` và biết độ dài của `secret || message` thì có thể tiếp tục hash thêm dữ liệu phía sau mà không cần biết secret.

Mục tiêu của mình là biến message từ:

```text
user=guest&role=viewer
```

thành dạng có thêm tham số cấp quyền, ví dụ:

```text
user=guest&role=viewer<PADDING>&admin=true
```

Vấn đề là padding SHA-256 phụ thuộc vào tổng độ dài `secret || message`, mà mình không biết secret dài bao nhiêu.

---

## Phần 2: Brute-force secret length

Vì không có source, mình không thể đọc secret hoặc biết secret length. Cách thực dụng nhất là thử một khoảng độ dài hợp lý, thường từ vài byte đến vài chục byte.

Trong note cũ, response quan trọng mình lưu lại được là:

```json
{"ok": true, "admin": false, "error": "token valid but no admin grant"}
```

Response này rất đáng giá. Nó nói rằng token đã hợp lệ, nhưng message chưa được backend hiểu là admin. Nói cách khác:

- Hash length extension đã thành công.
- Secret length đoán đúng là `16`.
- Payload admin đang thử chưa đúng với logic parse của backend.

Đây là khoảnh khắc mình tách bài thành hai lớp:

> Crypto layer đã bypass được. Phần còn lại không còn là SHA-256 nữa, mà là tìm đúng parameter mà backend dùng để cấp quyền.

---

## Phần 3: Kiểm tra payload length extension offline

Instance đã kết thúc nên mình không còn query lại server được, nhưng vẫn có thể sinh lại payload length extension offline từ token ban đầu. Mình dùng `hashpumpy` với `key_len = 16` và thử append `&admin=true`:

```bash
$ ./myenv/bin/python - <<'PY'
import hashpumpy
orig_msg = b'user=guest&role=viewer'
orig_hash = '988de84ef757890f2efbe3678c76458cd7e5120234a4a4e4da8dcfd0d133004c'
append_data = b'&admin=true'
new_hash, new_msg = hashpumpy.hashpump(orig_hash, orig_msg, append_data, 16)
print('new_hash:', new_hash)
print('new_msg_hex:', new_msg.hex())
print('new_msg_len:', len(new_msg))
print('contains admin payload:', append_data in new_msg)
PY
```

```
new_hash: e64548a431626613d0fa9c31b19063ccc976d3b1c21b295a8302a625a45a93ea
new_msg_hex: 757365723d677565737426726f6c653d76696577657280000000000000000000000000000000000000000000000001302661646d696e3d74727565
new_msg_len: 59
contains admin payload: True
```

Đoạn hex này có ba phần:

| Phần | Ý nghĩa |
|---|---|
| `757365723d677565737426726f6c653d766965776572` | `user=guest&role=viewer` |
| `80...0130` | SHA-256 glue padding cho `secret || message` |
| `2661646d696e3d74727565` | `&admin=true` |

Điểm quan trọng là mình không gửi raw string trực tiếp, mà gửi `msg` dưới dạng hex. Nhờ đó các byte padding không in được vẫn đi qua JSON an toàn.

---

## Sai lầm 1: Nghĩ rằng chỉ cần append `&role=admin`

Payload tự nhiên nhất là:

```text
&role=admin
```

Vì message ban đầu có `role=viewer`, mình nghĩ thêm `role=admin` ở sau sẽ ghi đè role cũ. Nhưng response trong note cho thấy token valid mà admin vẫn false:

```json
{"ok": true, "admin": false, "error": "token valid but no admin grant"}
```

Sai ở đây không phải crypto. Sai ở tầng parse parameter. Có thể backend lấy giá trị `role` đầu tiên, có thể nó không dùng key `role`, hoặc có thể nó cần một tên field khác hẳn.

---

## Sai lầm 2: Nhìn bài như crypto thuần

Tên bài là `Hash & Dash`, category mình ghi lại là Crypto/Web. Ban đầu mình tập trung vào hash và length extension, nhưng sau khi token hợp lệ mà không có admin, phần còn lại rõ ràng là web logic.

Nếu chỉ coi đây là crypto thuần, mình sẽ dừng ở `new_hash` và nghĩ exploit chưa đúng. Nhưng response `token valid` đã xác nhận phần crypto đúng rồi. Việc cần làm tiếp là fuzz các tham số cấp quyền.

---

## Phần 4: HTTP Parameter Pollution trên message

Vì backend nhận message dạng query string:

```text
user=guest&role=viewer
```

mình thử nhiều tham số thường gặp trong CTF:

```python
admin_payloads = [
    b"&admin=true",
    b"&admin=1",
    b"&user=admin",
    b"&user=root",
    b"&role=administrator",
    b"&role=root",
    b"&role=system",
    b"&is_admin=true",
    b"&is_admin=1",
    b"&privilege=admin",
    b"&grant=admin"
]
```

Mỗi payload đều được đưa qua hash length extension với cùng `KEY_LEN = 16`, sau đó gửi lên server:

```json
{
  "msg": "<forged_message_hex>",
  "tag": "<forged_sha256>"
}
```

Script cuối của mình:

```python
import json
import hashpumpy
from pwn import remote, context

HOST = '51.79.140.18'
PORT = 10770

context.log_level = 'error'

KEY_LEN = 16

admin_payloads = [
    b"&admin=true",
    b"&admin=1",
    b"&user=admin",
    b"&user=root",
    b"&role=administrator",
    b"&role=root",
    b"&role=system",
    b"&is_admin=true",
    b"&is_admin=1",
    b"&privilege=admin",
    b"&grant=admin"
]

def solve():
    print(f"[*] Da xac dinh secret_length = {KEY_LEN}.")
    print("[*] Bat dau thu nghiem cac payload ep quyen admin...\\n")

    for append_data in admin_payloads:
        print(f"[*] Dang chen them tham so: {append_data.decode()} ...")

        r = None
        try:
            r = remote(HOST, PORT)

            while True:
                line = r.recvline().decode().strip()
                if line.startswith('{'):
                    break

            data = json.loads(line)
            orig_msg = data['message'].encode()
            orig_hash = data['token']

            try:
                r.recvline(timeout=1)
            except Exception:
                pass

            new_hash, new_msg = hashpumpy.hashpump(
                orig_hash,
                orig_msg,
                append_data,
                KEY_LEN
            )

            payload = {
                "msg": new_msg.hex(),
                "tag": new_hash
            }

            r.sendline(json.dumps(payload).encode())
            resp = r.recvall(timeout=1.5).decode().strip()

            if not resp:
                continue

            if "no admin grant" in resp.lower() or "invalid" in resp.lower():
                print("   [-] Failed.")
                continue

            print(f"\\n[+] BINGO: {append_data.decode()}")
            print(f"[+] Sent: {json.dumps(payload)}")
            print(f"\\n[+] Server response:\\n{resp}\\n")
            break

        except Exception:
            pass
        finally:
            if r:
                r.close()

if __name__ == '__main__':
    solve()
```

Instance đã chết nên mình không còn output flag cuối để paste lại. Nhưng theo note cũ, sau khi `key_len = 16` được xác định, việc thử danh sách parameter này đã tìm được parameter đúng và server trả flag.

---

## Ghép Flag

| Thành phần | Giá trị | Nguồn |
|---|---|---|
| Hash primitive | SHA-256 | Token dài 64 hex / 32 byte |
| Message gốc | `user=guest&role=viewer` | JSON server cấp |
| Secret length | `16` | Response `token valid but no admin grant` khi brute-force |
| Crypto bug | Length extension | `SHA256(secret || message)` |
| Logic bug | Parameter pollution | Query-string style message |
| Flag | không còn lưu lại được | Instance đã kết thúc |

```text
LYKNCTF{...}
```

---

## Bài học rút ra

**1. SHA-256 không phải MAC.**
Nếu backend ký bằng `SHA256(secret || message)`, digest cuối chính là state có thể tiếp tục mở rộng. Muốn ký message phải dùng HMAC, ví dụ `HMAC-SHA256(secret, message)`.

**2. Response phân biệt lỗi là oracle rất mạnh.**
`invalid token` và `token valid but no admin grant` là hai trạng thái khác nhau. Chỉ cần server phân biệt như vậy, mình có thể biết lúc nào secret length đã đúng.

**3. Black-box crypto thường có lớp web logic phía sau.**
Sau khi token hợp lệ, bài chưa kết thúc. Vì message là query string, phải nghĩ tiếp tới cách backend parse parameter: first value wins, last value wins, hoặc một key admin khác.

**4. Gửi forged message bằng hex giúp tránh lỗi byte padding.**
Glue padding SHA-256 chứa byte như `0x80` và nhiều byte null. Nếu service cho gửi `msg` dạng hex thì nên dùng hex, tránh vỡ JSON hoặc encoding.
