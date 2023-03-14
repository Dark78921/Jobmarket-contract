//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface SubInterface {
    function stillSubscribed(address _address) external view returns (bool);
}

contract RecruiterListing is Ownable {
    SubInterface SubContract;

    mapping(uint256 => uint256) jobListingFee;

    uint256 public jobIds;

    struct jobDetail {
        string title;
        string description;
        uint256 jobPrice;
        uint256 startTime;
        uint256 endDate;
        address owner;
        bool jobState;
    }

    /// @notice mapping with Jobdetails and jobId

    mapping(uint256 => jobDetail) public JobDetails;

    /**
     * @notice Constructor to initialize ERC721A, grants default admin role to contract deployer
     * @param subAddress array of addresses to grant admin role to
     */

    constructor(
        address subAddress,
        uint256 Fee7,
        uint256 Fee14,
        uint256 Fee30
    ) {
        SubContract = SubInterface(subAddress);
        jobListingFee[7] = Fee7;
        jobListingFee[14] = Fee14;
        jobListingFee[30] = Fee30;
    }

    /**
     * @notice function to post job payable
     * @param _title title of job that user post
     * @param _description description of job that user post
     * @param _price budget of job that user post
     * @param _period duration that job is on active
     */

    function postJob(
        string memory _title,
        string memory _description,
        uint256 _price,
        uint256 _period
    ) external payable {
        require(jobListingFee[_period] > 0, "Invalid period");
        require(
            jobListingFee[_period] <= msg.value,
            "Did not send enough amount"
        );
        require(
            SubContract.stillSubscribed(msg.sender) == true,
            "Not subscribed"
        );
        uint256 endDate = block.timestamp + (_period * 86400);
        jobIds++;
        JobDetails[jobIds] = jobDetail(
            _title,
            _description,
            _price,
            block.timestamp,
            endDate,
            msg.sender,
            true
        );
    }

    /**
     * @notice function to get JobId after post job...must call this function after post Job
     */

    function returnJobId() public view returns (uint256) {
        return jobIds;
    }

    function getJobPrice(uint256 _jobId) external view returns (uint256) {
        return JobDetails[_jobId].jobPrice;
    }

    function getJobOwner(uint256 _jobId) external view returns (address) {
        return JobDetails[_jobId].owner;
    }

    function getEndDate(uint256 _jobId) external view returns (uint256) {
        return JobDetails[_jobId].endDate;
    }

    function getJobState(uint256 _jobId) external view returns (bool) {
        return JobDetails[_jobId].jobState;
    }

    /**
     * @notice function to extend duration of their job listing : payable
     * @param _jobId jobId that user is going to extend duration
     * @param _period duration that user is going to extend
     */

    function extendDuration(uint256 _jobId, uint256 _period) external payable {
        require(
            JobDetails[_jobId].endDate > block.timestamp,
            "Already finished"
        );
        require(
            jobListingFee[_period] <= msg.value,
            "Did not send enough amount"
        );
        uint256 date = JobDetails[_jobId].endDate + (_period * 86400);
        JobDetails[_jobId].endDate = date;
    }

    /**
     * @notice function to cancel job : only job's owner and project owner can call
     * @param _jobId jobId that user is going to cancel
     */

    function endJobPosting(uint256 _jobId) external {
        require(
            JobDetails[_jobId].endDate > block.timestamp,
            "Already finished"
        );
        require(
            JobDetails[_jobId].owner == msg.sender || owner() == msg.sender,
            "You are not Owner"
        );
        JobDetails[_jobId].endDate = block.timestamp;
    }

    /**
     * @notice  Return function which returns details of specific job
     * @param _jobId jobId that user is going to know
     */

    function getJob(uint256 _jobId) external view returns (jobDetail memory) {
        return JobDetails[_jobId];
    }

    /**
     * @notice  Return function which returns Active state of specific job
     * @param _jobId jobId that user is going to know
     */

    function stillListed(uint256 _jobId) external view returns (bool) {
        if (JobDetails[_jobId].endDate > block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice   Return function which returns mapping of active job listings within certain time period
     */

    function getNewJobs(uint256 from, uint256 to)
        external
        view
        returns (uint256)
    {
        uint256 Num;
        for (uint256 i = 1; i <= jobIds; i++) {
            if (
                JobDetails[i].startTime > from && JobDetails[i].startTime < to
            ) {
                Num++;
            }
        }
        return Num;
    }

    function updateJob(
        uint256 _jobId,
        string memory _title,
        string memory _description,
        uint256 _price
    ) external {
        require(
            JobDetails[_jobId].owner == msg.sender || msg.sender == owner(),
            "Can't update"
        );
        JobDetails[jobIds].title = _title;
        JobDetails[jobIds].description = _description;
        JobDetails[jobIds].jobPrice = _price;
    }

    function closeJob(uint256 _jobId) external {
        require(
            JobDetails[_jobId].owner == msg.sender || msg.sender == owner(),
            "Can't close"
        );
        JobDetails[jobIds].jobState = false;
    }
}
