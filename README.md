# Decentralized Research Platform

A comprehensive blockchain-based platform for managing scientific research lifecycle from proposal funding to publication, built on the Stacks blockchain using Clarity smart contracts.

## Overview

This platform consists of five interconnected smart contracts that facilitate transparent, decentralized scientific research:

### Core Contracts

1. **Research Proposal Funding Contract** (`research-funding.clar`)
    - Crowdfunding mechanism for scientific studies
    - Milestone-based fund release
    - Community voting on proposals

2. **Peer Review Coordination Contract** (`peer-review.clar`)
    - Academic paper evaluation system
    - Reviewer assignment and compensation
    - Quality scoring and consensus mechanisms

3. **Data Sharing Agreement Contract** (`data-sharing.clar`)
    - Secure research collaboration framework
    - Access control and usage tracking
    - Compensation for data providers

4. **Publication Rights Contract** (`publication-rights.clar`)
    - Academic journal submission management
    - Author rights and attribution
    - Revenue sharing for publications

5. **Research Integrity Contract** (`research-integrity.clar`)
    - Ethical standards compliance
    - Misconduct reporting and resolution
    - Researcher reputation system

## Features

### Research Funding
- Create funding proposals with detailed research plans
- Community-driven funding through STX contributions
- Milestone-based fund release system
- Transparent fund allocation and usage tracking

### Peer Review System
- Decentralized paper submission and review process
- Anonymous reviewer assignment
- Consensus-based acceptance/rejection decisions
- Reviewer incentivization through token rewards

### Data Collaboration
- Secure data sharing agreements between researchers
- Access control with time-limited permissions
- Usage tracking and audit trails
- Fair compensation for data providers

### Publication Management
- Decentralized journal submission system
- Author attribution and rights management
- Revenue sharing from publication fees
- Open access publication support

### Research Integrity
- Ethical compliance verification
- Misconduct reporting mechanisms
- Researcher reputation scoring
- Community-driven integrity enforcement

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for interactions

### Installation

\`\`\`bash
git clone <repository-url>
cd decentralized-research-platform
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy
\`\`\`

## Contract Architecture

### Data Structures

Each contract uses optimized data structures for gas efficiency:
- Maps for storing entity relationships
- Variables for global state management
- Lists for ordered data collections

### Error Handling

Comprehensive error codes for all failure scenarios:
- Input validation errors
- Permission and authorization errors
- State transition errors
- Resource availability errors

### Security Features

- Access control mechanisms
- Input validation and sanitization
- Reentrancy protection
- Integer overflow protection

## Usage Examples

### Creating a Research Proposal

\`\`\`clarity
(contract-call? .research-funding create-proposal
"Climate Change Impact Study"
"Comprehensive analysis of climate change effects on biodiversity"
u1000000 ;; 1000 STX funding goal
u30 ;; 30 day funding period
)
\`\`\`

### Submitting for Peer Review

\`\`\`clarity
(contract-call? .peer-review submit-paper
"paper-hash-123"
"Revolutionary Quantum Computing Algorithm"
"Computer Science"
)
\`\`\`

### Creating Data Sharing Agreement

\`\`\`clarity
(contract-call? .data-sharing create-agreement
'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
"climate-data-2024"
u365 ;; 365 day access period
u50000 ;; 50 STX compensation
)
\`\`\`

## Testing

The platform includes comprehensive test suites for all contracts:
- Unit tests for individual functions
- Integration tests for cross-contract interactions
- Edge case and error condition testing
- Gas optimization verification

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For questions and support, please open an issue in the repository.
