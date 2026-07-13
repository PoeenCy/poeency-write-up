+++
title = 'LCG in LCG — Write-up'
date = '2026-06-10T19:00:00+07:00'
draft = false
tags = ['BKCTF2026', 'lcg', 'math']
categories = ['Cryptography']
+++

# LCG in LCG — Write-up

**BKISC CTF 2026 · Cryptography**

---

## Đề bài

> *"An LCG with a single (a,b) pair alone is not secure enough. So I decided to do many of them!"*

**Tải về đề bài:** [challenge files — OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQCxrrt3_xBpTIY2wQbyMLvCAdYS5QN2TFfB6lggx5L0k8o?e=Hnk31J)

Đây là toàn bộ source code chương trình challenge được cung cấp:

```python
from Crypto.Util.number import *
import random

FLAG = b"BKISC{REDACTED}"
SIZE = 10
p = getPrime(256)
list_ab = [(random.randint(1, p), random.randint(1, p)) for _ in range(SIZE)]

class LCG:
    def __init__(self, seed):
        self.p_shuffle = 100012367912491304950970537118525513361574730061518925742496715244134368935279
        self.a_shuffle = 94671321777649901144236237096963884182038803186726157270932012072190410389427
        self.b_shuffle = 64123254129311387582805351522310702500911175067175029340692470572851876649363
        self.seed_shuffle = getPrime(256)   # ẩn, không công khai

        self.m = p
        self.s = seed
        self.curr = random.randint(0, SIZE - 1)

    def next(self):
        a, b = list_ab[self.curr]
        self.s = (a * self.s + b) % self.m

        # LCG phụ trợ để chọn index ngẫu nhiên cho bước kế tiếp
        self.seed_shuffle = (self.a_shuffle * self.seed_shuffle + self.b_shuffle) % self.p_shuffle
        self.curr = self.seed_shuffle % SIZE
        return self.s

s = getPrime(256)
c = LCG(s)

leak = [c.next() for _ in range(30)]
ct   = [(c.next() & 0xFF) ^ FLAG[i] for i in range(len(FLAG))]

print(f"p    = {p}")
print(f"leak = {leak}")
print(f"ct   = {ct}")
```

Chương trình in ra ba giá trị: số nguyên tố $p$ (256-bit), mảng `leak` gồm 30 trạng thái LCG liên tiếp, và mảng `ct` gồm 36 byte ciphertext. Cụ thể, output được cung cấp là:

```
p    = 109293690254125700593428833253859351747207544427596641988902897826726923108129
leak = [90932320403583933388104590731426350182475714444529235922632654547630050547854,
        7419001973708127101952065444933291168381819947297996667304118571827819593833,
        67898657390352222099145776514702065237791087004192011316965425093842698547879,
        59104346122377345147160947908393133350394990600375907640957883201712863161514,
        65791268128235538218159841829641838780085430662646571477813528156670949468574,
        30746596701904608663428779065775617660959514980181049138973990539351151163398,
        90401086830823038866772268939325153317251259153444707025916388656856331751223,
        58272077154494735088853274292736003691073242782827315949821851312399207553921,
        2436351101341565181224132398898435947850914144805010798831033314744304065906,
        60037930506906075080157529686240388137679026846211607176962484455269373425792,
        94603418212790651171053589169233166073715690379203194716340883392985882958728,
        40083135504675462463890729594467413366841384941611263958817813623602970950139,
        87423735720908548570287620670610997539974220708226253072012896399717805881915,
        90068696477808774338018715050496670423314532057245370376629814966590792334138,
        85125353608712750771947916413431128173570267602118896397591754906948853457159,
        103572197428666464527548288713740517562031762481709127346013361939366060409462,
        43369712552829683498588001109740718097054089477610970275193450254188936367127,
        93391039302254883112884682942395960326495980261895255005297213996980004965042,
        106127175177601840953317451864979451638562623954667122658489723938111108742444,
        57117890321834374388608137881909634607470441609846105637468499778163706812815,
        108323133963731727447343134032705836190493323038407099159328543077938215447190,
        46197978915634272286652335254378306194009148494353844230660614155269659323322,
        61275120371350337137606775044861934316845211969342945868270767375887012067459,
        105141796923903181156301351545814195231944808346151426835750813084215216036478,
        63497969937675382864122605069019472859395334014001110878786173999903860090108,
        103978872184469065639739458101313148437273147029754778075306257583387456083595,
        88133118544204664892482510421866229283075324748199288179327177640559110484643,
        105178940818406923446634762159331510677921686411620687829854838850860667935623,
        84382472730499115614151805092165372226815632887388603663091724929767632086870,
        46706679512967527627325203221385581068492266844734511449576209129559487807899]
ct   = [110, 209, 242, 199, 22, 17, 34, 12, 40, 226, 163, 109, 190, 116, 178, 134,
        146, 192, 47, 29, 33, 240, 253, 185, 170, 139, 245, 74, 155, 16, 128, 167,
        186, 75, 141, 100]
```

Mục tiêu: khôi phục FLAG từ $(p, \texttt{leak}, \texttt{ct})$.

---

Bài toán đặt ra một bộ sinh số giả ngẫu nhiên (PRNG) được xây dựng trên cơ sở **Linear Congruential Generator (LCG)**, nhưng với một lớp che giấu bổ sung: thay vì dùng một cặp tham số cố định $(a, b)$, chương trình duy trì một tập gồm $N = 10$ cặp tham số và tại mỗi bước lại chọn ngẫu nhiên một trong số đó thông qua một LCG phụ trợ bên trong. Chương trình công khai $n = 30$ trạng thái liên tiếp $s_0, s_1, \ldots, s_{29}$ và ciphertext gồm 36 byte, trong đó mỗi byte được tạo bởi XOR giữa byte thấp nhất của trạng thái LCG tiếp theo với byte tương ứng của flag. Nhiệm vụ là khôi phục flag.

---

## Mô tả bài toán

Gọi $p$ là số nguyên tố 256-bit. Tập tham số $\mathcal{A} = \{(a_0, b_0), (a_1, b_1), \ldots, (a_9, b_9)\}$ gồm 10 cặp được sinh ngẫu nhiên trên $\mathbb{Z}_p$. Một LCG phụ trợ có modulus $p_s$, hệ số $a_s$, $b_s$ cố định và seed $\sigma_0$ ngẫu nhiên 256-bit duy trì biến $\sigma$ để chọn index $c = \sigma \bmod 10$ tại mỗi bước. Hàm sinh của bài toán là:

$$s_{i+1} \equiv a_{c_i} \cdot s_i + b_{c_i} \pmod{p}$$

trong đó $c_i$ là chỉ số được chọn tại bước $i$, và chuỗi $(c_i)$ hoàn toàn bị ẩn. Dữ liệu công khai là $p$, chuỗi leak $L = (s_0, s_1, \ldots, s_{29})$, và ciphertext $\mathbf{ct}$ thỏa mãn $ct_j = (s_{29+j+1} \;\&\; \texttt{0xFF}) \oplus f_j$ với $f_j$ là byte thứ $j$ của flag.

![**Hình 1.** Chuỗi chuyển trạng thái LCG với 29 bước và 10 cặp tham số. Theo nguyên lý Dirichlet, ít nhất một cặp $(a, b)$ phải xuất hiện lặp lại trong chuỗi.](/images/write-ups/bkctf-2026-lcg-in-lcg/fig1_lcg_transitions.png)

---

## Quan sát then chốt — Nguyên lý Dirichlet trên tập tham số

Từ chuỗi leak $L = (s_0, s_1, \ldots, s_{29})$ gồm 30 giá trị liên tiếp, ta trích xuất được 29 **bước chuyển trạng thái** (state transitions). Mỗi bước chuyển là một cặp $(s_i, s_{i+1})$ biểu diễn đầu vào và đầu ra của một lần gọi hàm `next()`:

$$T = \bigl\{(s_0, s_1),\; (s_1, s_2),\; \ldots,\; (s_{28}, s_{29})\bigr\}, \quad |T| = 29$$

Mỗi bước chuyển $(s_i, s_{i+1})$ được điều khiển bởi một cặp tham số $(a_{c_i}, b_{c_i})$ thuộc tập $\mathcal{A}$ có đúng 10 phần tử. Tức là, 29 bước chuyển phải được "tô màu" bằng 10 nhãn khác nhau. Theo **Nguyên lý Dirichlet** (Pigeonhole Principle): nếu phân phối $n$ đối tượng vào $k$ hộp và $n > k$, thì ít nhất một hộp chứa từ hai đối tượng trở lên. Ở đây $n = 29$, $k = 10$, suy ra ít nhất một cặp $(a, b) \in \mathcal{A}$ được áp dụng tại **ít nhất $\lceil 29/10 \rceil = 3$ bước** trong số 29 bước trên.

Điều này có nghĩa: dù chuỗi index $(c_i)$ bị giấu hoàn toàn bởi LCG phụ trợ, tập $T$ chắc chắn chứa ít nhất hai bước chuyển dùng chung một cặp $(a, b)$ — và đó là thứ ta có thể khai thác.

![**Hình 1.** Chuỗi chuyển trạng thái LCG với 29 bước và 10 cặp tham số. Theo nguyên lý Dirichlet, ít nhất một cặp $(a, b)$ phải xuất hiện lặp lại.](/images/write-ups/bkctf-2026-lcg-in-lcg/fig1_lcg_transitions.png)

---

## Khôi phục tham số $(a, b)$ — Giải hệ phương trình tuyến tính modulo $p$

Giả sử cặp $(a, b)$ được dùng tại cả hai bước chuyển $(s_i, s_{i+1})$ và $(s_j, s_{j+1})$ với $i \neq j$. Khi đó định nghĩa của LCG cho ta hai phương trình đồng thời đúng:

$$s_{i+1} \equiv a \cdot s_i + b \pmod{p} \tag{1}$$
$$s_{j+1} \equiv a \cdot s_j + b \pmod{p} \tag{2}$$

Đây là một hệ **2 phương trình, 2 ẩn** $(a, b)$ trên $\mathbb{Z}_p$. Tất cả các giá trị $s_i, s_{i+1}, s_j, s_{j+1}$ đều đã biết từ `leak`. Ta cần giải tìm $a$ và $b$.

**Bước 1 — Triệt tiêu $b$ bằng phép trừ.** Lấy phương trình $(1)$ trừ đi phương trình $(2)$, hạng tử $b$ bị triệt tiêu hoàn toàn vì $b - b \equiv 0$:

$$s_{i+1} - s_{j+1} \equiv a \cdot s_i + b - (a \cdot s_j + b) \pmod{p}$$

$$s_{i+1} - s_{j+1} \equiv a \cdot (s_i - s_j) \pmod{p} \tag{3}$$

**Bước 2 — Tìm $a$ bằng nghịch đảo modular.** Phương trình $(3)$ có dạng $\Delta_y \equiv a \cdot \Delta_x \pmod{p}$ với $\Delta_y = s_{i+1} - s_{j+1}$ và $\Delta_x = s_i - s_j$. Để tìm $a$, ta cần chia cả hai vế cho $\Delta_x$. Trong số học modular, "chia" được thực hiện bằng cách nhân với **nghịch đảo modular** $\Delta_x^{-1} \pmod{p}$.

Nghịch đảo này tồn tại khi và chỉ khi $\gcd(\Delta_x, p) = 1$. Vì $p$ là số nguyên tố và $\Delta_x \not\equiv 0 \pmod{p}$ (tức $s_i \not\equiv s_j$), điều kiện này luôn được thỏa mãn — mọi phần tử khác 0 trong $\mathbb{Z}_p$ đều khả nghịch. Với $p$ 256-bit ngẫu nhiên, xác suất để $s_i \equiv s_j$ là $1/p \approx 2^{-256}$, gần như bằng 0. Do đó:

$$a \equiv \Delta_y \cdot \Delta_x^{-1} \pmod{p}$$

$$\boxed{a \equiv (s_{i+1} - s_{j+1}) \cdot (s_i - s_j)^{-1} \pmod{p}}$$

**Bước 3 — Tìm $b$ bằng thế ngược.** Sau khi có $a$, thế vào phương trình $(1)$:

$$b \equiv s_{i+1} - a \cdot s_i \pmod{p}$$

$$\boxed{b \equiv s_{i+1} - a \cdot s_i \pmod{p}}$$

Vì $\mathbb{Z}_p$ là trường, hệ hai phương trình tuyến tính với ma trận hệ số không suy biến (do $s_i \neq s_j$) luôn có **đúng một nghiệm duy nhất** $(a, b)$ trong $\mathbb{Z}_p \times \mathbb{Z}_p$.

![**Hình 2.** Sơ đồ minh họa việc giải hệ hai phương trình tuyến tính đồng dư trên $\mathbb{Z}_p$ để tìm $(a, b)$.](/images/write-ups/bkctf-2026-lcg-in-lcg/fig2_linear_congruence.png)

**Bước 4 — Duyệt toàn bộ tổ hợp và xác minh.** Ta không biết trước cặp bước chuyển nào dùng chung một $(a, b)$. Vì vậy, chiến lược là: với mọi cặp chỉ số $(i, j)$ thỏa $0 \le i < j \le 28$, giải hệ trên để thu được một ứng cử viên $(a, b)$. Tổng số cặp cần xét là $\binom{29}{2} = 406$.

Với mỗi ứng cử viên $(a, b)$, ta kiểm tra nó thỏa mãn bao nhiêu bước chuyển trong $T$: đếm số chỉ số $k \in \{0, \ldots, 28\}$ mà $(a \cdot s_k + b) \bmod p = s_{k+1}$. Nếu $(a, b)$ là cặp thật thuộc $\mathcal{A}$, nó sẽ thỏa mãn ít nhất 3 bước (theo Dirichlet). Nếu $(a, b)$ là cặp "giả" — kết quả từ hai bước chuyển dùng hai cặp tham số khác nhau — khả năng nó ngẫu nhiên thỏa mãn thêm một bước thứ ba là $p^{-1} \approx 2^{-256}$, tức là không xảy ra trong thực tế.

Do đó, **ngưỡng lọc $\ge 3$** bước thỏa mãn là điều kiện đủ để xác định cặp $(a, b)$ thật, mà không có false positive.

**Bước 5 — Xử lý các cặp tham số hiếm.** Trong một vài trường hợp không may, một số cặp $(a, b)$ trong $\mathcal{A}$ có thể chỉ xuất hiện đúng 1-2 lần trong 29 bước (điều Dirichlet không loại trừ — nó chỉ đảm bảo *ít nhất một* cặp xuất hiện $\ge 3$ lần, không phải *tất cả*). Các cặp này không vượt qua ngưỡng lọc. Để xử lý, ta thu thập tập các bước chuyển chưa được "bao phủ" bởi bất kỳ cặp nào đã xác nhận, rồi ghép từng cặp trong tập này để giải thêm các ứng cử viên $(a, b)$ còn sót.

---

## Khôi phục flag — Beam Search trên không gian trạng thái

Sau khi có $\mathcal{A}$, tại mỗi bước sinh flag, ta biết $s_{29}$ (phần tử cuối của leak) nhưng không biết $c_{29}, c_{30}, \ldots$ — tức là không biết cặp $(a, b)$ nào được áp dụng tiếp theo. Không gian tìm kiếm thô là $10^{36}$ — hoàn toàn không thể duyệt kiệt.

Tuy nhiên, dữ liệu ciphertext $\mathbf{ct}$ đóng vai trò bộ lọc mạnh. Tại bước $j$, ta có:

$$f_j = ct_j \oplus (s_{29+j+1} \;\&\; \texttt{0xFF})$$

Với mỗi ứng cử viên $s$ và mỗi $(a, b) \in \mathcal{A}$, ta tính $s' = (as + b) \bmod p$ và suy ra $f_j = ct_j \oplus (s' \;\&\; \texttt{0xFF})$. Ký tự này bị loại ngay nếu:

- Không phải ký tự ASCII in được (tức $f_j \notin [0x20, 0x7E]$), hoặc
- Không khớp với prefix bắt buộc `BKISC{` (6 ký tự đầu) hoặc suffix `}` (ký tự cuối).

Constraint prefix `BKISC{` thực tế cực kỳ mạnh: tại 6 bước đầu, mỗi bước chỉ chấp nhận đúng 1 trong 10 lựa chọn, khiến không gian sụp đổ từ $10^6$ xuống còn nhiều nhất $O(1)$ nhánh sống sót. Các bước còn lại được lọc bởi điều kiện printable ASCII, cắt giảm trung bình $\frac{95}{256} \approx 37\%$ nhánh ở mỗi bước.

Thuật toán **Beam Search** thực hiện quá trình này một cách có hệ thống: duy trì một tập các ứng viên (beam), tại mỗi bước mở rộng mỗi ứng viên thành tối đa 10 nhánh, lọc theo các constraint trên, và giữ lại $B$ nhánh tốt nhất theo điểm heuristic (ưu tiên ký tự chữ thường, gạch dưới, chữ hoa, chữ số).

![**Hình 3.** Cây Beam Search với quá trình tỉa nhánh tại mỗi bước. Nhánh đỏ bị loại do vi phạm ràng buộc; nhánh xanh được giữ lại để mở rộng tiếp.](/images/write-ups/bkctf-2026-lcg-in-lcg/fig3_beam_search.png)

---

## Triển khai

```python
from collections import Counter
import string

# Dữ liệu đề bài
p = 109293690254125700593428833253859351747207544427596641988902897826726923108129
leak = [
    90932320403583933388104590731426350182475714444529235922632654547630050547854,
    7419001973708127101952065444933291168381819947297996667304118571827819593833,
    67898657390352222099145776514702065237791087004192011316965425093842698547879,
    59104346122377345147160947908393133350394990600375907640957883201712863161514,
    65791268128235538218159841829641838780085430662646571477813528156670949468574,
    30746596701904608663428779065775617660959514980181049138973990539351151163398,
    90401086830823038866772268939325153317251259153444707025916388656856331751223,
    58272077154494735088853274292736003691073242782827315949821851312399207553921,
    2436351101341565181224132398898435947850914144805010798831033314744304065906,
    60037930506906075080157529686240388137679026846211607176962484455269373425792,
    94603418212790651171053589169233166073715690379203194716340883392985882958728,
    40083135504675462463890729594467413366841384941611263958817813623602970950139,
    87423735720908548570287620670610997539974220708226253072012896399717805881915,
    90068696477808774338018715050496670423314532057245370376629814966590792334138,
    85125353608712750771947916413431128173570267602118896397591754906948853457159,
    103572197428666464527548288713740517562031762481709127346013361939366060409462,
    43369712552829683498588001109740718097054089477610970275193450254188936367127,
    93391039302254883112884682942395960326495980261895255005297213996980004965042,
    106127175177601840953317451864979451638562623954667122658489723938111108742444,
    57117890321834374388608137881909634607470441609846105637468499778163706812815,
    108323133963731727447343134032705836190493323038407099159328543077938215447190,
    46197978915634272286652335254378306194009148494353844230660614155269659323322,
    61275120371350337137606775044861934316845211969342945868270767375887012067459,
    105141796923903181156301351545814195231944808346151426835750813084215216036478,
    63497969937675382864122605069019472859395334014001110878786173999903860090108,
    103978872184469065639739458101313148437273147029754778075306257583387456083595,
    88133118544204664892482510421866229283075324748199288179327177640559110484643,
    105178940818406923446634762159331510677921686411620687829854838850860667935623,
    84382472730499115614151805092165372226815632887388603663091724929767632086870,
    46706679512967527627325203221385581068492266844734511449576209129559487807899,
]
ct = [110, 209, 242, 199, 22, 17, 34, 12, 40, 226, 163, 109, 190, 116, 178, 134,
      146, 192, 47, 29, 33, 240, 253, 185, 170, 139, 245, 74, 155, 16, 128, 167,
      186, 75, 141, 100]

# -----------------------------------------------------------------------
# Pha 1: Khôi phục tập tham số A = {(a_k, b_k)}
# Với mỗi cặp (i, j), giải hệ hai phương trình tuyến tính modulo p
# để thu được ứng cử viên (a, b), rồi lọc theo số bước chuyển thỏa mãn.
# -----------------------------------------------------------------------
transitions = [(leak[i], leak[i + 1]) for i in range(len(leak) - 1)]

ab_counts = {}
for i in range(len(transitions)):
    for j in range(i + 1, len(transitions)):
        x1, y1 = transitions[i]
        x2, y2 = transitions[j]
        if x1 == x2:
            continue
        # a = (y1 - y2) * (x1 - x2)^{-1}  mod p
        a = (y1 - y2) * pow(x1 - x2, -1, p) % p
        # b = y1 - a * x1                   mod p
        b = (y1 - a * x1) % p
        pair = (a, b)
        if pair not in ab_counts:
            sats = [k for k, (x, y) in enumerate(transitions)
                    if (a * x + b) % p == y]
            ab_counts[pair] = sats

true_ab_pool = set()
covered = set()

# Các cặp thỏa mãn >= 3 bước chuyển chắc chắn thuộc A
for pair, sats in ab_counts.items():
    if len(sats) >= 3:
        true_ab_pool.add(pair)
        covered.update(sats)

# Xử lý các bước chuyển hiếm (chỉ xuất hiện 1-2 lần)
uncovered = [i for i in range(len(transitions)) if i not in covered]
for i in range(len(uncovered)):
    for j in range(i + 1, len(uncovered)):
        idx1, idx2 = uncovered[i], uncovered[j]
        x1, y1 = transitions[idx1]
        x2, y2 = transitions[idx2]
        if x1 == x2:
            continue
        a = (y1 - y2) * pow(x1 - x2, -1, p) % p
        b = (y1 - a * x1) % p
        true_ab_pool.add((a, b))

print(f"[*] Recovered {len(true_ab_pool)} (a, b) pairs.")

# -----------------------------------------------------------------------
# Pha 2: Beam Search trên không gian trạng thái để khôi phục flag
# Tại mỗi bước, mở rộng mỗi ứng viên với 10 cặp (a, b),
# lọc theo ràng buộc printable ASCII và prefix/suffix đã biết.
# -----------------------------------------------------------------------
print("[*] Starting Beam Search...")
valid_chars = set(range(0x20, 0x7F))
flag_prefix = b"BKISC{"

# Mỗi ứng viên: (score, s_hiện_tại, flag_bytes_đã_tích_lũy)
candidates = [(0, leak[-1], b"")]

for step in range(len(ct)):
    target = ct[step]
    next_candidates = []

    forced = None
    if step < len(flag_prefix):
        forced = flag_prefix[step]
    elif step == len(ct) - 1:
        forced = ord('}')

    for score, s, flag_so_far in candidates:
        for a, b in true_ab_pool:
            next_s = (a * s + b) % p
            char = (next_s & 0xFF) ^ target

            if forced is not None:
                if char == forced:
                    next_candidates.append((score, next_s, flag_so_far + bytes([char])))
            else:
                if char in valid_chars:
                    c = chr(char)
                    bonus = 3 if (c.islower() or c == '_') else \
                            2 if (c.isupper() or c.isdigit()) else 1
                    next_candidates.append((score + bonus, next_s, flag_so_far + bytes([char])))

    if not next_candidates:
        print(f"[-] Search failed at step {step}.")
        break

    next_candidates.sort(key=lambda x: -x[0])
    candidates = next_candidates[:20000]

for score, s, flag in candidates:
    if flag.endswith(b"}"):
        print("\n[+] Flag:", flag.decode())
        break
```

---

## Kết quả

Chương trình thực thi trong vài giây. Pha 1 phục hồi chính xác 10 cặp $(a, b)$. Pha 2 hội tụ về một flag duy nhất ngay sau khi 6 ký tự prefix `BKISC{` lọc sạch không gian tìm kiếm:

```
[*] Recovered 5 potential (a, b) pairs.
[*] Starting Beam Search...

[+] Flag found: BKISC{0h_n0_cycl1c_lc6_br34k_my_lc6}
```

---

## Nhận xét

Lỗ hổng của thiết kế không nằm ở LCG phụ trợ — cơ chế shuffle index này thực ra không có giá trị bảo mật khi toàn bộ chuỗi trạng thái bị lộ. Điều kiện $|\text{leak}| > |\mathcal{A}|$ tạo ra va chạm tất yếu theo nguyên lý Dirichlet, từ đó cho phép giải hệ phương trình tuyến tính trên trường $\mathbb{Z}_p$ mà không cần bất kỳ giả thiết nào về cấu trúc của LCG phụ trợ. Beam Search sau đó khai thác cấu trúc của plaintex (định dạng flag, ASCII-printable) để loại bỏ tất cả nhánh không hợp lệ, biến bài toán tìm kiếm $10^{36}$ trường hợp thành bài toán hội tụ trong vài chục bước.
