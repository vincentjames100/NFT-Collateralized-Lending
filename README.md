# 🎨 NFT Collateralized Lending Platform

> 💸 Unlock liquidity from your NFTs without selling them

A Clarity smart contract that enables NFT owners to borrow against their digital assets while maintaining ownership rights through an innovative collateralized lending system.

## 🚀 Overview

The NFT Collateralized Lending platform solves the liquidity problem for NFT holders by allowing them to:
- 🔒 Lock NFTs as collateral in secure vaults
- 💰 Borrow STX tokens based on NFT valuations
- ⚡ Access instant liquidity without selling assets
- 🔥 Participate in liquidation auctions

## ✨ Key Features

### 🏦 Lending System
- **Collateral-Based Loans**: Borrow up to 75% of NFT value
- **Interest Rate**: 5% annual interest on borrowed amounts
- **Loan Duration**: 144 blocks (approximately 24 hours)
- **Oracle Integration**: Real-time NFT price feeds

### 🔨 Liquidation Engine
- **Health Monitoring**: Real-time loan-to-value ratio tracking
- **Automatic Liquidation**: Triggered when collateral ratio drops below 75%
- **Auction System**: 12-block auction period for liquidated NFTs
- **Competitive Bidding**: Open marketplace for NFT acquisition

### 📊 Analytics Dashboard
- **Portfolio Tracking**: Monitor all active loans
- **Risk Assessment**: Real-time health ratios
- **Market Statistics**: Platform volume and activity metrics

## 🛠️ Smart Contract Functions

### 📝 Core Operations

#### `create-loan`
```clarity
(create-loan nft-contract nft-id loan-amount)
```
Lock an NFT as collateral and receive a loan in STX tokens.

#### `repay-loan`
```clarity
(repay-loan loan-id)
```
Repay the loan plus interest to reclaim your NFT.

#### `liquidate-loan`
```clarity
(liquidate-loan loan-id)
```
Trigger liquidation for undercollateralized or expired loans.

### 🏷️ Auction System

#### `place-bid`
```clarity
(place-bid auction-id bid-amount)
```
Bid on liquidated NFTs in active auctions.

#### `finalize-auction`
```clarity
(finalize-auction auction-id)
```
Complete the auction and transfer NFT to the highest bidder.

### 📈 Oracle Functions

#### `update-nft-price`
```clarity
(update-nft-price nft-contract nft-id price)
```
Update NFT valuations (owner-only function).

### 🔍 Query Functions

#### `get-loan`
```clarity
(get-loan loan-id)
```
Retrieve detailed loan information.

#### `get-loan-health`
```clarity
(get-loan-health loan-id)
```
Check the current health ratio of a loan.

#### `get-user-loans`
```clarity
(get-user-loans user-principal)
```
Get all loans for a specific user.

#### `get-contract-stats`
```clarity
(get-contract-stats)
```
View platform-wide statistics.

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet configured
- NFT collection deployed

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/your-repo/NFT-Collateralized-Lending
cd NFT-Collateralized-Lending
```

2. **Install dependencies**
```bash
npm install
```

3. **Run tests**
```bash
npm test
```

4. **Deploy contract**
```bash
clarinet deploy
```

### 💡 Usage Example

```clarity
;; Create a loan with your NFT as collateral
(contract-call? .nft-lending create-loan .my-nft-collection u123 u1000000)

;; Check loan health
(contract-call? .nft-lending get-loan-health u1)

;; Repay loan to reclaim NFT
(contract-call? .nft-lending repay-loan u1)
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   NFT Owner     │    │   Borrower      │    │   Liquidator    │
└─────┬───────────┘    └─────┬───────────┘    └─────┬───────────┘
      │                      │                      │
      │ Lock NFT             │ Request Loan         │ Bid on NFT
      ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Smart Contract Vault                            │
├─────────────────┬─────────────────┬─────────────────────────────┤
│  Collateral     │   Loan Pool     │     Auction House           │
│  Management     │   Management    │     (Liquidations)          │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

## 📊 Risk Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| 🔒 Loan-to-Value Ratio | 75% | Maximum borrowable amount |
| 💸 Interest Rate | 5% | Annual interest on loans |
| ⏰ Loan Duration | 144 blocks | ~24 hours |
| 🚨 Liquidation Threshold | 75% | Health ratio trigger |
| 🔨 Auction Duration | 12 blocks | ~2 hours |

## 🔐 Security Features

- ✅ **Ownership Verification**: NFT ownership validated before loan creation
- ✅ **Reentrancy Protection**: Safe contract interactions
- ✅ **Oracle Integration**: Tamper-resistant price feeds
- ✅ **Emergency Controls**: Owner emergency withdrawal capabilities
- ✅ **Health Monitoring**: Continuous collateral ratio tracking

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♀️ Support

- 📧 Email: support@nft-lending.com
- 💬 Discord: [Join our community](https://discord.gg/nft-lending)
- 🐦 Twitter: [@NFTLending](https://twitter.com/NFTLending)

---

<div align="center">
  <p>🎨 <strong>Unlock the power of your NFTs</strong> 💎</p>
  <p>Built with ❤️ on Stacks blockchain</p>
</div>
