//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./Equity.sol";

contract List {
    using Chainlink for Chainlink.Request;

    struct RemovedEmployee {
        uint256 timeWhenRemoved;
        IEquity.Currency[] currencies;
    }

    address public oracle;
    uint256 public unlockTime;

    address public owner;
    IEquity.Employee[] public list;
    IEquity public equity;
    //this mapping stores an address only for 30 days
    mapping(address => RemovedEmployee) public removedEmployees;

    constructor() {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner is able to call this function");
        _;
    }
    function setEquityContract(address contractAddress) public onlyOwner {
        //checking if the equity contract is already set
        require(address(equity) == address(0), "The equity contract is already set");
        equity = IEquity(contractAddress);
    }
    //this function should be called only once in a round
    function addList(IEquity.Employee[] memory _list) public onlyOwner {
        require(list.length == 0, "You can set this only once");
        unlockTime = SafeMath.add(block.timestamp, 365 days);
        list = _list;
    }
    //only the oracle is able to call this function
    function remove(address employee) public onlyOwner {
        for(uint256 i = 0; i < list.length; i++) {
            if(list[i].employee == employee) {
                //this leaves a gap in the array
                removedEmployees[employee] = RemovedEmployee(
                    block.timestamp, list[i].currencies
                );
                delete list[i];
            }
        } 
    }
    function returnRemoved(address employee) public onlyOwner {
        require(removedEmployees[employee].timeWhenRemoved + 30 days > block.timestamp,
        "You are not able to return the employee anymore");
        list.push(IEquity.Employee(employee, removedEmployees[employee].currencies));
        delete removedEmployees[employee];
    }
    function sendList() public {
        require(block.timestamp > unlockTime, "You are not able to send the list yet");
        equity.setList(list);
        delete list;
    }
}