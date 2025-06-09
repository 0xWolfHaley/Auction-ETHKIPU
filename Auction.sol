// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    /* 
    ======STATE VARIABLES======
    */

    // Address of the contract owner.
    address public owner;

    // Time when the auction ends.
    uint256 public auctionEndTime;

    // Current highest bid.
    uint256 public highestBid;

    // Address of the highest bidder.
    address public highestBidder;
    
    // Indicates if the auction was ended.
    bool public ended;

    /*
    ======CONSTANTS======
    */

    // Indicates a extension of time if the bid was placed in the last 10min.
    uint256 public constant EXTENSION_TIME = 10 minutes;

    // Indicates the percent of increment required for bid.
    uint256 public constant INCREMENT_PERCENT = 5;

    //Indicates the percent charged on the refunds.
    uint256 public constant COMMISSION_PERCENT = 2;

    /*
    ======STRUCTS======
    */ 

    // Structure of individual bids.
    struct Bid {
        address bidder; //Address of the bidder.
        uint256 amount; //Amount of the bid in wei.
        uint256 timestamp; //Time  when the bid was placed.
    }

    // Structure of an user specific information
    struct UserBid{
        uint256 bidAmount; //Amount of the bid in wei.
        uint256 timestamp; //Time  when the bid was placed.
    }

    /*
    ======ARRAYS AND MAPPINGS======
    */

    //Array of all bids placed in the auction.
    Bid[] public bids;

    // Array of all the bidders in the auction.
    address[] public allBidders;

    //Mapping to store all the bids of an user.
    mapping(address => UserBid[]) public userBids;

    // Mapping to store the total amount placed in the auction.
    mapping(address => uint256) public deposits;

    // Mapping to store the last bid of every bidder.
    mapping(address => Bid) public lastBids;

    // Mapping to comprobate if the user has bid.
    mapping(address => bool) private hasBid;

    // Mapping to store the total amount deposited by each user.
    mapping(address => uint256) public userTotalBids;

    /* 
    ======EVENTS======
    */

    //Emited when a new bid is placed.
    event NewBid(address indexed bidder, uint256 amount);

    //Emited when the auction was ended.
    event AuctionEnded(address winner, uint256 winningBid);

    //Emited when the deposits wans refunded.
    event RefundBids(address indexed beneficiary, uint256 amount);

    /*
    ======MODIFIERS======
    */

    // Restrinct the function only for the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner has the permission.");
        _;
    }

    //Restrinct the function only if the auction is active.
    modifier auctionActive() {
        require(!ended && block.timestamp < auctionEndTime, "La subasta no esta activa.");
        _;
    }

    //Restrinct the function only if the auction was ended.  
    modifier auctionEnded() {
        require(block.timestamp >= auctionEndTime || ended, "La subasta no ha finalizado.");
        _;
    }

    /* 
    ======CONSTRUCTOR======
    */

    constructor(uint256 _durationInMinutes) {
        require(_durationInMinutes > 0, "Duration must be greater than 0.");
        owner = payable(msg.sender);
        auctionEndTime = block.timestamp + (_durationInMinutes * 1 minutes);
    }

    /* 
    ======FUNCTIONS======
    */

    // Allows to place a bid.    
    function bid() external payable auctionActive {
        require(msg.value > 0, "Bid amount must be greater than zero");
        require(msg.value >= highestBid + ((highestBid * INCREMENT_PERCENT) / 100), "Bid must be at least 5% higher than current highest");

        // Linking bids to an user.
        userBids[msg.sender].push(UserBid({
            bidAmount: msg.value,
            timestamp: block.timestamp
        }));
        
        // Updating total user deposited amount.
        deposits[msg.sender] += msg.value;
        userTotalBids[msg.sender] += msg.value;

        // Adding new bids to the array of all bids.
        bids.push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        // Setting the highest bid and his bidder.
        highestBid = msg.value;
        highestBidder = msg.sender;

        // Verify if is necessary to add user to participants array
        if (!hasBid[msg.sender]) {
            allBidders.push(msg.sender);
            hasBid[msg.sender] = true;
        }

        // Implement time extension if applies
        if (auctionEndTime - block.timestamp < 10 minutes) {
            auctionEndTime = block.timestamp + EXTENSION_TIME;
        }

        // Notifies a new bid.
        emit NewBid(highestBidder, highestBid);
    }

    //If the auction time was ended, it notifies that the auction cannot be ended.
    function endAuction() public {
        require(block.timestamp >= auctionEndTime && !ended, "The auction cannot be ended.");
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    //  Shows the winner of the auction. Shows his address and the value of the winning bid.
    function auctionWinner() public view auctionEnded returns (address winner, uint256 winningBid) {
        return (highestBidder, highestBid);
    }

    // Shows the bidders and his bids amounts.
    function showBids() public view returns (address[] memory bidders, uint256[] memory amounts) {
        uint256 bidCount = bids.length;
        bidders = new address[](bidCount);
        amounts = new uint256[](bidCount);

        for (uint i = 0; i < bidCount; i++) {
            bidders[i] = bids[i].bidder;
            amounts[i] = bids[i].amount;
        }
        return (bidders, amounts);
    }

    //Allows the bidders to take out his deposits without the fee of 2%.
    function returnDeposits() public auctionEnded {

        // Checks if the sender participate in the auction.
        require(hasBid[msg.sender], "You did not place a bid.");

        // Checks if the sender was the winner.
        require(msg.sender != highestBidder, "The winner cannot withdraw a losers refund.");

        // Checks if the sender has deposits to withdraw. 
        uint256 amountToRefund = deposits[msg.sender];
        require(amountToRefund > 0, "You don't have deposits to withdraw.");

        // Discounts the commission percentage of the bid.
        uint256 commission = (amountToRefund * COMMISSION_PERCENT) / 100;
        uint256 netRefund = amountToRefund - commission;

        // Resets the deposits of the senders to avoid reentrancy.
        deposits[msg.sender] = 0;

        // Transfers the ethers to the bidder.
        (bool success, ) = payable (msg.sender).call{value: netRefund}("");
        require(success, "Transfer failed.");

        emit RefundBids(msg.sender, netRefund);
    }

    //Allows the bidders to withdraw his previous deposits during the auction. 
    function partialWithdrawal() public auctionActive {

        // The amount of the current deposit.
        uint256 currentDeposit = deposits[msg.sender];

        // The amount of his last bid.
        uint256 lastBidAmount = lastBids[msg.sender].amount;

        // Checks if the deposit is the more than the last bid.
        require(currentDeposit > lastBidAmount, "There aren't deposits to withdraw.");

        // Calculate the total amount to withdraw.
        uint256 amountToWithdraw = currentDeposit - lastBidAmount;

        // Set the users deposits to prevent reentrancy.
        deposits[msg.sender] = lastBidAmount;

        // Withdraws the excedent.
        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Failed to withdraw.");
    }
}