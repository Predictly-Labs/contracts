# Entry Functions Guide

Panduan lengkap untuk menulis data ke smart contract Predictly (butuh wallet & gas).

## Contract Info

```
Network: Movement Testnet (Bardock)
Contract: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
Module: predictly::market
```

---

## Cara Akses via Explorer

### 1. Direct Link
```
https://explorer.movementnetwork.xyz/account/0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565/modules/run/market?network=bardock+testnet
```

### 2. Pilih Tab "Run" (bukan View)
- Klik function yang mau dipanggil
- Connect wallet
- Isi parameter
- Klik "Run"

---

## Daftar Entry Functions

### create_market
Membuat prediction market baru.

**Parameter:**
| Name | Type | Description | Example |
|------|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| title | String | Judul market | `Will BTC reach 100k?` |
| description | String | Deskripsi | `Bitcoin price prediction` |
| end_time | u64 | Unix timestamp kapan voting berakhir | `1735689600` |
| min_stake | u64 | Minimum stake dalam octas | `10000000` (0.1 MOVE) |
| max_stake | u64 | Maximum stake (0 = unlimited) | `1000000000` (10 MOVE) |
| resolver | address | Siapa yang bisa resolve | `0x916...` |
| market_type | u8 | 0=STANDARD, 1=NO_LOSS | `0` |

**Contoh di Explorer:**
```
admin_addr: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
title: Will BTC reach 100k in 2025?
description: Bitcoin price prediction for end of 2025
end_time: 1735689600
min_stake: 10000000
max_stake: 1000000000
resolver: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
market_type: 0
```

**CLI:**
```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::create_market \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    string:"Will BTC reach 100k?" \
    string:"Bitcoin price prediction" \
    u64:1735689600 \
    u64:10000000 \
    u64:1000000000 \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u8:0
```

---

### place_vote
Vote di market dengan stake MOVE.

**Parameter:**
| Name | Type | Description | Example |
|------|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| market_id | u64 | ID market | `0` |
| prediction | u8 | 1=YES, 2=NO | `1` |
| amount | u64 | Jumlah stake dalam octas | `100000000` (1 MOVE) |

**Contoh di Explorer:**
```
admin_addr: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
market_id: 0
prediction: 1
amount: 100000000
```

**CLI:**
```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::place_vote \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u64:0 \
    u8:1 \
    u64:100000000
```

**Notes:**
- Harus punya MOVE di wallet
- Amount harus >= min_stake dan <= max_stake
- Tidak bisa vote 2x di market yang sama

---

### resolve
Menentukan hasil akhir market (hanya resolver).

**Parameter:**
| Name | Type | Description | Example |
|------|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| market_id | u64 | ID market | `0` |
| outcome | u8 | 1=YES, 2=NO, 3=INVALID | `1` |

**Contoh di Explorer:**
```
admin_addr: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
market_id: 0
outcome: 1
```

**CLI:**
```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::resolve \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u64:0 \
    u8:1
```

**Notes:**
- Hanya bisa dipanggil oleh resolver address
- Hanya bisa setelah end_time lewat
- Outcome 3 (INVALID) = semua orang dapat refund

---

### claim_reward
Klaim reward setelah market resolved.

**Parameter:**
| Name | Type | Description | Example |
|------|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| market_id | u64 | ID market | `0` |

**Contoh di Explorer:**
```
admin_addr: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
market_id: 0
```

**CLI:**
```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::claim_reward \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u64:0
```

**Notes:**
- Hanya bisa setelah market resolved
- Hanya yang menang dapat reward
- Kalau outcome INVALID, semua dapat refund
- Tidak bisa claim 2x

---

## Flow Lengkap

```
1. Admin: create_market() → Market ID = 0
2. User A: place_vote(market_id=0, prediction=YES, amount=1 MOVE)
3. User B: place_vote(market_id=0, prediction=NO, amount=0.5 MOVE)
4. ... waktu berlalu sampai end_time ...
5. Resolver: resolve(market_id=0, outcome=YES)
6. User A: claim_reward(market_id=0) → dapat 1.5 MOVE
7. User B: claim_reward(market_id=0) → dapat 0 (kalah)
```

---

## Konversi Cepat

| MOVE | Octas |
|------|-------|
| 0.1 | 10,000,000 |
| 0.5 | 50,000,000 |
| 1 | 100,000,000 |
| 5 | 500,000,000 |
| 10 | 1,000,000,000 |

---

## Unix Timestamp

Untuk convert tanggal ke unix timestamp:
- https://www.unixtimestamp.com/

Contoh:
- 1 Jan 2025 00:00 UTC = `1735689600`
- 1 Feb 2025 00:00 UTC = `1738368000`
- 1 Mar 2025 00:00 UTC = `1740787200`
