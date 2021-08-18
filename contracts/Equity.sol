//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface EquityInterface {
    function depositCurrency() external;
    function deposit() external payable;
    function withdraw() external;
    function ownerWithdraw() external;
}
contract Equity is EquityInterface{
    struct Employee {
        address employee;
        uint256 amount;
    }
    IERC20 public predefinedCurrency;

    address public owner;
    address public listContract;
    //keep track of the employees
    address[] public employees;

    uint256 public unlockTime;
    uint256 public lastUnlockTime;
    //2 years
    uint256 public lockPeriod = 2;
    
    //employee -> amount
    mapping (address => uint) list;

    uint public currentRoundTotal;
    uint256 public lastRoundTotal;

    //to use the currency of the blockchain(e.g ETH) set the
    //_predefinedCurrency to address 0x0000000000000000000000000000000000000000
    constructor(address _listContract, address _predefinedCurrency) {
        owner = msg.sender;
        listContract = _listContract;
        predefinedCurrency = IERC20(_predefinedCurrency);
    }
    //use this function if you have defined a custom predefinedCurrency 
    function depositCurrency() public override {
        require(address(predefinedCurrency) != address(0), "The predefined currency is not defined");
        require(predefinedCurrency.balanceOf(address(this)) > 0, "Send currency before calling this function");
        require(unlockTime < block.timestamp, "The fund function can only be called once");
        require(msg.sender == owner, "Only the owner can call this function");
        lastRoundTotal = currentRoundTotal;
        currentRoundTotal = predefinedCurrency.balanceOf(address(this));
        lastUnlockTime = unlockTime;
        unlockTime = SafeMath.add(block.timestamp, SafeMath.mul(lockPeriod, 365 days));
    }
    function deposit() public override payable {
        require(unlockTime < block.timestamp, "The fund function can only be called once");
        require(msg.sender == owner, "Only the owner can call this function");
        lastRoundTotal = currentRoundTotal;
        currentRoundTotal = msg.value;
        lastUnlockTime = unlockTime;
        unlockTime = SafeMath.add(block.timestamp, SafeMath.mul(lockPeriod, 365 days));
    }
    //solidity does not support mapping as function parameter
    function setList(Employee[] memory _list) public {
        require(msg.sender == listContract, "Only the List contract is allowed to call this function");
        //reseting the list
        //maybe need a fix
        for(uint256 i = 0; i < employees.length; i++) {
            delete list[employees[i]];
        }
        delete employees;

        uint256 total = 0;
        for(uint256 i = 0; i < _list.length; i++) {
            total+=_list[i].amount;
            list[_list[i].employee] = _list[i].amount;
            employees.push(_list[i].employee);
        }
        //if someone was dropped out of the list we can know for
        //sure that he is not going to be able to withdraw the amount
        //instead of the contract owner waiting for 2 years to pass
        //he can withdraw the kicked person's balance right away
        if(address(predefinedCurrency) == address(0)) {
            if(SafeMath.sub(SafeMath.sub(address(this).balance, total), lastRoundTotal) > 0) {
                payable(owner).transfer(SafeMath.sub(SafeMath.sub(currentRoundTotal, total), lastRoundTotal));
                currentRoundTotal -= SafeMath.sub(SafeMath.sub(currentRoundTotal, total), lastRoundTotal);
            }
        }else {
            uint amount = SafeMath.sub(SafeMath.sub(currentRoundTotal,
            total), lastRoundTotal);
            if(amount > 0) {
                predefinedCurrency.transfer(owner, amount);
            }
        }
        //you can delete this line(i use it for testing but it 
        //does not affect the code in production)
        unlockTime = block.timestamp;
        
        require(currentRoundTotal >= total, 
        "you should provide enough funds before calling this function");
    }
    function withdraw() public override {
        require(block.timestamp < SafeMath.add(unlockTime, SafeMath.mul(lockPeriod, 365 days))
        || block.timestamp < SafeMath.add(lastUnlockTime, SafeMath.mul(lockPeriod, 365 days)), 
        "Your are not allowed to withdraw anymore");
        require(unlockTime < block.timestamp || lastUnlockTime < block.timestamp,
         "Your are not allowed to withdraw yet");
        require(list[msg.sender] != 0, "You can't withdraw 0");
        //I reset the amount before sending it to prevent double spending
        uint256 amount = list[msg.sender];
        list[msg.sender] = 0;
        if(block.timestamp < unlockTime) {
            lastRoundTotal -= amount;
        }else {
            currentRoundTotal -= amount;
        }
        if(address(predefinedCurrency) == address(0)) {
            payable(msg.sender).transfer(amount);
        }else {
            predefinedCurrency.transfer(msg.sender, amount);
        }
    }
    function ownerWithdraw() public override {
        require(msg.sender == owner, "Only the owner is able to call this function");
        require(block.timestamp > SafeMath.add(unlockTime, SafeMath.mul(lockPeriod, 365 days))
        || block.timestamp > SafeMath.add(lastUnlockTime, SafeMath.mul(lockPeriod, 365 days)),
        "You are not able to withdraw yet");
        if(block.timestamp < SafeMath.add(unlockTime, SafeMath.mul(lockPeriod, 365))) {
            if(address(predefinedCurrency) == address(0)) {
                payable(owner).transfer(SafeMath.sub(address(this).balance, currentRoundTotal));
            }else {
                predefinedCurrency.transfer(owner, SafeMath.sub(
                    predefinedCurrency.balanceOf(address(this)),
                    currentRoundTotal
                ));
            }
        }else {
            if(address(predefinedCurrency) == address(0)) {
                payable(owner).transfer(address(this).balance);
            }else {
                predefinedCurrency.transfer(owner, 
                predefinedCurrency.balanceOf(address(this)));
            }
        }
    }
}
