# Predictly Smart Contracts

Move smart contracts for Predictly prediction market platform on Movement Network.

## Contracts

| Contract | Description | Docs |
|----------|-------------|------|
| [predictly](https://explorer.movementnetwork.xyz/account/0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565/transactions?network=bardock+testnet) | Prediction market core contract | [README]([./predictly/README.md](https://github.com/Predictly-Labs)) |

## Deployed Addresses

| Network | Contract | Address |
|---------|----------|---------|
| Movement Testnet | predictly | `0x9161980be9b78e96ddae98ceb289f6f4cda5e4af70667667ff9af8438a94e565` |

## Quick Start

```bash
# Compile
aptos move compile --package-dir contracts/predictly

# Test
aptos move test --package-dir contracts/predictly

# Deploy
aptos move publish --package-dir contracts/predictly --named-addresses predictly=default
```

## Documentation

- [View Functions](./predictly/docs/VIEW_FUNCTIONS.md) - Read data from contract
- [Entry Functions](./predictly/docs/ENTRY_FUNCTIONS.md) - Write data to contract
- [TypeScript Integration](./predictly/docs/TYPESCRIPT_INTEGRATION.md) - Frontend integration
