# Web3Lancer Sui Move Contracts 🚀

> Modular, robust smart contracts powering the Web3Lancer decentralized freelancing platform on Sui blockchain

## 📋 Overview

This repository contains the complete suite of Sui Move smart contracts for Web3Lancer, a decentralized marketplace connecting global talent with Web3 opportunities. The contracts are designed with modularity, security, and gas efficiency in mind.

## 🏗️ Contract Architecture

### Core Modules

#### 1. **User Profile Management** (`user_profile.move`)
- **Purpose**: Manages freelancer and client profiles with reputation tracking
- **Key Features**:
  - Profile creation and updates
  - Skill and portfolio management
  - Reputation scoring system
  - Profile verification mechanism
  - Admin capabilities for verification

#### 2. **Project Management** (`project_management.move`)
- **Purpose**: Handles project lifecycle, escrow, and milestone tracking
- **Key Features**:
  - Project creation with milestone-based structure
  - Secure escrow system with SUI tokens
  - Automated payment releases upon milestone approval
  - Platform fee collection (2.5% default)
  - Dispute initiation and tracking
  - Multi-status project management

#### 3. **Reputation System** (`reputation_system.move`)
- **Purpose**: Comprehensive review and badge system for trust building
- **Key Features**:
  - Multi-dimensional rating system (skills, communication, timeliness, quality)
  - Automated badge awarding based on achievements
  - Skill verification by peers and completed projects
  - Review dispute mechanism
  - Platform-wide reputation analytics

#### 4. **Messaging System** (`messaging_system.move`)
- **Purpose**: Secure communication and notification infrastructure
- **Key Features**:
  - Project-based and general conversations
  - Message threading and reply functionality
  - File sharing capabilities
  - Read receipt tracking
  - System notifications
  - Conversation archiving

## 🚀 Quick Start

### Prerequisites
- Sui CLI installed and configured
- Sui wallet set up
- Basic understanding of Move programming language

### Building the Contracts

```bash
# Clone the repository
git clone https://github.com/web3lancer/suicontract.git
cd suicontract

# Build the contracts
sui move build

# Run tests
sui move test

# Deploy to testnet
sui client publish --gas-budget 100000000
```

### Contract Addresses (Testnet)

- **Package ID:** `0x1338a3eb832f3d71f34f9f0ac2637367228219a591e68ee46add2192e547c881`
- **UserProfile Registry:** `0x39e0aaf986265e1c2657232a597555c8632014239cfcad3496912edcd38203cf`
- **ProjectRegistry:** `0x4e9112b5dce9a53cefa48a039b66308bf8554ad982715215bce12436b1d7a17b`
- **ReputationRegistry:** `0xe00f9e6b48f1a2079c320e8017112ae3caa698aee06e0d08534e719cdd5e8c2e`
- **MessagingRegistry:** `0x04c4c65442c14df15ab1a27ffc0d8ac2ff74a77764871d68802c38cf5bd6636d`

## 📖 Usage Examples

### Creating a User Profile

```bash
sui client call \
  --package $PACKAGE_ID \
  --module user_profile \
  --function create_profile \
  --args $REGISTRY_ID \"john_doe\" \"john@example.com\" \"Experienced Web3 developer\" 50000 \
  --gas-budget 10000000
```

### Creating a Project

```bash
sui client call \
  --package $PACKAGE_ID \
  --module project_management \
  --function create_project \
  --args $REGISTRY_ID \"Build DeFi Dashboard\" \"Create a comprehensive DeFi analytics dashboard\" $PAYMENT_COIN \
  --gas-budget 20000000
```

### Submitting a Review

```bash
sui client call \
  --package $PACKAGE_ID \
  --module reputation_system \
  --function submit_review \
  --args $REGISTRY_ID $PROJECT_ID $REVIEWEE_ADDRESS 5 \"Excellent work!\" 5 5 5 5 true \
  --gas-budget 15000000
```

## 🔒 Security Features

### Access Control
- Owner-only functions for profile and project management
- Participant verification for conversations and reviews
- Admin capabilities with proper capability-based security

### Economic Security
- Escrow system prevents payment fraud
- Platform fee mechanism ensures sustainability
- Reputation staking discourages malicious behavior

### Data Integrity
- Immutable review and project history
- Timestamped records for all actions
- Event emission for off-chain tracking

## 🎯 Key Benefits

### For Developers
- **Modular Design**: Each contract can be upgraded independently
- **Gas Optimized**: Efficient data structures and minimal storage
- **Event-Driven**: Comprehensive event system for dApp integration
- **Type Safety**: Leverages Move's type system for bug prevention

### For Users
- **Transparency**: All transactions and reviews are on-chain
- **Security**: Funds held in secure escrow until milestone completion
- **Global Access**: Borderless platform with instant settlements
- **Reputation Portability**: Reviews and badges follow users across projects

## 🧪 Testing

The contracts include comprehensive test suites covering:

- Profile creation and management
- Project lifecycle scenarios
- Escrow and payment flows
- Review submission and disputes
- Messaging functionality

```bash
# Run all tests
sui move test

# Run specific test module
sui move test --filter user_profile_tests
```

## 📊 Contract Statistics

### Gas Costs (Testnet)
- Profile Creation: ~1.2M gas units
- Project Creation: ~2.5M gas units
- Review Submission: ~1.8M gas units
- Message Sending: ~0.8M gas units

### Storage Efficiency
- Profile Object: ~500 bytes
- Project Object: ~1.2KB (varies with milestones)
- Review Object: ~400 bytes
- Message Object: ~200 bytes

## 🔮 Future Enhancements

### Planned Features
- Cross-chain integration with LayerZero
- Integration with Lens Protocol for social features
- Advanced dispute resolution with DAO governance
- Tokenized reputation system
- Subscription-based premium features

### Optimization Roadmap
- Batch operations for gas efficiency
- State compression for large datasets
- Progressive decentralization mechanisms

## 🤝 Contributing

We welcome contributions to improve the Web3Lancer contract suite:

1. Fork the repository
2. Create a feature branch
3. Write comprehensive tests
4. Submit a pull request with detailed description

### Development Guidelines
- Follow Move coding conventions
- Include detailed comments
- Write unit tests for all functions
- Optimize for gas efficiency
- Maintain backward compatibility

## 📜 License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0), ensuring the software remains open source even when used to provide network services.

## 🔗 Resources

- [Sui Documentation](https://docs.sui.io/)
- [Move Programming Language](https://move-language.github.io/move/)
- [Web3Lancer Platform](https://web3lancer.com)
- [Community Discord](https://discord.gg/web3lancer)

---

## 🌟 Main Repository

For the complete Web3Lancer platform including the frontend application, API, and documentation, visit our main repository:

**[🏠 Web3Lancer Main Repository](https://github.com/web3lancer/web3lancer)**

---

<p align="center">
  <i>Building the future of decentralized work, one smart contract at a time. 🌍✨</i>
</p>