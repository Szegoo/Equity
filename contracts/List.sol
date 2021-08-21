//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/KeeperCompatibleInterface.sol";
import "./Equity.sol";

contract List is KeeperCompatibleInterface {
    struct RemovedEmployee {
        address employee;
        uint256 timeWhenRemoved;
        IEquity.Currency[] currencies;
    }

    address public oracle;
    uint256 public unlockTime;

    address public owner;
    IEquity.Employee[] public list;
    IEquity public equity;
    //this mapping stores an address only for 30 days
    RemovedEmployee[] public removedEmployees;

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
        require(address(equity) != address(0), "Set the Equity contract address before calling this function");
        unlockTime = SafeMath.add(block.timestamp, 365 days);
        for(uint i = 0; i < _list.length; i++) {
            list.push(_list[i]);
        }
    } 
    function checkUpkeep(bytes calldata) external override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = block.timestamp > unlockTime;
    }
    function performUpkeep(bytes calldata) external override {
        equity.setList(list);
        delete list;
    }
    //only the oracle is able to call this function
    function remove(address employee) public onlyOwner {
        for(uint256 i = 0; i < list.length; i++) {
            if(list[i].employee == employee) {
                //this leaves a gap in the array
                removedEmployees[removedEmployees.length+1].employee = employee; 
                for(uint256 k = 0; k < list[i].currencies.length; k++) {
                    removedEmployees[removedEmployees.length+1].currencies[k] = IEquity.Currency(list[i].currencies[k],
                    list[i].amounts[k]);
                }
                delete list[i];
            }
        } 
    }
    function returnRemoved(address employee) public onlyOwner {
        for(uint i = 0; i < removedEmployees.length; i++) {
            if(removedEmployees[i].employee == employee) {
                require(removedEmployees[i].timeWhenRemoved + 30 days < block.timestamp,
                    "You are not able to return the employee anymore");
                list[list.length+1].employee = employee;
                for(uint k = 0; k < removedEmployees[i].currencies.length; k++) {
                    list[list.length+1].currencies[k] = list[list.length+1].currencies[k];
                }
                delete removedEmployees[i];
            }
        }
    }
}