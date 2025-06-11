// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Auction Contract
 * @notice Implements a secure auction system with time extensions, bid increments, and commission fees
 * @dev All function calls are currently implemented without side effects
 */
contract Auction {
    /* ====== STATE VARIABLES ====== */
    address public owner;
    uint256 public objectValue;
    uint256 public auctionEndTime;
    uint256 public highestBid;
    address public highestBidder;
    bool public ended;
    bool public paused;

    /* ====== CONSTANTS ====== */
    uint256 public constant EXTENSION_TIME = 10 minutes;
    uint256 public constant INCREMENT_PERCENT = 5;
    uint256 public constant COMMISSION_PERCENT = 2;

    /* ====== STRUCTS ====== */
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    struct UserBid {
        uint256 amount;
        uint256 timestamp;
    }

    /* ====== MAPPINGS & ARRAYS ====== */
    Bid[] public bids;
    address[] public bidders;
    mapping(address => UserBid[]) public userBids;
    mapping(address => uint256) public deposits;
    mapping(address => Bid) public lastBid;
    mapping(address => bool) private hasBid;

    /* ====== EVENTS ====== */
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event Refund(address indexed bidder, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event Paused(bool status);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    /* ====== MODIFIERS ====== */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenActive() {
        require(!ended, "Auction ended");
        require(!paused, "Auction paused");
        require(block.timestamp < auctionEndTime, "Auction expired");
        _;
    }

    modifier whenEnded() {
        require(ended || block.timestamp >= auctionEndTime, "Not ended");
        _;
    }

    /* ====== CONSTRUCTOR ====== */
    /**
     * @notice Initialize auction with duration and initial value
     * @param _durationInMinutes Auction duration in minutes
     * @param _initialValue Initial value of the auctioned item
     */
    constructor(uint256 _durationInMinutes, uint256 _initialValue) {
        require(_durationInMinutes > 0, "Invalid duration");
        owner = msg.sender;
        objectValue = _initialValue;
        auctionEndTime = block.timestamp + (_durationInMinutes * 1 minutes);
    }

    /* ====== BID FUNCTIONS ====== */
    /**
     * @notice Place a new bid
     * @dev Bid must be 5% higher than current highest
     */
    function bid() external payable whenActive {
        require(msg.value > 0, "Zero bid");
        require(msg.value >= _minBid(), "Bid too low");

        // State changes (1 read + 1 write per state var)
        uint256 currentBid = msg.value;
        address bidder = msg.sender;
        
        // Update last bid
        lastBid[bidder] = Bid(bidder, currentBid, block.timestamp);

        // Track bid
        userBids[bidder].push(UserBid(currentBid, block.timestamp));
        bids.push(Bid(bidder, currentBid, block.timestamp));
        deposits[bidder] += currentBid;

        // Update highest bid
        highestBid = currentBid;
        highestBidder = bidder;

        // Add to bidders if first time
        if (!hasBid[bidder]) {
            bidders.push(bidder);
            hasBid[bidder] = true;
        }

        // Extend auction if needed
        if (auctionEndTime - block.timestamp < EXTENSION_TIME) {
            auctionEndTime = block.timestamp + EXTENSION_TIME;
        }

        emit BidPlaced(bidder, currentBid);
    }

    /**
     * @notice Calculate minimum required bid
     * @return Minimum bid amount
     */
    function _minBid() private view returns (uint256) {
        return highestBid + ((highestBid * INCREMENT_PERCENT) / 100);
    }

    /* ====== AUCTION MANAGEMENT ====== */
    /**
     * @notice End the auction manually
     * @dev Only callable by owner after end time
     */
    function endAuction() external onlyOwner whenEnded {
        require(!ended, "Already ended");
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    /**
     * @notice Pause/unpause the auction
     * @param _paused True to pause, false to unpause
     */
    function setPaused(bool _paused) external onlyOwner {
        require(paused != _paused, "No change");
        paused = _paused;
        emit Paused(_paused);
    }

    /* ====== WITHDRAWAL FUNCTIONS ====== */
    /**
     * @notice Withdraw auction proceeds (owner only)
     * @param _amount Amount to withdraw
     */
    function withdraw(uint256 _amount) external onlyOwner whenEnded {
        require(_amount > 0 && _amount <= address(this).balance, "Invalid amount");
        payable(owner).transfer(_amount);
        emit Withdraw(owner, _amount);
    }

    /**
     * @notice Emergency ETH recovery (owner only)
     * @dev Only for stuck ETH, not auction funds
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(_amount > 0 && _amount <= address(this).balance, "Invalid amount");
        payable(owner).transfer(_amount);
        emit EmergencyWithdraw(owner, _amount);
    }

    /**
     * @notice Withdraw excess deposit (partial)
     * @param _amount Amount to withdraw
     */
    function withdrawExcess(uint256 _amount) external whenActive {
        require(_amount > 0, "Zero amount");
        
        uint256 available = deposits[msg.sender] - lastBid[msg.sender].amount;
        require(_amount <= available, "Amount too high");

        deposits[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit Refund(msg.sender, _amount);
    }

    /**
     * @notice Claim refund after auction ends
     */
    function claimRefund() external whenEnded {
        require(msg.sender != highestBidder, "Winner can't refund");
        
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No deposit");

        deposits[msg.sender] = 0;
        uint256 fee = (amount * COMMISSION_PERCENT) / 100;
        payable(msg.sender).transfer(amount - fee);
        emit Refund(msg.sender, amount - fee);
    }

    /* ====== VIEW FUNCTIONS ====== */
    /**
     * @notice Get auction winner info
     * @return winner Address of winner
     * @return amount Winning bid amount
     */
    function getWinner() external view whenEnded returns (address winner, uint256 amount) {
        return (highestBidder, highestBid);
    }

    /**
     * @notice Get all bids
     * @return All bids in auction
     */
    function getAllBids() external view returns (Bid[] memory) {
        return bids;
    }

    /**
     * @notice Get user's bids
     * @param _bidder User address
     * @return User's bids
     */
    function getUserBids(address _bidder) external view returns (UserBid[] memory) {
        return userBids[_bidder];
    }

    /**
     * @notice Get all bidders
     * @return List of all bidders
     */
    function getAllBidders() external view returns (address[] memory) {
        return bidders;
    }
}
