//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Interface from Subscription contract
 */

interface SubInterface {
    function stillSubscribed(address _address) external view returns (bool);
}

/**
 * @notice Interface from FreelancerListing contract
 */

interface RecruiterInterface {
    function getJobPrice(uint256 _jobId) external view returns (uint256);

    function getJobOwner(uint256 _jobId) external view returns (address);

    function getEndDate(uint256 _jobId) external view returns (uint256);

    function getJobState(uint256 _jobId) external view returns (bool);
}

contract RecruiterInteraction is Ownable {
    SubInterface SubContract;
    RecruiterInterface RecruiterContract;

    struct bid {
        uint256 jobId;
        address freelancer;
        uint256 bidPrice;
    }

    mapping(uint256 => bid) BidInfo;
    uint256 public bidId;

    struct AllBids {
        uint256[] Ids;
    }

    mapping(uint256 => AllBids) AllBidIds;

    struct order {
        address client;
        address freelancer;
        uint256 requestNum;
        uint256 deadline;
        uint256 submitWorkTime;
        uint256 price;
        bool workStatus;
        bool jobSuccess;
    }

    mapping(uint256 => order) OrderInfo;
    uint256 public orderId;

    constructor(address subAddress, address recruiterAddress) {
        SubContract = SubInterface(subAddress);
        RecruiterContract = RecruiterInterface(recruiterAddress);
    }

    // freelancer bid part

    function bidToJob(uint256 _jobId, uint256 _bidPrice) external {
        uint256 price = RecruiterContract.getJobPrice(_jobId);
        bool jobState = RecruiterContract.getJobState(_jobId);
        require(
            SubContract.stillSubscribed(msg.sender) == true,
            "Not subscribed"
        );
        require(jobState == true, "Job already closed");
        require(price <= _bidPrice, "you can't bid with that budget");
        bidId++;
        BidInfo[bidId] = bid(_jobId, msg.sender, _bidPrice);
        AllBidIds[_jobId].Ids.push(bidId);
    }

    function getBidId() external view returns (uint256) {
        return bidId;
    }

    function getAllBids(uint256 _jobId) external view returns (AllBids memory) {
        return AllBidIds[_jobId];
    }

    function selectFreelancer(uint256 _bidId) external payable {
        uint256 jobId = BidInfo[_bidId].jobId;
        address client = RecruiterContract.getJobOwner(jobId);
        uint256 deadline = RecruiterContract.getEndDate(jobId);
        uint256 price = BidInfo[_bidId].bidPrice;
        address freelancer = BidInfo[_bidId].freelancer;
        require(client == msg.sender, "You are not Owner of this job");
        require(
            SubContract.stillSubscribed(msg.sender) == true,
            "Not subscribed"
        );
        require(msg.value >= price, "You didn't send enough money");
        orderId++;
        OrderInfo[orderId] = order(
            msg.sender,
            freelancer,
            0,
            deadline,
            9999999999,
            price,
            false,
            false
        );
    }

    function getOrderId() external view returns (uint256) {
        return orderId;
    }

    function submitWork(uint256 _orderId) external {
        require(
            OrderInfo[_orderId].freelancer == msg.sender,
            "You can't submit"
        );
        require(
            OrderInfo[_orderId].deadline >= block.timestamp,
            "Deadline missed"
        );
        require(OrderInfo[_orderId].workStatus == false, "Already Submitted");
        OrderInfo[_orderId].workStatus = true;
        OrderInfo[_orderId].submitWorkTime = block.timestamp;
    }

    function requestRevision(uint256 _orderId) external {
        require(OrderInfo[_orderId].client == msg.sender, "You are not Owner");
        require(OrderInfo[_orderId].requestNum <= 3, "Can't request anymore");
        require(
            OrderInfo[_orderId].submitWorkTime < block.timestamp,
            "Didn't finish project yet"
        );
        OrderInfo[_orderId].requestNum++;
        OrderInfo[_orderId].deadline = block.timestamp + 2 days;
        OrderInfo[_orderId].workStatus = false;
    }

    function withdrawForFreelancer(uint256 _orderId) external {
        require(
            OrderInfo[_orderId].freelancer == msg.sender,
            "You can't call this function"
        );
        require(
            OrderInfo[_orderId].submitWorkTime + 3 days <= block.timestamp,
            "Can't withdraw yet"
        );
        require(
            OrderInfo[_orderId].workStatus == true,
            "You didn't finish this offer"
        );
        require(
            OrderInfo[_orderId].jobSuccess == false,
            "Order is already finished"
        );
        require(OrderInfo[_orderId].workStatus == true, "Didn't finish job");
        uint256 amount = (OrderInfo[_orderId].price * 96) / 100;
        (bool result, ) = payable(msg.sender).call{value: amount}("");
        require(result, "Ether not sent successfully");
        OrderInfo[_orderId].jobSuccess = true;
    }

    function withdrawForClinet(uint256 _orderId) external {
        require(
            OrderInfo[_orderId].client == msg.sender,
            "You are not owner on this order"
        );
        require(
            OrderInfo[_orderId].workStatus == false,
            "freelancer already completed task"
        );
        require(
            OrderInfo[_orderId].jobSuccess == false,
            "Order is already finished"
        );
        uint256 amount = OrderInfo[_orderId].price;
        (bool result, ) = payable(msg.sender).call{value: amount}("");
        require(result, "Ether not sent successfully");
        OrderInfo[_orderId].jobSuccess = true;
    }

    function editOrder(
        uint256 _orderId,
        uint256 _deadline,
        bool _workStatus,
        bool _jobSuccess
    ) external onlyOwner {
        OrderInfo[_orderId].deadline = _deadline;

        OrderInfo[_orderId].workStatus = _workStatus;
        OrderInfo[_orderId].jobSuccess = _jobSuccess;
    }
}
