+++
title = 'Ryan Guzling — Write-up'
date = '2026-08-31T21:28:38+07:00'
draft = false
tags = ['KasperskyCTF2026', 'forensics', 'FileVault', 'CoreStorage', 'Fusion Drive', 'HFS+', 'macOS']
categories = ['Forensics']
event = 'Kaspersky CTF 2026'
description = 'Khôi phục dữ liệu qua FileVault, Fusion Drive và CoreStorage historical metadata để tìm flag cuối.'
summary = 'Một forensic write-up về việc đi từ recovery key qua CoreStorage history, FileVault và HFS+ để lần ra flag.'
showToc = true
+++

# CTF Write-up: Ryan Guzling

**Category:** Forensics  
**Event:** Kaspersky CTF 2026  
**Points:** 182  
**Flag format:** `kaspersky{...}`  
**Flag cuối:** `kaspersky{1_th1nk_1t5_b3tt3r_t0_wr1t3_th3_k3y_0n_p4p3r}`

---

## Mô tả bài

> I can't decrypt my FileVault. There was a very important video that kept inspiring me to aim for the greater heights.  
> Sometimes, to move just a little bit forward, you have to apply an incredible, truly large effort.

File đính kèm là một ZIP rất lớn:

```text
https://storage.yandexcloud.net/kasperskyctf-2026/guz_5d74556b5147018c.zip
```

Bên trong có ba image:

```text
ssd.dd
hdd.dd
trash.dd
```

![Challenge Ryan Guzling](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/challenge_ryan_guzling.png)

Ngay từ tên bài và mô tả, mình chỉ biết đây là FileVault. Không có password, không có offset, không có tên file video. Câu “apply an incredible, truly large effort” lúc đầu trông giống một hint văn chương. Về sau nó lại mô tả khá đúng cái mình phải làm: chỉ để đọc được một file 29 byte, mình phải đi qua Fusion Drive, CoreStorage historical metadata, FileVault, HFS+, một sparsebundle AES-256 khác, GPT và thêm một HFS+ nữa.

Sơ đồ dưới đây là chuỗi cuối cùng sau khi mình đã giải xong. Khi bắt đầu mình không hề biết nó dài như vậy.

![Tổng quan đề bài và đường điều tra](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/overview_approach.png)

---

## Nhận file và kiểm tra nhanh

Mình không extract hết ZIP trên máy cá nhân ngay. Raw size của hai disk chính đã hơn 33 GiB, cộng thêm `trash.dd`, file tạm, các bản cắt partition và output parser thì không gian thực tế cần lớn hơn khá nhiều. Máy cá nhân lúc đó không phù hợp để ngồi copy qua copy lại hàng chục GiB, nên mình chuyển sang Google Colab để có storage tạm và chạy Python/parser trực tiếp.

Sau này, khi runtime Colab bị reset, mình còn dùng HTTP Range + central directory của ZIP để chỉ extract `ssd.dd` thay vì tải lại cả archive. Server trả `206 Partial Content`, ZIP cho thấy:

```text
'hdd.dd'   compressed=635,266,258    uncompressed=19,327,352,832
'ssd.dd'   compressed=11,048,339,952 uncompressed=16,106,127,360
'trash.dd' compressed=763,523        uncompressed=536,870,912
```

Điểm này quan trọng vì cuối bài address map mới nhất chứng minh toàn bộ logical data mình cần đều map vào PV0, tức SSD. Mình không phải tải lại HDD sau khi Colab mất session.

Partition triage cho thấy cả SSD và HDD đều có một CoreStorage partition bắt đầu ở LBA `409640`:

```text
409640 * 512 = 209735680 bytes
```

Một vài giá trị mình giữ lại từ đầu:

| Disk | Vùng | Start LBA | Ghi chú |
|---|---:|---:|---|
| `ssd.dd` | EFI | 40 | ESP |
| `ssd.dd` | CoreStorage | 409640 | PV0 |
| `hdd.dd` | CoreStorage | 409640 | PV1 |
| `hdd.dd` | Recovery HD | 36479160 | có BaseSystem |
| `trash.dd` | HFS-like evidence | - | chứa recovery artifact |

CoreStorage partition type GUID là:

```text
53746F72-6167-11AA-AA11-00306543ECAC
```

Lúc recon mình mới chỉ thấy hai CoreStorage physical volume. Sau khi đi hết chuỗi metadata và mapping, mình dựng lại được kiến trúc ổ đĩa của challenge như sau:

![Kiến trúc Fusion Drive, CoreStorage và FileVault dựng lại từ evidence](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/macos_fusion_architecture.png)

---

### Sai lầm 1: tìm `.bash_history` quá sớm

Một giả thuyết mình thử rất sớm là shell history có thể giữ lại thao tác của người dùng với file bị giấu. Vì vậy mình đi tìm `.bash_history` ngay trong `trash.dd`, Recovery HD, `.fseventsd`, `strings`, `fls`, `icat` và các vùng có thể đọc được mà chưa cần FileVault.

```text
$ strings -a trash.dd | grep -i bash_history
# không có kết quả hữu ích

$ fls -r ... | grep -i bash
# không có .bash_history của user
```

Mình còn raw-grep SSD/HDD cho `bash_history`. Tất nhiên không thấy gì.

### Khoảnh khắc nhận ra

> `.bash_history` là user artifact của macOS chính. Nếu FileVault đang che logical volume thì tên file và nội dung của nó cũng nằm trong ciphertext. Raw grep không thất bại vì file bị xóa; nó thất bại vì mình đang tìm plaintext ở sai layer.

Từ đây mình tạm bỏ filesystem user data và quay xuống lớp thấp hơn: lấy key trước.

---

### Sai lầm 2: bám vào `flag_picker.efires` và chuỗi `dd 9`

Trong Recovery HD có một file `flag_picker.efires`. `strings` cho vài chuỗi lạ, trong đó có `ZucTF` và `dd 9`. Cụm `dd 9` rất dễ kéo tư duy sang một lệnh kiểu:

```text
dd if=... of=... seek=9
```

hoặc một offset liên quan số 9. Mình đã thử đọc context, binwalk, carve và tìm các pattern `seek=`, `skip=`, `.mp4`, `.mov` ở quanh những vùng unencrypted.

```text
# Sai
strings -a flag_picker.efires | grep -E 'dd|seek|skip|mp4|mov'
```

Không có cấu trúc nào nối `dd 9` với user volume. Đến tận cuối, `.bash_history` thật cũng không có một lệnh `dd` nào.

### Khoảnh khắc nhận ra

> Một string “trông giống clue” không đủ. Từ đây mình chỉ giữ một giả thuyết nếu nó nối được với một cấu trúc disk, một pointer, một B-tree edge, một crypto invariant hoặc một filesystem record.

---

### Sai lầm 3: nghĩ tới carve video trước khi có plaintext

Challenge nhắc thẳng đến “video”, nên carve MP4/MOV là phản xạ hợp lý. Tuy nhiên nếu video nằm trong FileVault thì `ftyp`, `moov`, `mdat` đều đã thành ciphertext. Carve signature ở raw disk lúc này không khác gì tìm một chuỗi ngẫu nhiên trong dữ liệu mã hóa.

```text
# Sai thời điểm
foremost -t mp4 ...
binwalk ...
grep -aob 'ftyp' ssd.dd
```

Mình dừng hẳn nhánh này. Nếu cuối cùng cần carve, phải có exact logical/physical region trước.

![Những ngõ cụt chính trong quá trình điều tra](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/wrong_turns_small.png)

---

## Recovery key xuất hiện trong `trash.dd`

Triage `trash.dd` cuối cùng cho thứ thật sự hữu ích: một recovery password đúng format FileVault:

```text
XTA5-XPK2-9LV4-F6ON-WARR-4LYV
```

Ở đây có một chi tiết nhỏ nhưng nguy hiểm: nhóm `F6ON` là chữ `O`, không phải số `0`. Mình giữ nguyên ASCII chính xác thay vì chuẩn hóa bằng mắt.

Recovery user UUID mình trích được từ plist là:

```text
EEBD2AE6-30BA-4D32-AF99-EADA39B83AB5
```

KEK identifier:

```text
63C307E0-11A9-4432-9F81-D2278BF2CC6A
```

Tới đây mình có password, nhưng chưa biết phải biến nó thành VMK như thế nào. Thay vì đoán KDF, mình đi đọc source.

---

## Mình dừng notebook để đọc libfvde thay vì đoán KDF

Đây là lần đầu trong bài mình phải rời challenge data và đi đọc tài liệu/source khá lâu.

Mình mở các nguồn sau ngay ở đoạn này:

- `libyal/libfvde` README: <https://github.com/libyal/libfvde/blob/main/README>
- FileVault Drive Encryption format notes: <https://github.com/libyal/libfvde/blob/main/documentation/FileVault%20Drive%20Encryption%20%28FVDE%29.asciidoc>
- source `libfvde_password.c`
- source `libfvde_encrypted_metadata.c`
- paper *Infiltrate the Vault: Security Analysis and Decryption of Lion Full Disk Encryption*: <https://eprint.iacr.org/2012/374.pdf>
- RFC 3394 AES Key Wrap: <https://www.rfc-editor.org/info/rfc3394/>

README cho mình hai thông tin cực lớn. Một là libfvde đúng là library để đọc CoreStorage/FileVault 2. Hai là danh sách unsupported features có dòng:

```text
Unsupported Core Storage format features:
* multiple physical volumes
```

Dòng này về sau giải thích tại sao mình có key đúng mà tool vẫn không mount được Fusion Drive.

Trong `libfvde_encrypted_metadata.c`, mình lần theo `PassphraseWrappedKEKStruct`, wrapped KEK, wrapped volume key và đoạn kiểm tra 8 byte IV/integrity trước khi copy 16-byte VMK. `libfvde_password.c` cho đúng PBKDF routine. Đây là lúc mình bỏ hoàn toàn password guessing.

Paper của Choudary, Gröbert và Metz giúp mình đặt tên đúng các lớp: recovery/passphrase -> intermediate KEK -> VMK -> AES-XTS data encryption. Mình không lấy “magic value” từ paper rồi áp vào challenge; mình dùng paper để hiểu architecture, còn field/offset/iteration cụ thể vẫn lấy từ challenge + libfvde source.

![Luồng Recovery Key tới VMK](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/recovery_to_vmk.png)

PoC tối thiểu của nhánh recovery key có dạng:

```python
import hashlib
from cryptography.hazmat.primitives.keywrap import aes_key_unwrap

recovery = b"XTA5-XPK2-9LV4-F6ON-WARR-4LYV"

# salt, iterations, wrapped_kek, wrapped_vmk được parse từ plist/metadata
pbkdf_key = hashlib.pbkdf2_hmac(
    "sha256",
    recovery,
    salt,
    iterations,
    dklen=16,
)

kek = aes_key_unwrap(pbkdf_key, wrapped_kek)
vmk = aes_key_unwrap(kek, wrapped_vmk)
```

Giá trị cuối cùng:

| Stage | Value |
|---|---|
| PBKDF-derived key | `bc11e1b22dbef62562fd7a04c4a04470` |
| KEK | `50eb56d7abffc91878cecf8404bffa22` |
| VMK | `212582ed5da5d8cf5579a3a23a0a23a4` |

RFC 3394 cho mình một invariant rất mạnh: AES Key Wrap dùng integrity value `A6A6A6A6A6A6A6A6`. Unwrap pass nghĩa là mình không còn ở trạng thái “key có vẻ hợp lý”. Nó đã qua integrity check của chính format.

---

## Có VMK nhưng vẫn không mount được Fusion Drive

Đây là đoạn mình mất nhiều thời gian nhất ở nửa đầu bài.

Mình thử `fvdeinfo`, `fvdemount`, partition offset wrapper, cắt partition, FUSE offset layer và nhiều invocation khác. Có lúc lỗi đọc metadata ở offset lớn:

```text
unable to read metadata block data at offset: 15753760768 (0x3aaff5000)
```

Sau đó mình phát hiện bản SSD lúc đó bị truncated. Mình extract lại SSD đầy đủ 16,106,127,360 byte. Tuy nhiên ngay cả khi image đã đủ và VMK đúng, libfvde vẫn không cho mình một logical HFS+ usable.

### Sai lầm 4: nghĩ “tool không mount” đồng nghĩa “key sai”

Mình đã quay lại kiểm tra password/KDF nhiều lần dù RFC 3394 unwrap đã pass. Đây là thời gian lãng phí.

### Khoảnh khắc nhận ra

> README libfvde đã nói thẳng `multiple physical volumes` unsupported. Bài này là Fusion Drive hai PV. Key chain đã được chứng minh; thứ thiếu không còn là crypto key mà là logical-to-physical mapping của CoreStorage.

Mình cũng thử UFS Explorer vì nó nhận diện tốt storage stack kiểu Apple, nhưng bản dùng được cho tình huống này bị giới hạn bởi license. Mình không muốn lời giải phụ thuộc một commercial tool, nên nhánh đó dừng ở đây.

![UFS Explorer bị giới hạn license](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/ufs_explorer_license.png)

Từ đây kiến trúc bài đổi hẳn. Mình không còn “tìm cách mount FileVault” nữa. Mình bắt đầu tự dựng reader.

---

## Giải mã CoreStorage metadata trước khi đụng user data

Mình quay lại source libfvde để xem PV header và encrypted metadata. Đây là lúc mình đọc kỹ:

- `libfvde_metadata.c`
- `libfvde_metadata_block.c`
- `libfvde_encrypted_metadata.c`
- `libfvde_segment_descriptor.h`
- FileVault format documentation của libfvde
- NIST SP 800-38E để đối chiếu cách XTS hoạt động trên storage: <https://csrc.nist.gov/pubs/sp/800/38/e/final>

PV0 và PV1 có cùng LVG UUID nhưng key/UUID riêng:

| Field | PV0 / SSD | PV1 / HDD |
|---|---|---|
| serial | `0x021c0000` | `0x021c0000` |
| `key_data` | `e99749fe29e05f3b5ac4fc5709ec1e24` | `5938c35555b19bc11d6a38c30712c98f` |
| PV UUID | `caac2a72e9fe4ec68923698738d40f6b` | `89837067a08147c79d47de5db0ef13b7` |
| LVG UUID | `3186f1c4ed4d4d74b9ee36ebf630e52a` | giống PV0 |
| metadata copies | `1,1025,3846133,3847157` | `1,1025,4506641,4507665` |

Metadata working area bắt đầu ở physical block 2049, mỗi physical block 4096 byte, tổng 6144 blocks = 24 MiB. Một metadata logical block mình xử lý là 8192 byte.

Formula mình kiểm chứng được:

```python
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
import struct

def decrypt_cs_metadata(ct8192, laddr, key_data, pv_uuid):
    xts_key = key_data + pv_uuid       # 16 + 16 bytes
    tweak = struct.pack("<Q", laddr) + b"\x00" * 8
    dec = Cipher(algorithms.AES(xts_key), modes.XTS(tweak)).decryptor()
    return dec.update(ct8192) + dec.finalize()
```

Control case mạnh nhất là metadata laddr `35`. Cả SSD và HDD đều decrypt ra cùng plaintext có trạng thái `LVFwiped`, dù ciphertext khác nhau vì mỗi PV dùng metadata key riêng.

Đây là lần đầu mình có một primitive đáng tin để đọc CoreStorage metadata mà không phụ thuộc libfvde mount.

---

## Current metadata nói rằng logical volume đã bị wipe

Parser current state cho 57 metadata blocks, block number `0..56`, transaction `2..9`. Các loại mình dần map được gồm:

```text
0x0011  disk label
0x0012  disk-label continuation
0x0016  VAT
0x0019  LVF / LVFwiped
0x001a  LV header
0x0205  LV directory
0x0305  mapping-related object in current state
0x0405  physical/reserved extent tables
```

Current VAT cho:

```text
VAT[14] -> laddr 35 -> type 0x0019 -> LVFwiped
```

Current mapping còn ba extent owner 14:

| Logical start (4 KiB block) | PV | Physical block | Length |
|---:|---:|---:|---:|
| 0 | 0 | 8224 | 512 |
| 4,165,600 | 0 | 8736 | 32 |
| 8,330,720 | 0 | 8768 | 512 |

---

### Sai lầm 5: coi ba extent owner 14 là full logical volume

Ba extent này trông rất hấp dẫn vì có logical offset, physical block và length rõ ràng. Mình đã thử xem chúng như “segment map”. Nhưng tổng chỉ 1056 blocks và để lại hai gap hơn bốn triệu block.

```text
logical 0          -> paddr 8224   len 512
logical 4165600    -> paddr 8736   len 32
logical 8330720    -> paddr 8768   len 512
```

Nếu đây là full filesystem map thì một HFS+ volume chứa hàng trăm nghìn file lại gần như toàn hole. Không hợp lý.

### Khoảnh khắc nhận ra

> `0x0405` ở đây là các vùng pinned/special/reserved, không phải dynamic address map của Fusion Drive. Mình phải tìm historical state trước khi `LVFwiped` xảy ra.

---

## Mình chỉ quét đúng 24 MiB metadata ring và tìm state lịch sử

Mình không scan 15 GiB SSD hay 18 GiB HDD. Mình quét đúng vùng CoreStorage metadata đã biết, dùng AES-XTS formula ở trên, rồi chỉ nhận block nếu header, transaction, type, object và block number hợp lệ.

Kết quả bất ngờ:

```text
SSD strict structural blocks: 1537
HDD strict structural blocks: 1537
weak-only: 0
```

Plaintext set của hai PV giống nhau. CoreStorage đã giữ lại rất nhiều transaction stale trong metadata area.

Hai LVF đặc biệt:

```text
slot 1482 tx1348 type0019 obj14 -> unwiped
slot 1952 tx1343 type0019 obj14 -> unwiped
```

Còn nhiều transaction khác vẫn là `LVFwiped`.

PoC scanner lúc này không cố “đoán ý nghĩa mọi byte”; nó chỉ dùng structural filter:

```python
for laddr in range(metadata_slot_count):
    ct = read_exact_metadata_ciphertext(laddr)
    pt = decrypt_cs_metadata(ct, laddr, pv_key_data, pv_uuid)

    if valid_common_header(pt) and sane_transaction(pt) and sane_block_number(pt):
        keep(pt)
```

Đây là pivot quan trọng nhất của bài. Current state không dùng được, nhưng forensic metadata history vẫn đủ để dựng state trước wipe.

---

## VAT làm mình phải reverse Apple binary

Historical LVF trỏ đến các virtual address. Libfvde source không đủ để xử lý Fusion multi-PV path, nên mình cần xem Apple implementation thật.

Mình lấy `BaseSystem.dmg` từ Recovery HD rồi trích:

```text
libCoreStorage.dylib
CoreStorage.kext
CoreStorageFsck
```

`libCoreStorage.dylib` mình dùng có:

```text
size   748720
sha256 30862e42d60e817d97068c904717179874c311316fcc31b28ac03a052050dafa
```

Từ đây, “tài liệu” của mình không còn chỉ là webpage. Chính binary Apple là source of truth. Mình tìm symbol, disassemble và lần xref quanh:

```text
vaddr_to_laddr(lvg*, ...)
load_lfs_from_seg(lvg*, recovery_info const&)
mlv_vat_dev_strategy_core(...)
mlv_blockmap(...)
init_disk_label(...)
write_disk_label(...)
```

Kết quả VAT on-disk:

```text
type 0x0016

+0x40 uint32 entry_count
+0x44 vat_ent[entry_count]

vat_ent = 12 bytes
    +0x00 uint32 laddr_low32
    +0x04 uint32 laddr_high31_and_flag
    +0x08 uint32 refcount_or_valid

laddr = low32 | ((high32 & 0x7fffffff) << 32)
vaddr = array index
```

Current `VAT[14] -> 35` là control đẹp vì nó quay đúng về `LVFwiped` block mình đã decrypt.

Historical coherent chains cho address-map root luôn có `vaddr = 12`, nhưng `laddr` thay đổi theo snapshot:

```text
72, 224, 322, 870, 1485, 1922, 2424, 2838
```

Ví dụ:

```text
tx1449 -> VAT[12] = 72
tx1575 -> VAT[12] = 322
```

---

### Sai lầm 6: lấy VAT laddr làm metadata slot trực tiếp

Với `laddr=35`, đọc metadata slot 35 đúng. Mình vô thức tổng quát hóa điều này cho historical laddr 72, 224, 322, 1922... và đi tìm chúng như direct slots. Có block không tồn tại ở chỗ mình kỳ vọng, nên mình từng kết luận mapping root “missing”.

```text
# Sai mô hình
vaddr -> VAT[vaddr] -> metadata_slot
```

### Khoảnh khắc nhận ra

> VAT trả về MLV logical address, không phải direct physical metadata slot. Giữa VAT và disk còn một lớp `mlv_blockmap()`.

![CoreStorage translation: historical metadata → VAT → MLV → address map](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/corestorage_translation_small.png)

---

## Reverse `mlv_blockmap()` và `dk_disk_label`

Mình tiếp tục đọc disassembly `mlv_vat_dev_strategy_core()` và `mlv_blockmap()`. Cả hai lấy mapping qua `lvg + 0xb0`.

Sau đó mình lần mọi xref của `+0xb0`. Các hàm `init_disk_label`, `write_disk_label`, `labels_are_compatible`, `cksum_disk_label_var_part` cho thấy `lvg+0xb0` là `dk_disk_label*`.

Historical type `0x0011` có geometry ổn định:

| Offset | Value | Mình dùng nó như thế nào |
|---:|---:|---|
| `+0xa8` | 12 | physical block shift = 4096 |
| `+0xac` | 13 | MLV logical shift = 8192 |
| `+0xb4` | 48 | mapping record size |
| `+0xb8` | 1 | record count |
| `+0xdc` | 8192 | table offset |
| `+0xe0` | 8240 | table kéo sang 48 byte continuation |

Đúng lúc đó type `0x0012` mà trước giờ mình chưa giải thích được lại chứa đúng 48 byte continuation:

```text
000000000000000018000000000000000000000000000000020000000000000001080000000000000108000000000100
```

Decode theo layout của `mlv_blockmap()`:

```text
logical start  = 0
logical length = 6144 MLV blocks
copies         = 2
PV0 base       = physical block 2049
PV1 base       = physical block 2049
```

Vì MLV block là 8192 byte còn physical block là 4096 byte:

```text
paddr_4k = 2049 + 2 * mlv_laddr
```

Mình kiểm chứng công thức bằng chính `laddr=35`:

```text
2049 + 2*35 = 2119
absolute = 209735680 + 2119*4096 = 218415104
```

Đọc 8192 byte ở đó và metadata-decrypt ra `LVFwiped` chính xác. Lúc này bridge VAT -> MLV -> physical disk được đóng bằng một control độc lập.

Tám historical roots sau đó đều đọc được trực tiếp:

| MLV laddr | physical block | absolute byte | decrypted node |
|---:|---:|---:|---|
| 72 | 2193 | 218718208 | `0x0303`, tx1449 |
| 224 | 2497 | 219963392 | `0x0303` |
| 322 | 2693 | 220766208 | `0x0303` |
| 870 | 3789 | 225255424 | `0x0303` |
| 1485 | 5019 | 230293504 | `0x0303` |
| 1922 | 5893 | 233873408 | `0x0303` |
| 2424 | 6897 | 237985792 | `0x0303` |
| 2838 | 7725 | 241377280 | `0x0303` |

Ở đoạn reverse này, mình không tìm thấy một specification công khai đủ sâu cho MLV/VAT/dk_disk_label. Kiến thức đến từ ba nơi ghép lại: libfvde cho vocabulary và metadata basics, Apple binary cho runtime behavior, challenge bytes cho validation.

---

## Address-map B-tree xuất hiện, nhưng scanner của mình lại bỏ sót leaf

Root `0x0303` tx1449 có 16 separator records. Mỗi record gồm key 16 byte + child vaddr 8 byte. Các child decrypt ra type `0x0304`.

Scanner ban đầu chỉ coi `0x0305` là mapping-related leaf, nên `0x0304` bị đánh “unknown”. Đây là một lỗi do assumption trong code của mình, không phải do disk.

### Sai lầm 7: type chưa biết thì loại

Mình sửa cách kiểm chứng: không hỏi “type này có nằm trong list mình biết không?”, mà hỏi “nó có cư xử đúng như leaf B-tree không?”.

Mỗi child được kiểm:

```text
version == 1
obj == child_vaddr
number == VAT laddr
record_count <= capacity
first_key == parent separator
keys sorted
all keys inside [lower_separator, upper_separator)
physical extents sane
```

Kết quả:

```text
root children     : 16
valid 0x0304 leaf : 16
invalid           : 0
```

### Khoảnh khắc nhận ra

> `0x0304` chính là leaf variant của address-map tree. Scanner sai, disk không sai.

![Address-map B-tree 0x0303/0x0304](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/address_map_btree_small.png)

Reverse comparator và `lv_key` cho record 40 byte:

```text
key 16 bytes:
    q0 = objid/type bits
    q1 = logical address

value 24 bytes:
    v0, v1, v2

nblks       = v0 & ((1<<48)-1)
encrypt_ctx = (v0 >> 54) & 0x3f
timestamp   = v1
pv          = (v2 >> 48) & 0x7fff
paddr       = v2 & ((1<<48)-1)
```

Full tx1449 map:

```text
leaf nodes       16
leaf records     2081
logical range    0 .. 8205312
PV               {0: 2081}
encrypt_ctx      {1: 2081}
logical gaps     254
```

Các gap là sparse holes thật. Reverse I/O path cho thấy hole branch trả zero, nên mình không đi tìm một “second mapper” nữa.

---

## FileVault data decrypt cuối cùng mới bắt đầu

Tới đây mình có VMK và full logical->physical address map. Bây giờ crypto của FileVault mới thật sự có đủ context.

Mình quay lại libfvde FVDE documentation và NIST XTS để kiểm tra sector tweak. `libfvde` ghi rõ tweak là sector number dưới dạng 128-bit little-endian, data unit thường 512 byte. Nhưng challenge còn một family-derived tweak key.

Công thức mình chứng minh được:

```python
import hashlib, struct
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

VMK = bytes.fromhex("212582ed5da5d8cf5579a3a23a0a23a4")
family = bytes.fromhex("f00135c9a9314de8a2cb6f982d2cf40c")

tweak_key = hashlib.sha256(VMK + family).digest()[:16]
# 29331015d021a84988acce8cb7878fa6

xts_key = VMK + tweak_key

def decrypt_logical_sector(sector_no, ct512):
    tweak = struct.pack("<Q", sector_no) + b"\x00" * 8
    d = Cipher(algorithms.AES(xts_key), modes.XTS(tweak)).decryptor()
    return d.update(ct512) + d.finalize()
```

Mình không decrypt hàng GiB để “xem có đúng không”. Map record đầu nói logical 4K block 0 -> PV0 physical block 9600. Mình đọc đúng block này, decrypt 8 sector 512 byte, rồi kiểm byte `1024`.

Nó trả:

```text
48 2b ...
'H+'
version 4
lastMountedVersion 'HFSJ'
blockSize 4096
```

Đây là HFS+ Volume Header hợp lệ. Crypto branch đóng.

![Đường đọc logical block qua FileVault tới HFS+ outer](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/filevault_outer_hfs.png)

---

## Mình mở Apple TN1150 ngay khi thấy `H+`

Tài liệu được dùng ở đây:

- Apple Technical Note TN1150, *HFS Plus Volume Format*: <https://developer.apple.com/library/archive/technotes/tn/tn1150.html>

TN1150 cho đúng các thứ mình cần ở low level:

```text
Volume Header nằm tại byte +1024
all multi-byte integers are big-endian
HFSPlusForkData có 8 embedded extents
Catalog File là B-tree
Catalog key = parentID + Unicode name
recordType 1 = folder
recordType 2 = file
recordType 3/4 = thread
```

Outer volume header:

| Field | Value |
|---|---:|
| signature | `H+` |
| version | 4 |
| block size | 4096 |
| total blocks | 8,205,312 |
| file count | 347,458 |
| folder count | 93,448 |
| last mounted | `HFSJ` |

Catalog fork:

```text
logical size 167772160
blocks       40960
extent       start 183809 count 40960
node size    8192
leaf records 881814
first leaf   19691
```

Mình viết reader on-demand: bisect logical block trong address-map CSV, đọc đúng physical 4K block của SSD, FileVault-decrypt 8 sector, sau đó ghép HFS+ fork. Không tạo một decrypted 33 GiB image.

Phần Catalog walk tối thiểu:

```python
node = read_catalog_node(first_leaf)
while node_number:
    desc = parse_node_descriptor(node)
    offsets = parse_record_offsets(node)

    for record in leaf_records(node, offsets):
        key = parse_catalog_key(record)
        if key.name == ".bash_history" and record.type == FILE_RECORD:
            save_file_fork(record)

    node_number = desc.fLink
```

Sau khoảng 20,074 leaf nodes và 881,814 records, mình tìm đúng một file:

```text
/Users/macsos/.bash_history
file ID      442033
parent ID    437898
catalog leaf 19977
record       27
size         2493
extent       start 3066715 count 1
sha256       7f767333fe6443589e6423d1a2be32418a0a62047d55ac39a9fe836f3c7f42a8
```

---

## `.bash_history` không có `dd`; nó kể một câu chuyện khác

Những dòng đáng giữ lại:

```bash
sudo hdiutil create -size 50m -type SPARSEBUNDLE -fs HFS+J -encryption AES-256 -volname hranilka ~/Desktop/hranilka.sparsebundle
hdiutil attach ~/Desktop/hranilka.sparsebundle/
sudo mv /usr/local/.secret.txt /Volumes/hranilka/
...
sudo hdiutil attach -owners on -readwrite ~/Documents/hranilka.sparsebundle/
cat /Volumes/hranilka/.secret.txt
sudo nano /Volumes/hranilka/.secret.txt
hdiutil detach /Volumes/hranilka/
...
cd /usr/local/
sudo nano .pass
cat .pass
```

Không có `dd`.

---

### Sai lầm 8: nghĩ snapshot mới hơn sẽ bổ sung lệnh `dd`

Mình vẫn chưa chịu bỏ giả thuyết cũ ngay. Historical VAT cho phép dựng một address map mới hơn, tx1575, nên mình nghĩ `.bash_history` ở tx1449 có thể chỉ là bản cũ.

Map tx1575 thật sự khác:

```text
tx1449 rows 2081
tx1575 rows 2127
unchanged   2004
added       123
removed     77
PV          {0: 2127}
```

Filesystem state có thay đổi. Nhưng khi đọc lại chính file ID 442033:

```text
old size 2493
new size 2493
old sha  7f767333fe6443589e6423d1a2be32418a0a62047d55ac39a9fe836f3c7f42a8
new sha  7f767333fe6443589e6423d1a2be32418a0a62047d55ac39a9fe836f3c7f42a8
identical True
exact dd commands 0
```

### Khoảnh khắc nhận ra

> Clue thật không phải `dd`. History đã nói rất rõ: `.pass` và `hranilka.sparsebundle`. Mình phải follow evidence literal, không ép history khớp giả thuyết cũ.

---

## `.pass` nằm plaintext ngay ngoài encrypted container

Mình walk outer Catalog thêm một lần, lần này chỉ tìm ba tên đã xuất hiện trong history:

```text
.pass
.secret.txt
hranilka.sparsebundle
```

Kết quả:

```text
/usr/local/.pass
CNID 449291
size 17
content: ILoveAzazinCreet\n
/Users/macsos/Documents/hranilka.sparsebundle
CNID 448984

.secret.txt trên outer filesystem: không còn
```

Chuỗi này khớp hoàn hảo với history: `.secret.txt` đã bị `mv` vào volume `hranilka`, còn password của container lại được lưu plaintext ở `/usr/local/.pass`.

Đây là “điểm yếu” quan trọng của challenge, nhưng không phải một CVE hay memory corruption bug. Nó là một **opsec/evidence-chain failure**: encryption mạnh nhưng key material và thao tác người dùng để lại dấu vết ngoài container.

---

## Mình đọc `hdiutil` docs trước khi ghép band

Ở đoạn này mình mở:

- `hdiutil(1)` man page: <https://keith.github.io/xcode-man-pages/hdiutil.1.html>

Man page xác nhận `SPARSEBUNDLE` là directory-backed image, grow theo band; các bản macOS hiện đại dùng 8 MiB band mặc định. Đây khớp chính xác `Info.plist` mình parse được:

```text
CFBundleInfoDictionaryVersion = 6.0
band-size = 8388608
bundle-backingstore-version = 1
diskimage-bundle-type = com.apple.diskimage.sparsebundle
size = 52428800
```

Inventory package:

| Path | Size |
|---|---:|
| `Info.plist` | 495 |
| `Info.bckup` | 495 |
| `token` | 122,368 |
| `bands/0` | 5,783,552 |
| `bands/3` | 1,081,344 |
| `bands/5` | 8,388,608 |
| `bands/6` | 2,097,152 |

Chỉ band có data được materialize. Virtual disk vẫn là 50 MiB; missing bands là sparse zero ranges.

![Đường giải mã hranilka.sparsebundle và HFS+ inner](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/sparsebundle_inner_path_small.png)

---

## `token` bắt đầu bằng `encrcdsa`, nên mình lại đi đọc implementation

Token 122,368 byte có header:

```text
magic              encrcdsa
version            2
cipher block bytes 16
data key bits      256
auth key bits      160
sector size        512
iterations         416666
salt len           20
wrapper IV len     8
wrapped len        64
```

Mình không đoán algorithm từ các field số. Mình mở:

- `nlitsme/encrypteddmg`: <https://github.com/nlitsme/encrypteddmg>
- source `readencrcdsa.py`: <https://github.com/nlitsme/encrypteddmg/blob/master/readencrcdsa.py>
- RFC 8018 / PBKDF2: <https://www.rfc-editor.org/info/rfc8018/>
- NIST SP 800-67 Rev.2 cho TDEA/3DES (tài liệu hiện đã withdrawn cho encryption mới, nhưng phù hợp để đọc legacy format): <https://csrc.nist.gov/pubs/sp/800/67/r2/final>
- RFC 2104 / HMAC: <https://www.rfc-editor.org/rfc/rfc2104>

`readencrcdsa.py` đặc biệt hữu ích vì nó mô tả v2 algorithm gần như đúng field mình đang có: PBKDF2 -> 3DES-CBC unwrap -> PKCS#7 -> `CKIE\0`, sau đó split AES key/HMAC key, và data sector IV từ HMAC-SHA1(block number).

Mình vẫn không tin source ngoài challenge một cách mù quáng. PoC phải pass structural invariant của token này.

```python
import hashlib
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

password = b"ILoveAzazinCreet"

wrapper_key = hashlib.pbkdf2_hmac(
    "sha1",
    password,
    salt,
    416666,
    dklen=24,
)

# 3DES-CBC, IV 8 bytes
D = Cipher(TripleDES(wrapper_key), modes.CBC(wrapper_iv)).decryptor()
padded = D.update(wrapped64) + D.finalize()

pad = padded[-1]
assert padded[-pad:] == bytes([pad]) * pad
clear = padded[:-pad]

assert len(clear) == 57
assert clear[-5:] == b"CKIE\x00"

aes_key  = clear[:32]
hmac_key = clear[32:52]
```

Kết quả:

```text
wrapper key:
dfb99623da86d0df1f2e8bd505b6bb88ec86462feb6877df

AES-256 key:
78f4795a629d4c2b06ce2e8b3cfd8fb607a3a0f319fcea2d71808c93f8c7e5af

HMAC-SHA1 key:
a77bc27dd7de254e3dcf18908192c8829ee50fd8

trailer:
CKIE\0
```

Password không còn là “candidate”. Nó cryptographically unwrap đúng token.

---

## Mình chỉ decrypt bốn sector để đóng công thức `encrcdsa`

Data algorithm từ implementation:

```python
import hmac, hashlib, struct

def decrypt_sparse_sector(sector_no, ct512):
    iv = hmac.new(
        hmac_key,
        struct.pack(">I", sector_no),
        hashlib.sha1,
    ).digest()[:16]

    d = Cipher(algorithms.AES(aes_key), modes.CBC(iv)).decryptor()
    return d.update(ct512) + d.finalize()
```

Mình decrypt sector 0..3 của virtual image, không decrypt cả 50 MiB.

Sector 0:

```text
... 55 aa
```

Sector 1:

```text
45 46 49 20 50 41 52 54
EFI PART
```

Sector 2 chứa partition entry có Apple HFS GUID. Công thức đúng.

Ở đây mình mở UEFI GPT spec:

- <https://uefi.org/specs/UEFI/2.10/05_GUID_Partition_Table_Format.html>

Spec cho `EFI PART` ở GPT header LBA1, partition entry array và little-endian GUID layout. Parse ra:

```text
GPT current LBA 1
backup LBA      102399
entries LBA     2
entry count     128
entry size      128

partition 0:
  type GUID  48465300-0000-11aa-aa11-00306543ecac
  first LBA  40
  last LBA   102359
  name       disk image
```

Apple_HFS partition bắt đầu LBA 40.

Theo TN1150, HFS+ Volume Header ở `partition_start + 1024 byte`, tức sector 42. Nó trả:

```text
signature   H+
version     4
block size  4096
totalBlocks 12790
fileCount   8
folderCount 3
```

Tới đây inner filesystem chỉ còn tám file. Mình không cần mount sparsebundle hay tạo decrypted image; on-demand sector reader là đủ.

---

## Inner HFS+ chỉ có tám file và `/.secret.txt` nằm ngay root

Catalog B-tree bên trong rất nhỏ:

```text
tree depth   1
root node    1
leaf records 24
first leaf   1
last leaf    1
node size    4096
```

Inventory:

```text
/.journal
/.journal_info_block
/.fseventsd/fseventsd-uuid
/.fseventsd/000000000003d529
/.fseventsd/000000000003d52a
/.fseventsd/000000000003e8a0
/.fseventsd/000000000003e8a1
/.secret.txt
```

`/.secret.txt`:

```text
CNID         22
size         29
data extent  start 332 count 1
sha256       4408bd32dd93fd4c7fc145319f955073ec030cd7cb1bd6556676d97ae5736981
```

Nội dung:

```text
https://youtu.be/461vxC3ZKMc
```

Đây là lần đầu mình có exact video ID từ disk evidence. Không carve. Không đoán title. Không brute-force offset.

---

## YouTube extractor bị age gate, nhưng browser đã cho flag

Mình thử `yt-dlp --skip-download` chỉ để lấy metadata video. YouTube trả:

```text
Sign in to confirm your age
```

Mình không cần bypass. Link đã được lấy hợp lệ từ `/.secret.txt`, và khi mở trong browser phần mô tả hiện thẳng flag.

![Flag trong phần mô tả YouTube](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/youtube_flag.png)

Chuỗi từ disk đến flag lúc này đã kín:

```text
trash.dd
  -> recovery key
  -> KEK
  -> VMK
  -> CoreStorage historical metadata
  -> VAT / MLV / address map
  -> outer FileVault HFS+
  -> .bash_history
  -> .pass + hranilka.sparsebundle
  -> encrcdsa token
  -> inner GPT / HFS+
  -> /.secret.txt
  -> YouTube
  -> flag
```

---

## Điểm yếu mình thật sự “khai thác” nằm ở đâu

Bài này không có một lỗ hổng kiểu buffer overflow, auth bypass hay RCE. Nếu gọi đây là “khai thác”, thứ mình khai thác là **dấu vết forensic + sai lầm quản lý bí mật**.

Chuỗi opsec failure:

```text
Recovery key còn trong trash evidence
        ↓
FileVault có thể unlock nếu tái dựng đúng CoreStorage
        ↓
.bash_history ghi lại chính thao tác tạo/mount encrypted sparsebundle
        ↓
Password của sparsebundle lại được lưu plaintext ở /usr/local/.pass
        ↓
.secret.txt chỉ được chuyển vào encrypted volume, không xóa mọi dấu vết về cách mở volume
```

AES-XTS và AES-256-CBC không “bị phá”. Mình lấy key qua artifacts và format-defined KDF/unwrap rồi đọc dữ liệu đúng cách.

PoC của bài vì vậy không phải exploit payload. PoC là tập các parser/decryptor nhỏ chứng minh từng bridge:

```text
recovery password -> PBKDF -> KEK -> VMK
VMK + CoreStorage address map -> HFS+ plaintext
.pass -> encrcdsa token -> AES/HMAC keys
AES/HMAC keys + bands -> inner HFS+ plaintext
```

---

## Sơ đồ reverse: phần nào có tài liệu, phần nào mình phải tự suy ra

![Những nhóm tài liệu được đọc trong quá trình giải](/images/write-ups/kaspersky-ctf-2026-ryan-guzling/research_sources_small.png)

Có hai loại kiến thức mình dùng.

Loại đầu có specification/source công khai tương đối rõ: PBKDF2, AES Key Wrap, XTS, HFS+, GPT, sparsebundle, encrcdsa v2.

Loại thứ hai là phần Fusion/CoreStorage historical mapping. Chỗ này public docs không đủ để giải case của bài. Mình phải reverse Apple `libCoreStorage.dylib`, sau đó dùng challenge bytes làm test vector.

Điều này quan trọng vì nếu chỉ đọc tài liệu rồi viết parser theo “cảm giác”, mình rất dễ nhầm unit 4K/8K, nhầm VAT laddr với physical slot hoặc dùng physical sector number làm FileVault XTS tweak.

---

## Tất cả tài liệu mình đã mở, và mình mở nó ở đoạn nào

Bảng này ghi theo đúng hành trình, không chỉ làm bibliography cuối bài.

| Khi mình đang mắc ở đâu | Tài liệu/source mình mở | Thứ mình lấy từ đó |
|---|---|---|
| Có recovery key nhưng chưa biết key chain | `libfvde_password.c`, `libfvde_encrypted_metadata.c` | PBKDF call, wrapped KEK/VMK flow, integrity check |
| Cần bức tranh FileVault 2 tổng thể | *Infiltrate the Vault* - Choudary, Gröbert, Metz | architecture recovery/passphrase -> KEK -> VMK -> XTS |
| AES unwrap cần một chuẩn độc lập để verify | RFC 3394 | AES Key Wrap + A6 integrity value |
| `fvdemount` không ghép được SSD+HDD | libfvde README | xác nhận `multiple physical volumes` unsupported |
| Cần hiểu FileVault sector tweak | libfvde FVDE documentation | sector-number tweak little-endian, 512-byte data units |
| Cần đối chiếu XTS như storage mode | NIST SP 800-38E | mô hình XTS-AES cho storage device |
| Cần hiểu CoreStorage current metadata parsers | libfvde source: metadata/segment descriptor files | type parsers, physical/logical descriptor fields |
| VAT/MLV vẫn thiếu | Apple `libCoreStorage.dylib` | `vaddr_to_laddr`, `load_lfs_from_seg`, `mlv_blockmap`, `dk_disk_label` |
| Cần cross-check binary environment | `CoreStorage.kext`, `CoreStorageFsck` | symbol/string context, implementation vocabulary |
| Có HFS+ signature | Apple TN1150 | VH +1024, big-endian structs, Catalog/Fork/B-tree/thread records |
| Có sparsebundle | `hdiutil(1)` | UDSB directory bundle, band behavior, encryption/create semantics |
| Token có magic `encrcdsa` | `nlitsme/encrypteddmg/readencrcdsa.py` | exact v2 PBKDF2/3DES/CKIE/AES/HMAC flow |
| Cần formal PBKDF reference | RFC 8018 | PBKDF2 semantics |
| Cần formal HMAC reference | RFC 2104 | HMAC construction; dùng cho sector IV generation |
| Cần formal TDEA reference | NIST SP 800-67 Rev.2 | legacy 3DES/TDEA definition used by wrapper |
| Sector 1 ra `EFI PART` | UEFI GPT 2.10 spec | GPT header/entry layout và GUID parsing |
| Muốn hiểu vì sao UFS Explorer có vẻ nhận được các format này | UFS Explorer release/docs | support sparsebundle/encrcdsa; nhưng license khiến mình không dùng làm lời giải |

Link đầy đủ:

- libfvde repository: <https://github.com/libyal/libfvde>
- libfvde README: <https://github.com/libyal/libfvde/blob/main/README>
- libfvde FVDE format notes: <https://github.com/libyal/libfvde/blob/main/documentation/FileVault%20Drive%20Encryption%20%28FVDE%29.asciidoc>
- FileVault 2 paper: <https://eprint.iacr.org/2012/374.pdf>
- Apple TN1150: <https://developer.apple.com/library/archive/technotes/tn/tn1150.html>
- RFC 3394: <https://www.rfc-editor.org/info/rfc3394/>
- RFC 8018: <https://www.rfc-editor.org/info/rfc8018/>
- RFC 2104: <https://www.rfc-editor.org/rfc/rfc2104>
- NIST SP 800-38E: <https://csrc.nist.gov/pubs/sp/800/38/e/final>
- NIST SP 800-67 Rev.2: <https://csrc.nist.gov/pubs/sp/800/67/r2/final>
- UEFI GPT: <https://uefi.org/specs/UEFI/2.10/05_GUID_Partition_Table_Format.html>
- `hdiutil(1)`: <https://keith.github.io/xcode-man-pages/hdiutil.1.html>
- `encrypteddmg`: <https://github.com/nlitsme/encrypteddmg>
- `readencrcdsa.py`: <https://github.com/nlitsme/encrypteddmg/blob/master/readencrcdsa.py>
- libfvde ChangeLog: <https://github.com/libyal/libfvde/blob/main/ChangeLog>

Mình cũng đọc source trực tiếp của bản `libfvde-20240502` trong Colab, nên một số đoạn investigation không dựa vào webpage mà dựa vào file local như:

```text
/tmp/libfvde-20240502/libfvde/libfvde_password.c
/tmp/libfvde-20240502/libfvde/libfvde_encrypted_metadata.c
/tmp/libfvde-20240502/libfvde/libfvde_metadata.c
/tmp/libfvde-20240502/libfvde/libfvde_logical_volume.c
/tmp/libfvde-20240502/libfvde/libfvde_segment_descriptor.h
```

Với CoreStorage proprietary internals, mình đọc disassembly của:

```text
libCoreStorage.dylib
CoreStorage.kext
CoreStorageFsck
```

Các symbol quan trọng mình đã lần:

```text
vaddr_to_laddr
load_lfs_from_seg
load_gps
mlv_vat_dev_strategy_core
mlv_blockmap
init_disk_label
write_disk_label
bt_lookup<lv_key>
CoreStorageGroup::translateExtent
```


---

## Lúc reverse current CoreStorage, mình đã đọc từng object như thế nào

Trước khi historical metadata mở ra, mình đã tốn khá nhiều thời gian với current object graph. Phần này đáng ghi lại vì nó giải thích vì sao mình không thể “nhảy” thẳng tới address map đúng.

Instrumentation libfvde cho current metadata inventory 57 blocks:

```text
00 tx2  type0013 obj0
01 tx2  type0018 obj1
02 tx2  type0105 obj2
03 tx2  type001c obj3
04 tx2  type0022 obj4
05 tx2  type001d obj5
06 tx2  type001d obj6
07 tx2  type0405 obj7
...
31 tx6  type0018 obj1
32 tx6  type0105 obj2
33 tx6  type0305 obj12
34 tx6  type0021 obj13
35 tx6  type0019 obj14  LVFwiped
36 tx6  type001a obj15
37 tx6  type0205 obj16
38 tx6  type0605 obj17
39 tx6  type0016 obj0   VAT
...
56 tx9  type0305 obj12
```

Ban đầu mình nghĩ chỉ cần hiểu `0x0305` là đủ. Nhưng current `0x0305` chỉ mô tả một state sparse/wiped, còn full filesystem mapping đã biến mất khỏi current view.

Mình patch debug output của libfvde ở các parser `0x0405`, `0x0021`, `0x0022`, `0x0018` để xem raw physical/logical values. Mục tiêu không phải sửa libfvde thành một tool mới ngay; mình dùng nó như một microscope cho các struct mà source đã có parser.

Ví dụ `0x0405` trả các owner class âm `-3`, `-4`, `-5` và owner `14`. Mình chưa gán tên cho owner âm, vì source không chứng minh tên. Mình chỉ thống kê geometry:

```text
PV0 owner -5: metadata copies around block 1, 1025, 3846133, 3847157
PV0 owner -3: block 2049, length 6144
PV0 owner 14: block 8224..9280, three logical extents

PV1 owner -5: tương tự trên HDD
PV1 owner -3: block 2049, length 6144
```

`owner=-3` ở block 2049 length 6144 sau này chính là lý do mình chọn đúng 24 MiB metadata region để historical scan. Như vậy một hướng exploratory tưởng như không ra lời giải vẫn để lại geometry quan trọng.

Mình cũng đọc `0x0018` parser vì tưởng nó có thể là Fusion topology descriptor. Source thực tế chỉ in hai qword và không chứa các mapping values mình cần. Đây là một ví dụ khác của cách mình đóng nhánh: không thấy reference tới physical-volume topology, nên không tiếp tục gán nghĩa cho object chỉ dựa trên số type.

### Khoảnh khắc nhận ra

> Current object graph có giá trị như “bản đồ các vùng metadata”, nhưng nó không còn full logical map. Lời giải phải chuyển từ current transaction sang historical transaction.

---

## Historical metadata không phải một bản backup hoàn chỉnh, nên mình phải dựng snapshot coherent

Việc thấy 1537 stale blocks không có nghĩa mình có thể chọn tùy ý block transaction cao nhất. Metadata ring chứa block từ nhiều thời điểm khác nhau. Nếu lấy root của tx này, VAT của tx khác và LVF của tx khác, tree có thể structurally valid ở từng node nhưng không phải một filesystem state từng tồn tại.

Mình dựng snapshot theo quan hệ object:

```text
historical LVF obj14 (unwiped)
       ↓ root vaddr 16
LV directory type0205
       ↓ record -> LV header vaddr15
VAT snapshot
       ↓ VAT[15] -> LV header laddr1217
LV header type001a
       ↓ mapping root vaddr12
VAT snapshot
       ↓ VAT[12] -> historical root MLV laddr
```

Một snapshot chỉ được giữ khi các pointer/vaddr/laddr cùng hợp lệ. Cách này cho 33 coherent chains.

Một số root state:

| Mapping root MLV laddr | VAT transactions quan sát được |
|---:|---|
| 72 | 1449 |
| 224 | 1396 |
| 322 | 1452, 1462, 1470, 1476, 1479, 1485, 1491, 1501, 1511, 1521, 1532, 1543, 1554, 1564, 1575 |
| 870 | 1364, 1370, 1379, 1388 |
| 1485 | 1357 |
| 1922 | 1344, 1345, 1346, 1347 |
| 2424 | 1412, 1416, 1418, 1423, 1431, 1441 |
| 2838 | 1403 |

Điều lạ lúc đầu là VAT tx1449 trỏ root laddr72, nhưng block vật lý decrypt ra header tx1449; trong khi VAT tx1575 trỏ laddr322 nhưng root block có tx1451. Đây không phải inconsistency. Copy-on-write tree có thể giữ root node cũ trong khi các virtual child address của nó được VAT mới resolve sang leaf mới hơn. Vì vậy transaction number của root block không bắt buộc bằng transaction number của VAT snapshot.

Đây cũng là lý do mình luôn resolve **child vaddr qua cùng VAT snapshot** thay vì tin laddr ghi từ một snapshot khác.

---

## Reverse address-map leaf chi tiết hơn: vì sao mình dám dùng nó để đọc 33 GiB logical volume

Một B-tree parser sai một bit là đủ để tạo ra physical blocks hợp lệ về range nhưng sai nội dung. Do đó mình đặt nhiều invariant cùng lúc.

Root tx1449 có separator:

```text
logical 0       -> child vaddr 23
logical 10176   -> child vaddr 87
logical 183808  -> child vaddr 100
logical 189664  -> child vaddr 119
logical 199616  -> child vaddr 34
logical 212864  -> child vaddr 127
logical 217408  -> child vaddr 123
logical 223744  -> child vaddr 115
logical 2285952 -> child vaddr 138
logical 2548896 -> child vaddr 39
logical 2728000 -> child vaddr 38
logical 2770176 -> child vaddr 32
logical 2876352 -> child vaddr 133
logical 2930528 -> child vaddr 29
logical 3111968 -> child vaddr 25
logical 3213824 -> child vaddr 120
```

Ví dụ leaf vaddr23:

```text
VAT -> laddr285
type        0x0304
tx          1142
obj         23
number      285
count       108
first key   logical 0
last key    logical 10144
parent range [0, 10176)
```

Leaf cuối vaddr120 tx1575:

```text
VAT -> laddr625
count       169
logical range 3213824 .. 8205312
```

Sau khi export full map, mình kiểm thêm:

```text
globally sorted = True
no overlaps      = True
encrypt_ctx      = 1 trên mọi record
PV               = 0 trên mọi record ở snapshot dùng cuối
```

`PV={0}` là một kết quả khá thú vị. Fusion Drive có hai PV, nhưng snapshot logical map mình cần cuối cùng đặt toàn bộ mapped data trên SSD. HDD vẫn cần ở giai đoạn reverse/metadata validation, nhưng khi runtime Colab reset ở cuối bài, mình có thể phục hồi chỉ `ssd.dd` và tiếp tục inner sparsebundle.

Mình không suy diễn từ đây rằng “Fusion Drive luôn nằm trên SSD”. Chỉ snapshot của challenge này có map như vậy.

---

## Reader on-demand quan trọng hơn việc tạo một decrypted image lớn

Một lựa chọn dễ là tạo raw logical image 33.6 GiB rồi mount/parse. Mình tránh vì Colab session không ổn định và không cần thiết.

Reader của mình chỉ có ba tầng:

```text
read_hfs_byte(offset)
    ↓
logical 4K block
    ↓ address map
PV + physical 4K block
    ↓ read ciphertext
8 x FileVault AES-XTS sectors
```

Sparse holes trả zero đúng theo reverse CoreStorage I/O branch. Nhờ vậy parser HFS+ nhìn thấy một byte stream như volume thật mà mình chưa bao giờ materialize volume đó ra file.

Điểm dễ sai nhất là tweak. Address map cho **physical block**, nhưng XTS tweak là **logical sector number**. Nếu dùng physical sector, block đầu có thể vẫn trông ngẫu nhiên và mình có thể đổ lỗi cho key. Vì vậy test `H+` ở logical byte1024 là bắt buộc.

Một block 4 KiB:

```python
first_sector = logical_4k * 8
for i in range(8):
    logical_sector = first_sector + i
    tweak = LE64(logical_sector) || 8*0x00
```

Đây là một trong những nguyên tắc mình rút ra từ bài: trong storage crypto, **đúng key chưa đủ; đúng address space mới quan trọng**.

---

## HFS+ Catalog parser: mình không mount vì TN1150 đã cho đủ format

Catalog File của outer filesystem có 40,960 HFS allocation blocks trong một embedded extent duy nhất, nên mình chưa cần Extents Overflow để đọc chính Catalog.

Node descriptor:

```text
+0x00 fLink
+0x04 bLink
+0x08 kind
+0x09 height
+0x0a numRecords
```

Record offset table nằm ở cuối node. Với Catalog key, mình parse:

```text
UInt16 keyLength
UInt32 parentID
UInt16 nameLength
UTF-16BE name
```

Sau key là record data, căn even-byte. `recordType=2` là file record; data fork ở offset `+88` trong `HFSPlusCatalogFile`.

Thread records (`3`/`4`) là thứ giúp mình dựng full path. Nếu chỉ tìm tên `.bash_history`, mình biết file tồn tại nhưng chưa chắc path. Mình lưu:

```text
thread[CNID] = (actual_parent_CNID, thread_name)
folder[CNID] = (parent_CNID, folder_name)
```

rồi đi ngược cho tới root CNID 2.

Kết quả `/Users/macsos/.bash_history` vì vậy đến từ Catalog semantics, không phải grep một Unicode string trong decrypted stream.

---

## Sparsebundle token: các offset mình parse trực tiếp

Để write-up tái hiện được, đây là các field mình lấy từ `token` v2:

```text
0x00  magic[8]          = encrcdsa
0x08  version           = 2
0x0c  cipherBlockBytes  = 16
0x18  dataKeyBits       = 256
0x20  authKeyBits       = 160
0x24  UUID/raw16
0x34  sectorSize        = 512
0x44  tokenSize         = 122368

0x68  iterations        = 416666
0x6c  saltLen           = 20
0x70  salt[20]

0x90  wrapperIVLen      = 8
0x94  wrapperIV[8]

0xc4  wrappedLen        = 64
0xc8  wrappedKeyBlob[64]
```

Exact values:

```text
salt = 80f81c7f0fcd4f8a65057d9967fed8c9f44f641c
IV   = 87c56b1bcc889b18
wrapped = c3261c261e319be44cef51d6a1237302...
```

Sau 3DES decrypt:

```text
padded length 64
pad = 07 07 07 07 07 07 07
clear length 57
```

57 byte tách được chính xác:

```text
32 byte AES key
20 byte HMAC key
5 byte  CKIE\0
```

`CKIE\0` là invariant lấy từ `readencrcdsa.py`, nhưng mình dùng nó như một phép kiểm trên challenge token. Nếu password sai, khả năng vừa có PKCS#7 hợp lệ, vừa đúng length geometry, vừa đúng CKIE trailer là cực thấp.

---

## Từ sparse band tới virtual sector: chỗ sparse zero dễ gây hiểu nhầm

Virtual image size là 52,428,800 byte, band size 8,388,608. Nếu band file không tồn tại, không có nghĩa virtual disk kết thúc; nó nghĩa range đó chưa được materialize và đọc như zero.

Reader:

```text
virtual_byte = sector * 512
band_no      = virtual_byte // 8388608
band_offset  = virtual_byte % 8388608
```

Nếu `band_no` không có trong `{0,3,5,6}` hoặc offset vượt logical size của band hiện tại, mình trả 512 zero bytes. Nếu có ciphertext, mới chạy HMAC/AES-CBC.

Đây là lý do mình không “concatenate bốn band” theo thứ tự file rồi coi đó là image. Làm vậy sẽ xóa mất các sparse gap và mọi sector number phía sau sẽ dịch chuyển, kéo theo HMAC-derived IV sai hoàn toàn.

---

## Colab checkpoint cũng trở thành một phần của quá trình forensic

Bài kéo dài qua nhiều session, nên `/content` của Colab từng mất toàn bộ file tạm. Mình bắt đầu checkpoint những artifact nhỏ nhưng đắt công tái tạo:

```text
tx1449_full_address_map.csv
tx1575_full_address_map.csv
inventory.json
field256.bin
field160.bin
bash_history.txt
state JSON
```

Mình không checkpoint SSD/HDD 15-18 GiB lên Drive. Khi runtime mất disk image, mình dùng HTTP Range đọc ZIP central directory từ remote, sau đó `remotezip` stream-decompress riêng `ssd.dd`.

Việc này không liên quan trực tiếp tới flag, nhưng nó là một bài học thực tế khi làm forensics image lớn trên notebook cloud: **checkpoint parser output và key material, không checkpoint mọi byte raw nếu raw có thể tái tải**.

---

## Các proof point mình dùng để không tự lừa mình

Trong quá trình này có rất nhiều nơi random bytes có thể “trông hợp lý”. Mình giữ một danh sách invariant để đóng từng nhánh:

| Layer | Proof mình yêu cầu |
|---|---|
| recovery key | RFC3394 unwrap integrity pass |
| CoreStorage metadata | common header/type/tx sane; same plaintext mirror trên hai PV |
| MLV translation | laddr35 dịch đúng về physical block decrypt ra `LVFwiped` |
| B-tree internal | separators strictly ordered |
| B-tree leaf | `obj=vaddr`, `number=laddr`, sorted keys, interval bound, sane physical extents |
| FileVault data | HFS+ `H+`, version 4, blockSize 4096 tại logical byte1024 |
| HFS+ Catalog | B-tree node geometry + exact file/folder/thread semantics |
| sparsebundle password | PKCS#7 + 32/20-byte geometry + `CKIE\0` |
| sparsebundle data | sector0 `55aa`, sector1 `EFI PART` |
| inner filesystem | Apple_HFS GUID + HFS+ Volume Header + tiny Catalog |
| final clue | exact 29-byte `/.secret.txt` read từ file fork |

Cách này chậm ở đầu nhưng giúp mình dừng được những hướng như “thử thêm crypto variant xem sao”.

---

## Script giải tối giản sau khi đã biết toàn bộ cơ chế

Nếu bỏ hết exploratory code và chỉ giữ các primitive đã chứng minh, pipeline có thể tách thành bốn reader nhỏ.

FileVault metadata:

```python
def cs_metadata_decrypt(ct8192, laddr, key_data, pv_uuid):
    key = key_data + pv_uuid
    tweak = struct.pack("<Q", laddr) + b"\x00" * 8
    d = Cipher(algorithms.AES(key), modes.XTS(tweak)).decryptor()
    return d.update(ct8192) + d.finalize()
```

Historical MLV address:

```python
def historical_meta_abs(mlv_laddr):
    paddr_4k = 2049 + 2 * mlv_laddr
    return 209735680 + paddr_4k * 4096
```

FileVault logical block reader:

```python
def fv_block(logical_4k):
    extent = address_map.lookup(logical_4k)
    if extent is None:
        return b"\x00" * 4096

    paddr = extent.paddr + (logical_4k - extent.logical)
    ct = read_ssd(209735680 + paddr * 4096, 4096)

    out = bytearray()
    for i in range(8):
        sector = logical_4k * 8 + i
        tweak = struct.pack("<Q", sector) + b"\x00" * 8
        d = Cipher(algorithms.AES(fv_xts_key), modes.XTS(tweak)).decryptor()
        out += d.update(ct[i*512:(i+1)*512]) + d.finalize()
    return bytes(out)
```

Sparsebundle virtual sector reader:

```python
def sparse_sector(n):
    band_no = (n * 512) // 8388608
    band_off = (n * 512) % 8388608

    if band_no not in bands or band_off >= bands[band_no].logical_size:
        return b"\x00" * 512

    ct = read_outer_hfs_fork(bands[band_no], band_off, 512)
    iv = hmac.new(hmac_key, struct.pack(">I", n), hashlib.sha1).digest()[:16]
    d = Cipher(algorithms.AES(aes_key), modes.CBC(iv)).decryptor()
    return d.update(ct) + d.finalize()
```

Tất cả những đoạn này chỉ ngắn sau khi mình đã mất rất nhiều thời gian chứng minh unit, address space, key và snapshot. Viết chúng từ đầu mà không có quá trình reverse phía trên sẽ chỉ là đoán.

---

## Nếu làm lại, mình sẽ thay đổi cách tư duy ở những điểm nào

Mình sẽ kiểm tra raw image size ngay sau extract, trước mọi lỗi crypto/tool. SSD truncated đã làm mình chẩn đoán sai quá lâu.

Mình sẽ đọc README limitation của libfvde ngay khi nhận ra hai CoreStorage PV. Khi tool nói unsupported multi-PV, mình sẽ không cố thêm mười wrapper để ép mount.

Mình sẽ xem current `LVFwiped` như một forensic signal để tìm stale metadata, thay vì cố ép current mapping thành filesystem.

Mình sẽ giữ ranh giới address space rõ trên giấy:

```text
vaddr
  != VAT laddr
  != MLV block
  != physical 4K block
  != FileVault logical 4K block
  != FileVault logical sector
```

Mình sẽ không blacklist một metadata type chỉ vì parser hiện tại chưa biết nó. `0x0304` là bài học rõ nhất.

Cuối cùng, khi `.bash_history` đưa ra `.pass` và `hranilka.sparsebundle`, mình sẽ follow literal evidence ngay, thay vì cố chứng minh một lệnh `dd` mà history chưa từng chứa.

---

## Những giá trị mình giữ lại để tái hiện bài

| Artifact | Value |
|---|---|
| CoreStorage partition offset | `209735680` |
| Recovery key | `XTA5-XPK2-9LV4-F6ON-WARR-4LYV` |
| PBKDF key | `bc11e1b22dbef62562fd7a04c4a04470` |
| KEK | `50eb56d7abffc91878cecf8404bffa22` |
| VMK | `212582ed5da5d8cf5579a3a23a0a23a4` |
| FileVault family | `f00135c9a9314de8a2cb6f982d2cf40c` |
| FileVault tweak key | `29331015d021a84988acce8cb7878fa6` |
| tx1449 address map | 2081 records |
| tx1575 address map | 2127 records, PV0 only |
| `.bash_history` SHA-256 | `7f767333fe6443589e6423d1a2be32418a0a62047d55ac39a9fe836f3c7f42a8` |
| sparsebundle password | `ILoveAzazinCreet` |
| encrcdsa AES-256 key | `78f4795a629d4c2b06ce2e8b3cfd8fb607a3a0f319fcea2d71808c93f8c7e5af` |
| encrcdsa HMAC key | `a77bc27dd7de254e3dcf18908192c8829ee50fd8` |
| inner Apple_HFS start LBA | `40` |
| `/.secret.txt` URL | `https://youtu.be/461vxC3ZKMc` |

---

## Ghép Flag

```text
kaspersky{1_th1nk_1t5_b3tt3r_t0_wr1t3_th3_k3y_0n_p4p3r}
```
