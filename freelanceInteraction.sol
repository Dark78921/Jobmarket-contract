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

interface JobInterface {
    function getJobPrice(uint256 _jobId) external view returns (uint256);

    function getJobOwner(uint256 _jobId) external view returns (address);
}

contract FreelanceInteraction is Ownable {
    SubInterface SubContract;
    JobInterface JobContract;

    uint256 public orderId;

    /**
     * @notice Container for Order data
     * @member client : Address that make order
     * @member freelancer : Address that client sent offer
     * @member requestNum : Number of amendments requested by clients
     * @member deadline : Date that clients want to complete this task
     * @member submitWorkTime : Date that freelacner submit his work
     * @member price : freelancer's budget for this task
     * @member description : specific info for this task
     * @member freelancerConfirm : Bool value indicating whether the freelancer has accepted the offer or not.
     * @member workStatus : Bool value indicating whether the freelancer has submitted his work to client or not
     * @member jobSuccess : Bool value indicating whether payment is done or not
     */

    struct order {
        address client;
        address freelancer;
        uint256 requestNum;
        uint256 deadline;
        uint256 submitWorkTime;
        uint256 price;
        string description;
        bool freelancerConfirm;
        bool workStatus;
        bool jobSuccess;
    }

    mapping(uint256 => order) public Orders;

    /**
     * @notice Constructor to initialize subscription and freelancerListing contract
     * @param subAddress Subscription contract address
     * @param jobAddress FreelancerListing contract address
     */

    constructor(address subAddress, address jobAddress) {
        SubContract = SubInterface(subAddress);
        JobContract = JobInterface(jobAddress);
    }

    /**
     * @notice function to create order by client
     * @param _jobId JobId that freelancer posted
     * @param _deadline deadline that client want for this task
     * @param _description specific info for this task
     */

    function openOrder(
        uint256 _jobId,
        uint256 _deadline,
        string memory _description
    ) external payable {
        address freelancer = JobContract.getJobOwner(_jobId);
        uint256 price = JobContract.getJobPrice(_jobId);
        require(
            SubContract.stillSubscribed(msg.sender) == true,
            "Not subscribed"
        );
        require(price <= msg.value, "Didn't send enough money");
        orderId++;
        Orders[orderId] = order(
            msg.sender,
            freelancer,
            0,
            _deadline,
            9999999999,
            price,
            _description,
            false,
            false,
            false
        );
    }

    /**
     * @notice function to return OrderId, must call this function after create Order
     */

    function returnOrderId() external view returns (uint256) {
        return orderId;
    }

    /**
     * @notice Via this function, freelancer accept an offer from client
     * @param _orderId OrderId that freelancer is going to accept
     */

    function acceptOrder(uint256 _orderId) external {
        require(
            Orders[_orderId].freelancer == msg.sender,
            "You can't accept this offer"
        );
        require(
            Orders[_orderId].freelancerConfirm == false,
            "Already Confirmed"
        );
        Orders[_orderId].freelancerConfirm = true;
    }

    /**
     * @notice Via this function, freelancer decline an offer from client
     * @param _orderId OrderId that freelancer is going to decline
     */

    function declineOrder(uint256 _orderId) external {
        require(
            Orders[_orderId].freelancer == msg.sender,
            "You can't accept this offer"
        );
        uint256 amount = Orders[_orderId].price;
        (bool result, ) = payable(msg.sender).call{value: amount}("");
        require(result, "Ether not sent successfully");
        Orders[_orderId].jobSuccess = true;
    }

    /**
     * @notice freelancer call this function when he submit product to client
     * @param _orderId OrderId that freelancer is going to submit
     */

    function submitWork(uint256 _orderId) external {
        require(
            Orders[_orderId].freelancer == msg.sender,
            "You don't need to submit"
        );
        require(
            Orders[_orderId].deadline >= block.timestamp,
            "Deadline missed"
        );
        require(
            Orders[_orderId].freelancerConfirm == true,
            "You didn't accept this offer"
        );
        require(Orders[_orderId].workStatus == false, "Already Submitted");
        Orders[_orderId].workStatus = true;
        Orders[_orderId].submitWorkTime = block.timestamp;
    }

    /**
     * @notice client call this function to pay him when he is satisfied with freelancer's work
     * @param _orderId OrderId that client is going to approve
     */

    function approveWork(uint256 _orderId) external {
        require(Orders[_orderId].client == msg.sender, "You are not Owner");
        require(Orders[_orderId].freelancerConfirm == true, "Already returned");
        uint256 amount = (Orders[_orderId].price * 96) / 100;
        (bool result, ) = payable(Orders[_orderId].freelancer).call{
            value: amount
        }("");
        require(result, "Ether not sent successfully");
        Orders[_orderId].jobSuccess = true;
    }

    /**
     * @notice client call this function when he is going to request revision.
     * @param _orderId OrderId that client is going to request
     */

    function requestRevision(uint256 _orderId) external {
        require(Orders[_orderId].client == msg.sender, "You are not Owner");
        require(Orders[_orderId].requestNum <= 3, "Can't request anymore");
        require(
            Orders[_orderId].submitWorkTime < block.timestamp,
            "Didn't finish project yet"
        );
        Orders[_orderId].requestNum++;
        Orders[_orderId].deadline = block.timestamp + 2 days;
        Orders[_orderId].workStatus = false;
    }

    /**
     * @notice freelancer call this function to get paid when client didn't reply to his work
     * @param _orderId OrderId that freelancer wants to get paid
     */

    function withdrawForFreelancer(uint256 _orderId) external {
        require(
            Orders[_orderId].freelancer == msg.sender,
            "You can't call this function"
        );
        require(
            Orders[_orderId].submitWorkTime + 3 days <= block.timestamp,
            "Can't withdraw yet"
        );
        require(
            Orders[_orderId].workStatus == true,
            "You didn't finish this offer"
        );
        require(
            Orders[_orderId].jobSuccess == false,
            "Order is already finished"
        );
        require(Orders[_orderId].workStatus == true, "Didn't finish job");
        uint256 amount = (Orders[_orderId].price * 96) / 100;
        (bool result, ) = payable(msg.sender).call{value: amount}("");
        require(result, "Ether not sent successfully");
        Orders[_orderId].jobSuccess = true;
    }

    /**
     * @notice client call this function to get his money back when freelancer didn't submit product on time
     * @param _orderId OrderId that freelancer wants to get paid
     */

    function withdrawForClinet(uint256 _orderId) external {
        require(
            Orders[_orderId].client == msg.sender,
            "You are not owner on this order"
        );
        require(
            Orders[_orderId].workStatus == false,
            "freelancer already completed task"
        );
        require(
            Orders[_orderId].jobSuccess == false,
            "Order is already finished"
        );
        uint256 amount = Orders[_orderId].price;
        (bool result, ) = payable(msg.sender).call{value: amount}("");
        require(result, "Ether not sent successfully");
        Orders[_orderId].jobSuccess = true;
    }

    /**
     * @notice function to edit order by owner
     * @param _orderId OrderId that owner is going to edit
     */

    function editOrder(
        uint256 _orderId,
        uint256 _price,
        string memory _description,
        bool _freelancerConfirm,
        bool _workStatus,
        bool _jobSuccess
    ) external onlyOwner {
        Orders[_orderId].price = _price;
        Orders[_orderId].description = _description;
        Orders[_orderId].freelancerConfirm = _freelancerConfirm;
        Orders[_orderId].workStatus = _workStatus;
        Orders[_orderId].jobSuccess = _jobSuccess;
    }
}
