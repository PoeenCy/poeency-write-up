+++
title = 'Crypto For Kindergarten — Write-up'
date = '2026-06-10T22:55:59+07:00'
draft = false
tags = ['BKCTF2026', 'math', 'lattice']
categories = ['Cryptography']
+++

# Crypto For Kindergarten — Write-up

**BKISC CTF 2026 · Cryptography**

---

## Đề bài

> *"Crypto for Kindergarten — bài toán mật mã dành cho trẻ mầm non?"*

**Tải về đề bài:** [challenge files — OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQC4Td2ZJycNQIvobKjTQK6mATD4X0pZ_u2lfdCOf_Fcce0?e=whhahH)

Source code challenge:

```python
from Crypto.Util.number import getPrime
import os, secrets

FLAG = os.getenv("GZCTF_FLAG", "BKISC{local_test_flag}")

def main():
    secret_size = 256
    p_size = 32
    secret = os.urandom(secret_size)
    secret_num = int(secret.hex(), 16)
    for _ in range(75):
        option = input("Option: ")
        if option == "1":
            p = getPrime(p_size)
            r = secret_num % p
            if secrets.randbits(1):
                r = -r % p
            print(f'(p, r) = ({p}, {r})')
        elif option == "2":
            secret_input = bytes.fromhex(input("What is the secret? "))
            if secret_input == secret:
                print("Correct!")
                print("Here is your reward: ", FLAG)
            exit()

main()
```

Dữ liệu rò rỉ (74 cặp thu thập từ server):

```
p_list = [2379703019, 4257895777, 3914096657, ..., 2636092451]  # 74 giá trị
r_list = [1329177185, 4143119318, 3297201491, ...,  526800386]  # 74 giá trị
```

**Mục tiêu:** Khôi phục chuỗi `secret` dài 256 byte từ các cặp $(p_i, r_i)$ và gửi lại server dưới dạng hex.

---

## Mô tả bài toán

### Đặt ký hiệu

Server sinh bí mật $s \in \mathbb{Z}$ từ 256 byte ngẫu nhiên:

$$s = \texttt{int(os.urandom(256).hex(), 16)}, \quad 0 \le s < 2^{2048}$$

Với mỗi lần ta chọn Query (`"1"`), server:

1. Sinh số nguyên tố $p_i$ ngẫu nhiên 32-bit: $p_i \in [2^{31}, 2^{32})$.
2. Tính phần dư $r_i \leftarrow s \bmod p_i$, tức $0 \le r_i < p_i$.
3. Tung đồng xu: với xác suất $\tfrac{1}{2}$, thay $r_i \leftarrow p_i - r_i$.
4. Trả lại cặp $(p_i, r_i)$.

![**Hình 1.** Mô hình Oracle: với mỗi truy vấn, server tính $r_i = s \bmod p_i$ rồi ngẫu nhiên lật dấu.](/images/write-ups/bkctf-2026-crypto-kindergarten/fig1_oracle_model.png)

### Mô hình hóa bằng phương trình đồng dư

Sau bước lật dấu, $r_i$ có thể là $s \bmod p_i$ **hoặc** $(-s) \bmod p_i$. Nói cách khác:

$$r_i \equiv \epsilon_i \cdot s \pmod{p_i}, \quad \epsilon_i \in \{+1, -1\} \;\text{(ẩn)}$$

Đặt **bit dấu ẩn** $e_i \in \{0, 1\}$ và **độ lệch dấu**:

$$d_i \triangleq (p_i - 2r_i) \bmod p_i$$

Khi $e_i = 0$: $r_i + 0 \cdot d_i = r_i \equiv s \pmod{p_i}$ ✓  
Khi $e_i = 1$: $r_i + d_i = r_i + (p_i - 2r_i) = p_i - r_i \equiv -r_i \equiv s \pmod{p_i}$ ✓

Vậy, với **mọi** $e_i \in \{0,1\}$:

$$\boxed{s \equiv r_i + e_i \cdot d_i \pmod{p_i}}$$

Ta có $n = 74$ phương trình như vậy, nhưng mỗi $e_i$ đều **ẩn**, tạo ra $2^{74}$ tổ hợp khả dĩ.

---

## Quan sát then chốt

### Bước 1 — Nhận xét về kích thước

Mỗi $p_i$ là số nguyên tố 32-bit, tức $p_i \approx 2^{32}$. Khi ta thu thập $n = 74$ truy vấn, xét tích:

$$M \triangleq \prod_{i=1}^{74} p_i \approx (2^{32})^{74} = 2^{2368}$$

So sánh với $s$:

$$s < 2^{2048} \ll M \approx 2^{2368}$$

Chênh lệch: $\Delta = 2368 - 2048 = \mathbf{320}$ **bit dư thừa**.

![**Hình 2.** So sánh kích thước: $s < 2^{2048}$ và $M \approx 2^{2368}$. Khoảng dư 320 bit là điều kiện cốt lõi để lưới LLL hoạt động.](/images/write-ups/bkctf-2026-crypto-kindergarten/fig2_size_comparison.png)

### Bước 2 — Áp dụng Định lý Số dư Trung Hoa (CRT)

**Định lý CRT:** Nếu $p_1, \ldots, p_n$ đôi một nguyên tố cùng nhau (đây là các số nguyên tố phân biệt nên thỏa mãn), thì hệ $n$ phương trình đồng dư:

$$s \equiv a_i \pmod{p_i}, \quad i = 1, \ldots, n$$

có **đúng một nghiệm duy nhất** $s^* \in [0, M)$ với $M = \prod p_i$.

Trong bài này, mỗi phương trình là $s \equiv r_i + e_i d_i \pmod{p_i}$. Gọi $a_i \triangleq r_i + e_i d_i$ (giá trị đúng — ẩn vì $e_i$ ẩn). Theo CRT, nghiệm là:

$$s = \sum_{i=1}^{n} a_i \cdot C_i \bmod M$$

trong đó $C_i$ là **hệ số CRT** thứ $i$:

$$C_i \triangleq \frac{M}{p_i} \cdot \left(\frac{M}{p_i}\right)^{-1}_{\!\!\bmod p_i} \bmod M$$

Khai triển $a_i = r_i + e_i d_i$:

$$s = \sum_{i=1}^{n} (r_i + e_i d_i) C_i \bmod M = \underbrace{\sum_{i=1}^n r_i C_i}_{\displaystyle R} + \sum_{i=1}^n e_i \underbrace{d_i C_i}_{\displaystyle C'_i} \bmod M$$

$$\boxed{s \equiv R + \sum_{i=1}^{n} e_i \cdot C'_i \pmod{M}}$$

Cả $R$ và $C'_i$ đều **tính được hoàn toàn** từ dữ liệu quan sát $(p_i, r_i)$. Ẩn số duy nhất còn lại là vector bit dấu $\mathbf{e} = (e_1, \ldots, e_n) \in \{0,1\}^n$.

### Bước 3 — Bài toán tìm vector ngắn trong lưới

Không tính modulo, phương trình trên có dạng:

$$s = R + \sum_{i=1}^{n} e_i C'_i - k \cdot M, \quad k \in \mathbb{Z}$$

Đặt $W \triangleq 2^{2048}$ (hệ số tỉ lệ). Xét vector $(n+2)$-chiều:

$$\mathbf{t} \triangleq \bigl(\underbrace{s}_{\text{bí mật}},\; \underbrace{e_1 W, \ldots, e_n W}_{\text{các bit dấu}},\; \underbrace{W}_{\text{nhãn}}\bigr) \in \mathbb{Z}^{n+2}$$

- Thành phần đầu: $s < W = 2^{2048}$
- Thành phần giữa: $e_i W \in \{0, W\}$
- Thành phần cuối: $W$ (cố định, dùng để nhận dạng vector đúng)

Chuẩn Euclidean:

$$\|\mathbf{t}\|_2 = \sqrt{s^2 + \sum e_i^2 W^2 + W^2} \approx \sqrt{n+2} \cdot W \approx \sqrt{76} \cdot 2^{2048} \approx 2^{2051.5}$$

**Điểm mấu chốt:** Vector $\mathbf{t}$ có chuẩn nhỏ hơn nhiều so với chuẩn kỳ vọng của lưới (Gaussian heuristic $\approx 2^{2052}$), và **nằm trong lưới** mà ta sắp xây dựng.

---

## Chiến lược tấn công

![**Hình 3.** Luồng tấn công: Thu thập → CRT → Xây lưới → LLL → Submit FLAG.](/images/write-ups/bkctf-2026-crypto-kindergarten/fig4_attack_flow.png)

### Bước 4 — Xây dựng ma trận lưới

Ta xây dựng ma trận $\mathbf{B} \in \mathbb{Z}^{(n+2)\times(n+2)}$ như sau:

$$\mathbf{B} = \begin{pmatrix}
M    & 0 & 0 & \cdots & 0 & 0 \\
C'_1 & W & 0 & \cdots & 0 & 0 \\
C'_2 & 0 & W & \cdots & 0 & 0 \\
\vdots&\vdots&\vdots&\ddots&\vdots&\vdots\\
C'_n & 0 & 0 & \cdots & W & 0 \\
R    & 0 & 0 & \cdots & 0 & W
\end{pmatrix}$$

![**Hình 4.** Cấu trúc ma trận lưới $\mathbf{B}$ kích thước $(n+2)\times(n+2)$. Cột cam (col 0) chứa các hệ số CRT. Đường chéo xanh (col 1..n+1) là $W \cdot I$.](/images/write-ups/bkctf-2026-crypto-kindergarten/fig3_lattice_matrix.png)

**Chứng minh $\mathbf{t} \in \mathcal{L}(\mathbf{B})$:** Xét tổ hợp tuyến tính nguyên với hệ số $(-k, e_1, e_2, \ldots, e_n, -1)$:

$$(-k) \cdot \text{row}_0 + \sum_{i=1}^n e_i \cdot \text{row}_i + (-1) \cdot \text{row}_{n+1}$$

- **Cột 0:** $-kM + \sum e_i C'_i - R = s - kM + \sum e_i C'_i - R$. Từ phương trình CRT: $s = R + \sum e_i C'_i - kM$, suy ra thành phần cột 0 $= s$. ✓
- **Cột $i$ ($1 \le i \le n$):** $e_i \cdot W$. ✓
- **Cột $n+1$:** $(-1) \cdot W = -W$. ✓

Vậy $\mathbf{t} = (\pm s, e_1 W, \ldots, e_n W, \pm W)$ thuộc lưới $\mathcal{L}(\mathbf{B})$.

### Bước 5 — Rút gọn lưới bằng LLL và trích nghiệm

Giải thuật **LLL** (Lenstra–Lovász–Lovász, 1982) tìm một cơ sở rút gọn của lưới, trong đó vector ngắn nhất được đảm bảo có chuẩn không quá $2^{(n+2)/4}$ lần vector ngắn nhất thật sự. Vì $\mathbf{t}$ cực kỳ ngắn (chênh $\Delta = 320$ bit), LLL thực tế tìm được $\mathbf{t}$ (hoặc $-\mathbf{t}$) ngay trong lần chạy đầu tiên.

Sau khi có $\mathbf{B}_{\text{LLL}} = \text{LLL}(\mathbf{B})$, ta duyệt từng hàng $\mathbf{r}$:

| Điều kiện kiểm tra | Ý nghĩa |
|---|---|
| $|r_{n+1}| = W$ | Đây là hàng ứng với vector mục tiêu |
| $r_j \in \{0, W, -W\}$ với mọi $j=1..n$ | Các bit $e_i$ hợp lệ |
| $|r_0| < W$ | Nghiệm nằm trong phạm vi $[0, 2^{2048})$ |

Khi thỏa mãn: $s = |r_0|$.

---

## Triển khai

Script chia thành **Công cụ 1** (kết nối server, thu thập, submit) và **Công cụ 2** (giải lưới offline bằng SageMath).

### Công cụ 1 — `finding.py`

```python
import re, time
from websocket import create_connection

def solve():
    # ================================================================
    # Pha 1: Thu thập 74 cặp (p_i, r_i) từ Oracle
    # ================================================================
    uri = "wss://ctf.bkisc.com/api/proxy/<INSTANCE_ID>"
    ws  = create_connection(uri)

    def read_until(prompt):
        data = ""
        while prompt not in data:
            buf = ws.recv()
            data += buf.decode('utf-8') if isinstance(buf, bytes) else buf
        return data

    read_until("Option: ")
    p_list, r_list = [], []

    for i in range(74):
        ws.send("1\n")
        time.sleep(0.05)
        resp  = read_until("Option: ")
        m = re.search(r'\(p, r\) = \((\d+), (\d+)\)', resp)
        if m:
            p_list.append(int(m.group(1)))
            r_list.append(int(m.group(2)))
            print(f"  [{i+1}/74] p={p_list[-1]}, r={r_list[-1]}")

    print(f"\np_list = {p_list}")
    print(f"r_list = {r_list}")
    print("\n→ Copy hai dòng trên, dán vào solve.sage và chạy trên SageMath Cell.")

    # ================================================================
    # Pha 3: Submit kết quả sau khi có hex từ SageMath
    # ================================================================
    hex_secret = input("\n[?] Dán chuỗi HEX từ SageMath: ").strip()
    ws.send("2\n");  read_until("What is the secret? ")
    ws.send(hex_secret + "\n")

    while True:
        buf = ws.recv()
        if not buf: break
        print((buf.decode('utf-8') if isinstance(buf, bytes) else buf), end="")

if __name__ == "__main__":
    solve()
```

### Công cụ 2 — `solve.sage`

```python
# Chạy: sage solve.sage  (hoặc dán lên sagecell.sagemath.org)
from sage.all import *

# ================================================================
# Pha 2A: Dữ liệu thu thập được
# ================================================================
p_list = [2379703019, 4257895777, 3914096657, 3528903647, 3354735113,
          2371636537, 3093826397, 2326873231, 3436362607, 3370765777,
          2414955509, 2790339379, 2917241959, 2512982713, 3838109309,
          2579487377, 2906471357, 2581473109, 3207099923, 2690875393,
          2834938511, 2648337953, 3406056631, 3923640991, 4158697339,
          3684191761, 2518082797, 2647027711, 3827727053, 3463588393,
          2679396703, 2304888281, 2954550637, 3586512607, 2382502211,
          3668946929, 3866400311, 4157531461, 3066004531, 2795034647,
          4209878927, 2430538853, 2635538813, 2818131907, 3405126071,
          3858461603, 2461374313, 2566812077, 2559345743, 2764186921,
          4049617171, 3033268151, 2666428333, 2857618433, 3129990317,
          3389457469, 2580064429, 2159490791, 3934645249, 2328616133,
          3182371177, 2190229757, 3580970977, 3986611309, 2636467817,
          3005145491, 2585262919, 2663192591, 2629985857, 2494146439,
          3352592339, 2688017069, 4025439709, 2636092451]

r_list = [1329177185, 4143119318, 3297201491,  195307827,  820363902,
          1559582815,  282992153, 1088571329, 1589612880, 2037158222,
          1777363824, 1430693338, 1673034777, 1756839917,  700290228,
           689692528, 1065039844,  566073547, 2939816939,  192110337,
           462976342,  331267740, 1875930444,  779699293, 1063952269,
          3259672649, 2211727282, 2085279394, 2658209742, 3159429453,
           223984574, 1466961743, 2640715512,  923330014, 2083220221,
           583191295, 1904107527, 1215642454,  310758698,  668640010,
          3084172398, 1620836551, 1839131092, 2341302982,  498475512,
           417396410, 1743190788, 1996258647,   79244288,  246166764,
          2706284948, 1320745478, 2013394780, 2696054502, 1265537445,
          1659400938,  118500369,  858084044,  534088948,  970172704,
           590984059,  818029748, 1616656913, 2480874429, 2317209756,
          1851813169,  591148914, 2099512249, 1971976248,  731178434,
           816861169,   15808790, 1410913924,  526800386]

n = len(p_list)  # 74
M = prod(p_list) # M ≈ 2^{2368}
W = 2^2048       # Hệ số tỉ lệ, bằng chặn trên của s

# ================================================================
# Pha 2B: Tính hệ số CRT
#   C_i  = (M/p_i) * modinv(M/p_i, p_i)  mod M
#   d_i  = (p_i - 2*r_i) mod p_i          (offset khi e_i=1)
#   C'_i = d_i * C_i mod M
#   R    = sum(r_i * C_i) mod M
# ================================================================
C, d = [], []
for i in range(n):
    Mp  = M // p_list[i]
    inv = inverse_mod(Mp, p_list[i])
    C.append((Mp * inv) % M)
    d.append((p_list[i] - 2 * r_list[i]) % p_list[i])

Cp = [(d[i] * C[i]) % M for i in range(n)]
R  = sum(r_list[i] * C[i] for i in range(n)) % M

# ================================================================
# Pha 2C: Xây dựng ma trận lưới (n+2) × (n+2)
#   Hàng 0      : [M,    0, ..., 0, 0]
#   Hàng 1..n   : [C'_i, 0, ..., W(tại i+1), ..., 0, 0]
#   Hàng n+1    : [R,    0, ..., 0, W]
# ================================================================
rows = [[M] + [0]*n + [0]]
for i in range(n):
    row = [Cp[i]] + [0]*n + [0]
    row[1 + i] = W
    rows.append(row)
rows.append([R] + [0]*n + [W])

B = Matrix(ZZ, rows)  # Lưới 76×76

# ================================================================
# Pha 2D: Rút gọn LLL và trích xuất nghiệm s
# ================================================================
print("[*] Chạy LLL trên lưới 76×76 ...")
L = B.LLL()

found = False
for row in L:
    if abs(row[-1]) != W:               # điều kiện nhận dạng
        continue
    if not all(v in [0, W, -W] for v in row[1:-1]):  # các bit e_i hợp lệ
        continue
    s_cand = abs(row[0])
    if s_cand < W:                       # nghiệm trong phạm vi
        sb = int(s_cand).to_bytes(256, byteorder='big')
        print("\n[+] secret (hex):", sb.hex())
        found = True
        break

if not found:
    print("[-] LLL thất bại — thử BKZ(block_size=20).")
```

---

## Kết quả

Chạy `solve.sage` trên SageMath Cell. LLL hội tụ sau vài phút:

```
[*] Chạy LLL trên lưới 76×76 ...

[+] secret (hex): 23e883a6b9175c0294c2da89506aadc59cfc3b459627f9bb26a648053f4fee90
3c0f8a3310cf6cb88253121b285faf8326662d3975d304b73d1b2d00a08d9d574
d646815681336f4668...
```

Dán hex vào `finding.py` → server trả về:

```
Correct!
Here is your reward:  BKISC{h1dd3n_numb3r_pr0bl3m_w1th_s1gn_4mb1gu1ty}
```

$$\boxed{\texttt{BKISC\{h1dd3n\_numb3r\_pr0bl3m\_w1th\_s1gn\_4mb1gu1ty\}}}$$

---

## Nhận xét

| Điểm yếu | Hậu quả |
|---|---|
| $p_i \approx 2^{32}$ nhỏ hơn $s \approx 2^{2048}$ rất nhiều | Mỗi truy vấn chỉ lộ ~32 bit thông tin |
| $74 \times 32 = 2368 > 2048$ bit | CRT xác định $s$ duy nhất mod $M$, dư thừa 320 bit đảm bảo LLL thành công |
| Lật dấu ngẫu nhiên không che được $s$ | $2^{74}$ tổ hợp dấu vẫn bị phá vỡ bởi lưới |

**Biện pháp phòng thủ:** Dùng $p_i \ge 256$ bit, giảm số truy vấn xuống $\le 30$, hoặc chỉ tiết lộ $k < p_i$ bit thấp của $s \bmod p_i$ (HNP chuẩn). Nguyên tắc cốt lõi: khi $\sum_i \log_2 p_i > \log_2 s$, bí mật **luôn bị rò rỉ hoàn toàn** qua CRT, bất kể dấu có bị ẩn hay không.
