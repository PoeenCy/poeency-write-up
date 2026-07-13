+++
title = 'Follow The Layer - Write-up'
date = '2026-07-14T02:21:00+07:00'
draft = false
tags = ['LYCKNCTF2026', 'blockchain', 'tron', 'trc20', 'ofac']
categories = ['Forensics', 'OSINT']
+++

# CTF Write-up: Follow The Layer

**Category:** Forensics / OSINT
**Flag format:** `LYKNCTF{tx_hash:MM/DD/YYYY:ENTITY}`
**Flag cuối:** `LYKNCTF{7e401f8004084d4bf9f792535fdf5b89138a935d027b6b75ceb2dd3ac8838fab:03/21/2025:FUNNULL}`

---

## Mô tả bài

> Our fraud response team flagged a suspicious USDT transfer linked to an online scam operation.
>
> The payment trail starts here:
> `d4500023a8114caaa640ab92bb8f73830a5303ccdfc4e9b0cf862bdae7ae336b`
>
> The money didn't just vanish - it was layered through a series of wallets before disappearing into the shadows. But every hop leaves a trace.
>
> Trace the laundering chain, find where the money stops being attributable, and answer:
> 1. What is the transaction hash of the last traceable hop?
> 2. What date did it occur? (MM/DD/YYYY)
> 3. What is the name of the sanctioned entity at the heart of this operation?

**Tải về đề bài:** [challenge files - OneDrive](https://1drv.ms/u/c/2f661437c52d8a10/IQCVmKGjVm_dT7IXzhr180LHATFvxjgF41ReO_dIF63vCnE?e=ChIVkX)

---

## Nhận dữ liệu và xác định chain

Bài chỉ cho một transaction hash. Hash dài 64 ký tự hex có thể thuộc Ethereum, BSC, TRON hoặc nhiều chain khác, nên việc đầu tiên là xác định explorer đúng.

Mình thử tra trên các explorer quen thuộc. Etherscan và BscScan không có kết quả, còn Tronscan tìm thấy giao dịch. Vì đề nhắc USDT và scam, TRON khá hợp lý: USDT TRC-20 thường được dùng vì phí rẻ và chuyển nhanh.

Để lấy dữ liệu có cấu trúc thay vì bấm từng tab trong UI, mình dùng Tronscan API:

```bash
$ curl -s "https://apilist.tronscan.org/api/transaction-info?hash=d4500023a8114caaa640ab92bb8f73830a5303ccdfc4e9b0cf862bdae7ae336b"
```

Các trường quan trọng:

```json
{
  "hash": "d4500023a8114caaa640ab92bb8f73830a5303ccdfc4e9b0cf862bdae7ae336b",
  "block": 70002978,
  "timestamp": 1740661449000,
  "confirmed": true,
  "contractRet": "SUCCESS",
  "ownerAddress": "TXk7Dor9GeRRpR5hbCGd4rBieM21v4BcwX",
  "toAddress": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
  "trc20TransferInfo": [{
    "from_address": "TXk7Dor9GeRRpR5hbCGd4rBieM21v4BcwX",
    "to_address": "TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8",
    "amount_str": "2700000000",
    "symbol": "USDT"
  }]
}
```

Điểm dễ nhầm ở TRC-20 là `toAddress` cấp transaction là contract USDT (`TR7NH...`), còn ví nhận USDT thật nằm trong `trc20TransferInfo.to_address`.

Hop đầu tiên:

| Trường | Giá trị |
|---|---|
| From | `TXk7Dor9GeRRpR5hbCGd4rBieM21v4BcwX` |
| To | `TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8` |
| Amount | `2700 USDT` |
| Date | `02/27/2025 13:04:09 UTC` |

---

## Phần 1: Lần theo dòng tiền

Mình viết một script nhỏ gọi API `token_trc20/transfers` để lấy các giao dịch USDT IN/OUT của từng ví. Mục tiêu là tìm giao dịch OUT sau khi ví nhận tiền, đặc biệt nếu số tiền được chuyển gần như nguyên vẹn.

```python
import json
import urllib.request

USDT_CONTRACT = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

def get_transfers(address, limit=20):
    url = (
        "https://apilist.tronscan.org/api/token_trc20/transfers"
        f"?limit={limit}&start=0"
        f"&contract_address={USDT_CONTRACT}"
        f"&relatedAddress={address}"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())

    for t in data.get("token_transfers", []):
        direction = "OUT" if t["from_address"] == address else " IN"
        amount = int(t["quant"]) / 1e6
        print(direction, t["transaction_id"], t["from_address"], t["to_address"], amount, t["block_ts"])
```

### Hop 1 - ví gom tiền

Ví `TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8` nhận 2700 USDT từ giao dịch đề bài. Sau đó nó còn nhận thêm 2522 USDT từ một ví khác, rồi chuyển đúng tổng 5222 USDT đi:

```
[ IN] d4500023a8114caaa640ab92bb8f73830a5303ccdfc4e9b0cf862bdae7ae336b
     TXk7Dor9GeRRpR5hbCGd4rBieM21v4BcwX -> TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8
     2700.00 USDT | 02/27/2025 13:04:09 UTC

[ IN] 5d1c353fbb6764f0aefd3f1533ede3842aac3c09a6a70b7e77e17786db0f8181
     TPfTT8bTnaWH7vekHMkbe882qb8f6FeTX9 -> TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8
     2522.00 USDT | 03/07/2025 08:15:18 UTC

[OUT] 2ef09557180070d4bfd274f771619b062fa9a1dec5087869b45e65003256b9d9
     TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8 -> TQMq9s5eqxzHW9CG4hgrWxVZaz4oZDo3tb
     5222.00 USDT | 03/21/2025 03:03:30 UTC
```

Đây là ví staging: gom nhiều nguồn vào một chỗ, rồi chuyển toàn bộ sang hop kế tiếp.

### Hop 2 - ví chuyển tiếp

Ví `TQMq9s5eqxzHW9CG4hgrWxVZaz4oZDo3tb` giữ tiền rất ngắn. Nó nhận 5222 USDT rồi chuyển nguyên số đó sang ví khác:

```
[ IN] 2ef09557180070d4bfd274f771619b062fa9a1dec5087869b45e65003256b9d9
     TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8 -> TQMq9s5eqxzHW9CG4hgrWxVZaz4oZDo3tb
     5222.00 USDT | 03/21/2025 03:03:30 UTC

[OUT] 7e401f8004084d4bf9f792535fdf5b89138a935d027b6b75ceb2dd3ac8838fab
     TQMq9s5eqxzHW9CG4hgrWxVZaz4oZDo3tb -> TJ7hhYhVhaxNx6BPyq7yFpqZrQULL3JSdb
     5222.00 USDT | 03/21/2025 03:07:39 UTC
```

Khoảng cách chỉ khoảng 4 phút, rất giống relay wallet tự động.

---

## Phần 2: Điểm dừng traceable và thực thể bị sanction

Ví nhận cuối `TJ7hhYhVhaxNx6BPyq7yFpqZrQULL3JSdb` được các nguồn explorer gắn nhãn là ví nóng Bitget. Khi tiền đi vào CEX hot wallet, on-chain public trace gần như dừng lại vì tiền bị trộn vào thanh khoản của sàn. Muốn đi tiếp cần log nội bộ/KYC của sàn, không còn là dữ liệu public ledger.

Vì vậy giao dịch cuối còn trace được là:

```
7e401f8004084d4bf9f792535fdf5b89138a935d027b6b75ceb2dd3ac8838fab
```

Sai lầm dễ mắc là lấy `Bitget` làm entity cuối, vì nó là điểm kết thúc dòng tiền. Nhưng đề hỏi "sanctioned entity at the heart of this operation", không hỏi tên sàn nhận tiền cuối.

Mình quay lại tra từng ví trung gian trên OFAC SDN. Ví `TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8` khớp với:

```
FUNNULL TECHNOLOGY INC.
Program: CYBER3
Address (TRON): TNmRfnSUXZoWWzxcDDbf95eGQYXt1mJDt8
```

Vậy thực thể cần điền là `FUNNULL`.

---

## Ghép Flag

| Thành phần | Giá trị | Nguồn |
|---|---|---|
| Last traceable hop | `7e401f8004084d4bf9f792535fdf5b89138a935d027b6b75ceb2dd3ac8838fab` | Hop 2 OUT vào Bitget hot wallet |
| Date | `03/21/2025` | Timestamp của last hop |
| Entity | `FUNNULL` | OFAC SDN match của ví Hop 1 |

```
LYKNCTF{7e401f8004084d4bf9f792535fdf5b89138a935d027b6b75ceb2dd3ac8838fab:03/21/2025:FUNNULL}
```

---

## Bài học rút ra

**1. Với TRC-20, ví nhận token nằm trong transfer event.**
`toAddress` của transaction có thể chỉ là contract USDT. Phải đọc `trc20TransferInfo`.

**2. CEX hot wallet là điểm mù của public-chain tracing.**
Khi tiền vào sàn tập trung, dữ liệu public không còn đủ để gán cho user cuối.

**3. Entity của đề không nhất thiết là điểm cuối.**
Ở bài này, `Bitget` là endpoint, nhưng `FUNNULL` mới là sanctioned entity ở trung tâm chuỗi.
