# 📜 Auction Smart Contract
This is part of a Eth Kipu blockchain development course assignment. It's a smart contract to create an auction system on the Ethereum blockchain.

# 📝 Overview

This Solidity smart contract facilitates a bidding process where users can place bids within a defined time frame. It includes advanced features such as automatic time extensions, refunds with commission deductions, and secure deposit management.

# ⚙️ Key Features

📌 Minimum bid increment: Every new bid must be at least 5% higher than the current highest bid.

⏳ Automatic time extension: If a bid is placed within the last 10 minutes of the auction, the deadline is extended.

💰 Refund mechanism: Participants can withdraw their deposits, subject to a 2% fee.

🔐 Access controls: Modifiers regulate contract execution to ensure integrity.

# 🚀 Implementation Details

Built on Solidity 0.8.0, this contract leverages mappings, structs, and arrays for efficient data handling. It prioritizes security by mitigating overflow risks and enforcing proper bid validations.

# 🔄 State Variables

The contract includes several key variables that store auction-related data:

1. **General Variables**
- **`owner (address)`** Stores the contract owner's address.

- **`objectValue (address)`** Value of the auctions object.

- **`auctionEndTime (uint256)`** Timestamp indicating when the auction ends.

- **`highestBid (uint256)`** Current highest bid amount.

- **`highestBidder (address)`** Address of the highest bidder.

- **`ended (bool)`** Whether the auction has ended.

2. **Constants**
- **`EXTENSION_TIME (uint256)`** Auction time extension (10 minutes).

- **`INCREMENT_PERCENT (uint256)`** Minimum bid increment percentage (5%).

- **`COMMISSION_PERCENT (uint256)`** Refund commission percentage (2%).

3. **Mappings and Structs**
- **`userBids (mapping(address => UserBid[]))`** Tracks all bids placed by a user.

- **`deposits (mapping(address => uint256))`** Stores total deposit amounts per user.

- **`lastBids (mapping(address => Bid))`** Keeps record of users’ latest bids.

- **`hasBid (mapping(address => bool))`** Checks whether a user has bid.

- **`userTotalBids (mapping(address => uint256))`** Stores total bid amounts per user.

# 🎟️ Events

The contract emits events to notify external applications about important actions:

- **`NewBid(address indexed bidder, uint256 amount)`** Emitted when a new bid is placed.

- **`AuctionEnded(address winner, uint256 winningBid)`** Emitted when the auction ends, declaring a winner.

- **`RefundBids(address indexed beneficiary, uint256 amount)`** Emitted when refunds are processed for bidders who did not win.

# 🔍 Core Functions 

1. **🔄 Bid Management**

**`bid()`**

  - Places a new bid in the auction

  - **Requires:**

    - Bid value ≥ current highest + 5%

    - Auction must be active

  - **Emits:** **`BidPlaced`**

**`_minBid() private view → (uint256)`**

  - Calculates minimum acceptable bid

  - **Returns:** Minimum bid amount (current highest + 5%)

2. **⏹️ Auction Control**

**`endAuction()`**

  - Officially ends auction and distributes winning bid

  - **Requires:**

    - Owner only

    - Auction time expired

  - **Emits:** **`AuctionEnded`**

**`refundAllNonWinners()`**

  - Processes refunds for all non-winning bidders (minus 2% fee)

  - **Emits:** **`Refund for each processed bid`**

3. **💰 Withdrawals**
    
**`withdrawExcess(uint256 _amount)`**

  - Allows partial withdrawal of excess funds during auction

  - **Parameters:**

    - **`_amount: Amount to withdraw`**

**`claimRefund()`**

  - Lets non-winning bidders claim refund after auction ends

  - **Deducts:** 2% commission fee

4. **👑 Owner Functions**
   
**`setPaused(bool _paused)`**

  - Pauses/unpauses the auction

  - **Emits:** **`Paused`**

**`emergencyWithdraw(uint256 _amount)`**

  - Owner-only emergency ETH recovery

  - **For:** Stuck funds only

5. **🔍 View Functions**
**`getWinner() → (address winner, uint256 amount)`**

  - Returns auction winner information

**`getAllBids() → (Bid[] memory)`**

  - Returns complete bid history

**`getUserBids(address _bidder) → (UserBid[] memory)`**

  - Returns specific user's bid history

**`getAllBidders() → (address[] memory)`**

  -Returns list of all participants

# 📜 License
This contract is licensed under MIT.
