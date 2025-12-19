# TypeScript Integration Guide

Panduan integrasi smart contract Predictly dengan TypeScript/JavaScript.

## Setup

### Install SDK
```bash
npm install @aptos-labs/ts-sdk
```

### Initialize Client
```typescript
import { Aptos, AptosConfig, Network } from '@aptos-labs/ts-sdk';

const CONTRACT = '0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565';

const config = new AptosConfig({
  fullnode: 'https://testnet.movementnetwork.xyz/v1',
});

const aptos = new Aptos(config);
```

---

## View Functions (Read Data)

### Get Market Count
```typescript
async function getMarketCount(): Promise<number> {
  const [count] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_market_count`,
      functionArguments: [CONTRACT],
    }
  });
  return Number(count);
}
```

### Get Market Status
```typescript
async function getMarketStatus(marketId: number): Promise<number> {
  const [status] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_market_status`,
      functionArguments: [CONTRACT, marketId.toString()],
    }
  });
  return Number(status); // 0=ACTIVE, 1=RESOLVED, 2=CANCELLED
}
```

### Get Market Outcome
```typescript
async function getMarketOutcome(marketId: number): Promise<number> {
  const [outcome] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_market_outcome`,
      functionArguments: [CONTRACT, marketId.toString()],
    }
  });
  return Number(outcome); // 0=PENDING, 1=YES, 2=NO, 3=INVALID
}
```

### Get Market Pools
```typescript
async function getMarketPools(marketId: number): Promise<{yesPool: number, noPool: number}> {
  const [yesPool, noPool] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_market_pools`,
      functionArguments: [CONTRACT, marketId.toString()],
    }
  });
  return {
    yesPool: Number(yesPool) / 100_000_000, // Convert to MOVE
    noPool: Number(noPool) / 100_000_000,
  };
}
```

### Get Percentages
```typescript
async function getPercentages(marketId: number): Promise<{yesPercent: number, noPercent: number}> {
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

### Get Participant Count
```typescript
async function getParticipantCount(marketId: number): Promise<number> {
  const [count] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_participant_count`,
      functionArguments: [CONTRACT, marketId.toString()],
    }
  });
  return Number(count);
}
```

### Get Vote Info
```typescript
async function getVoteInfo(marketId: number, voterAddress: string): Promise<{prediction: number, amount: number}> {
  const [prediction] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_vote_prediction`,
      functionArguments: [CONTRACT, marketId.toString(), voterAddress],
    }
  });
  
  const [amount] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::get_vote_amount`,
      functionArguments: [CONTRACT, marketId.toString(), voterAddress],
    }
  });
  
  return {
    prediction: Number(prediction), // 1=YES, 2=NO
    amount: Number(amount) / 100_000_000, // Convert to MOVE
  };
}
```

### Calculate Reward
```typescript
async function calculateReward(marketId: number, voterAddress: string): Promise<number> {
  const [reward] = await aptos.view({
    payload: {
      function: `${CONTRACT}::market::calculate_reward`,
      functionArguments: [CONTRACT, marketId.toString(), voterAddress],
    }
  });
  return Number(reward) / 100_000_000; // Convert to MOVE
}
```

---

## Entry Functions (Write Data)

Entry functions membutuhkan wallet untuk sign transaction.

### Build Create Market Payload
```typescript
function buildCreateMarketPayload(params: {
  title: string;
  description: string;
  endTime: number;
  minStake: number; // in MOVE
  maxStake: number; // in MOVE (0 = unlimited)
  resolver: string;
  marketType: 0 | 1; // 0=STANDARD, 1=NO_LOSS
}) {
  return {
    function: `${CONTRACT}::market::create_market`,
    functionArguments: [
      CONTRACT,
      params.title,
      params.description,
      params.endTime.toString(),
      (params.minStake * 100_000_000).toString(),
      (params.maxStake * 100_000_000).toString(),
      params.resolver,
      params.marketType,
    ],
  };
}
```

### Build Place Vote Payload
```typescript
function buildPlaceVotePayload(params: {
  marketId: number;
  prediction: 1 | 2; // 1=YES, 2=NO
  amount: number; // in MOVE
}) {
  return {
    function: `${CONTRACT}::market::place_vote`,
    functionArguments: [
      CONTRACT,
      params.marketId.toString(),
      params.prediction,
      (params.amount * 100_000_000).toString(),
    ],
  };
}
```

### Build Resolve Payload
```typescript
function buildResolvePayload(params: {
  marketId: number;
  outcome: 1 | 2 | 3; // 1=YES, 2=NO, 3=INVALID
}) {
  return {
    function: `${CONTRACT}::market::resolve`,
    functionArguments: [
      CONTRACT,
      params.marketId.toString(),
      params.outcome,
    ],
  };
}
```

### Build Claim Reward Payload
```typescript
function buildClaimRewardPayload(marketId: number) {
  return {
    function: `${CONTRACT}::market::claim_reward`,
    functionArguments: [
      CONTRACT,
      marketId.toString(),
    ],
  };
}
```

---

## Full Example: Get All Market Data

```typescript
async function getFullMarketData(marketId: number) {
  const [status, outcome, pools, percentages, participants] = await Promise.all([
    getMarketStatus(marketId),
    getMarketOutcome(marketId),
    getMarketPools(marketId),
    getPercentages(marketId),
    getParticipantCount(marketId),
  ]);

  return {
    marketId,
    status: ['ACTIVE', 'RESOLVED', 'CANCELLED'][status],
    outcome: ['PENDING', 'YES', 'NO', 'INVALID'][outcome],
    yesPool: pools.yesPool,
    noPool: pools.noPool,
    totalPool: pools.yesPool + pools.noPool,
    yesPercent: percentages.yesPercent,
    noPercent: percentages.noPercent,
    participants,
  };
}

// Usage
const data = await getFullMarketData(0);
console.log(data);
// {
//   marketId: 0,
//   status: 'ACTIVE',
//   outcome: 'PENDING',
//   yesPool: 1.5,
//   noPool: 0.5,
//   totalPool: 2,
//   yesPercent: 75,
//   noPercent: 25,
//   participants: 5
// }
```

---

## Constants

```typescript
// Contract
const CONTRACT = '0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565';
const RPC_URL = 'https://testnet.movementnetwork.xyz/v1';

// Conversion
const OCTAS_PER_MOVE = 100_000_000;

// Enums
const MarketStatus = {
  ACTIVE: 0,
  RESOLVED: 1,
  CANCELLED: 2,
} as const;

const MarketOutcome = {
  PENDING: 0,
  YES: 1,
  NO: 2,
  INVALID: 3,
} as const;

const Prediction = {
  YES: 1,
  NO: 2,
} as const;

const MarketType = {
  STANDARD: 0,
  NO_LOSS: 1,
} as const;
```

---

## Error Handling

```typescript
async function safeGetMarketData(marketId: number) {
  try {
    const data = await getFullMarketData(marketId);
    return { success: true, data };
  } catch (error) {
    if (error.message?.includes('MARKET_NOT_FOUND')) {
      return { success: false, error: 'Market does not exist' };
    }
    return { success: false, error: error.message };
  }
}
```
