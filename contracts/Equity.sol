//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

struct Employee {
    address employee;
    uint256 reward;
}
interface EquityInterface {
    function deposit() external payable;
    function setList(Employee[] memory _list) external;
    function withdraw() external;
    function ownerWithdraw() external;
}
contract Equity is EquityInterface{

    address public owner;
    address public listContract;
    //keep track of the employees
    address[] public employees;

    uint256 public unlockTime;
    uint256 public lockPeriod;
    
    //employee -> amount
    mapping (address => uint) list;
    bool withdrawPeriod = false;

    //lock period is defined in days
    constructor(address _listContract, uint256 _lockPeriod) {
        owner = msg.sender;
        lockPeriod = _lockPeriod;
        listContract = _listContract;
    }
    function deposit() public override payable {
        //checking if the withdraw period is done
        if(block.timestamp > SafeMath.add(unlockTime, SafeMath.mul(lockPeriod, 365 days))) {
            withdrawPeriod = false;
        }
        require(withdrawPeriod == false, "You can't deposit during the withdraw period");
        require(unlockTime < block.timestamp, "The fund function can only be called once");
        require(msg.sender == owner, "Only the owner can call this function");
        require(msg.value > 0, "Message value cannost be 0");
        unlockTime = SafeMath.add(block.timestamp, SafeMath.mul(lockPeriod, 365 days));
    }
    //solidity does not support mapping as function parameter
    function setList(Employee[] memory _list) public override {
        require(msg.sender == listContract, "Only the List contract is allowed to call this function");
        for(uint256 i = 0; i <= _list.length; i++) {
            list[_list[i].employee] = _list[i].reward;
            employees.push(_list[i].employee);
        }
        withdrawPeriod = true;
    }
    function withdraw() public override {
        require(block.timestamp < SafeMath.add(unlockTime, SafeMath.mul(lockPeriod, 365 days)), 
        "Your are not allowed to withdraw anymore");
        require(unlockTime > block.timestamp, "Your are not allowed to withdraw yet");
        require(list[msg.sender] != 0, "You can't withdraw 0");
        //I reset the reward before sending it to prevent double spending
        list[msg.sender] = 0;
        payable(msg.sender).transfer(list[msg.sender]);
    }
    function ownerWithdraw() public override {
        require(msg.sender == owner, "Only the owner is able to call this function");
        //resetting the list
        for(uint i = 0; i < employees.length; i++) {
            delete list[employees[i]];
        }
        delete employees;
        //transfers all remaining balance to the owner
        payable(owner).transfer(address(this).balance);
    }
}
