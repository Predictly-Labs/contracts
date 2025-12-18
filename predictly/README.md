# Predictly Smart Contracts

Move smart contracts for Predictly prediction market platform on Movement Network.

## Prerequisites

- [Movement CLI](https://docs.movementlabs.xyz/) or [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli)
- Rust (for building)

## Project Structure

```
predictly/
├── Move.toml           # Package configuration
├── sources/
│   └── market.move     # Main prediction market module
└── tests/              # Unit tests (coming soon)
```

## Build

```bash
# Using Movement CLI
movement move compile

# Or using Aptos CLI
aptos move compile
```

## Test

```bash
movement move test
```

## Deploy to Devnet

```bash
# Initialize account (first time only)
movement init --network devnet

# Deploy
movement move publish --named-addresses predictly=default
```

## Contract Overview

### Market Module (`predictly::market`)

Core functionality:
- `initialize`: Setup the market module (admin only, once)
- `create_market`: Create a new prediction market
- `place_vote`: Stake tokens on YES or NO outcome
- `resolve`: Resolve market after end time (resolver only)
- `claim_reward`: Claim winnings from resolved market

View functions:
- `get_market_state`: Get market details
- `get_vote`: Get vote details for a voter
- `get_market_count`: Get total number of markets
- `calculate_reward`: Calculate potential reward
- `get_percentages`: Get YES/NO vote percentages

## Market Types

- **STANDARD (0)**: Winner takes proportional share of total pool

## Market Status

- `ACTIVE (0)`: Accepting votes
- `RESOLVED (1)`: Outcome determined, claims open
- `CANCELLED (2)`: Market cancelled, refunds available

## Outcomes

- `PENDING (0)`: Not yet resolved
- `YES (1)`: YES prediction won
- `NO (2)`: NO prediction won
- `INVALID (3)`: Market invalidated, all stakes refunded
