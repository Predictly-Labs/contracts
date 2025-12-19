# View Functions Guide

Panduan lengkap untuk membaca data dari smart contract Predictly.

## Contract Info

```
Network: Movement Testnet (Bardock)
Contract: 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
Module: predictly::market
```

---

## Cara Akses via Explorer

### 1. Buka Explorer
https://explorer.movementnetwork.xyz/?network=bardock+testnet

### 2. Direct Link ke Module
```
https://explorer.movementnetwork.xyz/account/0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565/modules/run/market?network=bardock+testnet
```

### 3. Pilih Tab "View"
- Klik function yang mau dipanggil
- Isi parameter
- Klik "Run"

---

## Daftar View Functions

### get_market_count
Mendapatkan total jumlah market yang sudah dibuat.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |

**Output:** `["1"]` → ada 1 market

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_count \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
```

---

### get_market_status
Mendapatkan status market.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` (market pertama) |

**Output:** 
- `["0"]` → ACTIVE (masih bisa vote)
- `["1"]` → RESOLVED (sudah selesai)
- `["2"]` → CANCELLED (dibatalkan)

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_status \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```

---

### get_market_outcome
Mendapatkan hasil akhir market.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |

**Output:**
- `["0"]` → PENDING (belum resolved)
- `["1"]` → YES menang
- `["2"]` → NO menang
- `["3"]` → INVALID (refund semua)

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_outcome \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```

---

### get_market_pools
Mendapatkan total MOVE yang di-stake di YES dan NO pool.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |

**Output:** `["100000000", "50000000"]`
- Index 0: YES pool = 100000000 octas = 1 MOVE
- Index 1: NO pool = 50000000 octas = 0.5 MOVE

**Konversi:** 1 MOVE = 100,000,000 octas

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_pools \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```

---

### get_percentages
Mendapatkan persentase YES vs NO.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |

**Output:** `["6667", "3333"]`
- Index 0: YES = 6667 basis points = 66.67%
- Index 1: NO = 3333 basis points = 33.33%

**Konversi:** Bagi 100 untuk dapat persen (5000 = 50%)

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_percentages \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```

---

### get_participant_count
Mendapatkan jumlah voter di market.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |

**Output:** `["5"]` → ada 5 orang yang sudah vote

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_participant_count \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```

---

### get_vote_prediction
Mendapatkan prediksi vote seseorang.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |
| voter | address | `0x...` (wallet address voter) |

**Output:**
- `["1"]` → Vote YES
- `["2"]` → Vote NO

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_vote_prediction \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0 address:0xVOTER_ADDRESS
```

---

### get_vote_amount
Mendapatkan jumlah stake seseorang.

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |
| voter | address | `0x...` (wallet address voter) |

**Output:** `["100000000"]` → stake 1 MOVE

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_vote_amount \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0 address:0xVOTER_ADDRESS
```

---

### calculate_reward
Menghitung reward yang akan didapat (setelah market resolved).

**Parameter:**
| Name | Type | Value |
|------|------|-------|
| admin_addr | address | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |
| market_id | u64 | `0` |
| voter | address | `0x...` (wallet address voter) |

**Output:** `["200000000"]` → akan dapat 2 MOVE

**CLI:**
```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::calculate_reward \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0 address:0xVOTER_ADDRESS
```

---

## Quick Reference

### Constants
| Constant | Values |
|----------|--------|
| Status | 0=ACTIVE, 1=RESOLVED, 2=CANCELLED |
| Outcome | 0=PENDING, 1=YES, 2=NO, 3=INVALID |
| Prediction | 1=YES, 2=NO |
| Market Type | 0=STANDARD, 1=NO_LOSS |

### Konversi
| From | To | Formula |
|------|-----|---------|
| octas | MOVE | ÷ 100,000,000 |
| basis points | % | ÷ 100 |
