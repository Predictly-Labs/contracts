# Predictly Smart Contracts

Move smart contracts for Predictly prediction market platform on Movement Network.

## Deployed Contract (Movement Testnet)

| Network | Contract Address |
|---------|-----------------|
| Movement Testnet | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |

**Explorer:** https://explorer.movementnetwork.xyz/?network=bardock+testnet

## Quick Reference

```
CONTRACT_ADDRESS = 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
MODULE = predictly::market
```

---

## View Functions (Read Data)

All view functions require `admin_addr` as first parameter = CONTRACT_ADDRESS

### get_market_count
Get total number of markets created.

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_count \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565
```
**Output:** `["1"]` (1 market exists)

### get_market_status
Get market status (0=ACTIVE, 1=RESOLVED, 2=CANCELLED).

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_status \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```
**Input:** `admin_addr`, `market_id`
**Output:** `["0"]` (ACTIVE)

### get_market_outcome
Get market outcome (0=PENDING, 1=YES, 2=NO, 3=INVALID).

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_outcome \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```
**Input:** `admin_addr`, `market_id`
**Output:** `["0"]` (PENDING)

### get_market_pools
Get YES and NO pool amounts in octas (1 MOVE = 100,000,000 octas).

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_market_pools \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```
**Input:** `admin_addr`, `market_id`
**Output:** `["100000000", "50000000"]` (1 MOVE in YES, 0.5 MOVE in NO)

### get_percentages
Get YES/NO percentages in basis points (5000 = 50%).

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_percentages \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```
**Input:** `admin_addr`, `market_id`
**Output:** `["5000", "5000"]` (50% YES, 50% NO)

### get_participant_count
Get number of voters in a market.

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_participant_count \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0
```
**Input:** `admin_addr`, `market_id`
**Output:** `["5"]` (5 participants)

### get_vote_prediction
Get a voter's prediction (1=YES, 2=NO).

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_vote_prediction \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0 address:0x123...voter_address
```
**Input:** `admin_addr`, `market_id`, `voter_address`
**Output:** `["1"]` (voted YES)

### get_vote_amount
Get a voter's stake amount in octas.

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::get_vote_amount \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0 address:0x123...voter_address
```
**Input:** `admin_addr`, `market_id`, `voter_address`
**Output:** `["100000000"]` (staked 1 MOVE)

### calculate_reward
Calculate potential reward for a voter (after market resolved).

```bash
aptos move view \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::calculate_reward \
  --args address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 u64:0 address:0x123...voter_address
```
**Input:** `admin_addr`, `market_id`, `voter_address`
**Output:** `["200000000"]` (will receive 2 MOVE)

---

## Entry Functions (Write Data)

### initialize
Initialize the market module. Call once after deployment.

```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::initialize
```

### create_market
Create a new prediction market.

```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::create_market \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    string:"Will BTC reach 100k?" \
    string:"Bitcoin price prediction for 2025" \
    u64:1735689600 \
    u64:10000000 \
    u64:1000000000 \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u8:0
```
**Input:**
| Arg | Type | Description | Example |
|-----|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| title | string | Market title | `"Will BTC reach 100k?"` |
| description | string | Market description | `"Bitcoin prediction"` |
| end_time | u64 | Unix timestamp when voting ends | `1735689600` |
| min_stake | u64 | Minimum stake in octas | `10000000` (0.1 MOVE) |
| max_stake | u64 | Maximum stake (0 = no limit) | `1000000000` (10 MOVE) |
| resolver | address | Who can resolve the market | `0x916...` |
| market_type | u8 | 0=STANDARD, 1=NO_LOSS | `0` |

### place_vote
Vote on a market with stake.

```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::place_vote \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u64:0 \
    u8:1 \
    u64:100000000
```
**Input:**
| Arg | Type | Description | Example |
|-----|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| market_id | u64 | Market ID | `0` |
| prediction | u8 | 1=YES, 2=NO | `1` |
| amount | u64 | Stake amount in octas | `100000000` (1 MOVE) |

### resolve
Resolve a market after end_time (resolver only).

```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::resolve \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u64:0 \
    u8:1
```
**Input:**
| Arg | Type | Description | Example |
|-----|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| market_id | u64 | Market ID | `0` |
| outcome | u8 | 1=YES, 2=NO, 3=INVALID | `1` |

### claim_reward
Claim reward from resolved market.

```bash
aptos move run \
  --function-id 0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565::market::claim_reward \
  --args \
    address:0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565 \
    u64:0
```
**Input:**
| Arg | Type | Description | Example |
|-----|------|-------------|---------|
| admin_addr | address | Contract address | `0x916...` |
| market_id | u64 | Market ID | `0` |

---

## Constants Reference

### Market Type
| Value | Name | Description |
|-------|------|-------------|
| 0 | STANDARD | Winner takes proportional share of total pool |
| 1 | NO_LOSS | Losers get principal back, winners get yield |

### Prediction
| Value | Name |
|-------|------|
| 1 | YES |
| 2 | NO |

### Status
| Value | Name | Description |
|-------|------|-------------|
| 0 | ACTIVE | Accepting votes |
| 1 | RESOLVED | Outcome determined |
| 2 | CANCELLED | Market cancelled |

### Outcome
| Value | Name | Description |
|-------|------|-------------|
| 0 | PENDING | Not yet resolved |
| 1 | YES | YES prediction won |
| 2 | NO | NO prediction won |
| 3 | INVALID | Market invalidated, refunds |

---

## TypeScript Example

```typescript
import { Aptos, AptosConfig } from '@aptos-labs/ts-sdk';

const CONTRACT = '0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565';

const aptos = new Aptos(new AptosConfig({
  fullnode: 'https://testnet.movementnetwork.xyz/v1'
}));

// Read market count
async function getMarketCount() {
  const [count] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_market_count`,
      functionArguments: [CONTRACT],
    }
  });
  return Number(count);
}

// Read market pools
async function getMarketPools(marketId: number) {
  const [yesPool, noPool] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_market_pools`,
      functionArguments: [CONTRACT, marketId.toString()],
    }
  });
  return {
    yesPool: Number(yesPool) / 100000000, // Convert to MOVE
    noPool: Number(noPool) / 100000000,
  };
}

// Read percentages
async function getPercentages(marketId: number) {
  const [yesPct, noPct] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_percentages`,
      functionArguments: [CONTRACT, marketId.toString()],
    }
  });
  return {
    yesPercent: Number(yesPct) / 100, // Convert basis points to %
    noPercent: Number(noPct) / 100,
  };
}
```

---

## Build & Test

```bash
# Compile
aptos move compile --package-dir contracts/predictly --named-addresses predictly=0xCAFE

# Test (15 tests)
aptos move test --package-dir contracts/predictly
```

## Deploy

```bash
# Init account
aptos init --network custom \
  --rest-url https://testnet.movementnetwork.xyz/v1 \
  --faucet-url https://faucet.testnet.movementnetwork.xyz

# Deploy
aptos move publish --package-dir contracts/predictly --named-addresses predictly=default --assume-yes

# Initialize
aptos move run --function-id default::market::initialize --assume-yes
```
