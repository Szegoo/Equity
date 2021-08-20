//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEquity {
    struct Currency {
        address currency;
        uint amount;
    }
    struct Employee {
        address employee;
        //the currencies that the user gets when calls 
        //the withdraw function
        Currency[] currencies;
    }
    function deposit() external;
    function withdraw() external;
    function setList(Employee[] memory _list) external;
    function ownerWithdraw() external;
}
contract Equity is IEquity{
    address[] public predefinedCurrencies;

    address public owner;
    address public listContract;

    uint256 public unlockTime;
    uint256 public lastUnlockTime;
    //2 years
    uint256 public lockPeriod = 2;
    
    //employee -> amount
    Employee[] public list;

    uint[] public currentRoundTotal;
    uint[] public lastRoundTotal;

    //to use the currency of the blockchain(e.g ETH) set the
    //address of _predefinedCurrency.currency 
    //to address 0x0000000000000000000000000000000000000000
    constructor(address _listContract, address[] memory _predefinedCurrencies) {
        owner = msg.sender;
        listContract = _listContract;
        predefinedCurrencies = _predefinedCurrencies;
    }
    //use this function if you have defined a custom predefinedCurrency 
    function deposit() public override {
        //there should be at least one currency
        require(unlockTime < block.timestamp, "The fund function can only be called once");
        require(msg.sender == owner, "Only the owner can call this function");
        lastRoundTotal = currentRoundTotal;
        for(uint i = 0; i < predefinedCurrencies.length; i++) {
            //maybe need a fix
            if(predefinedCurrencies[i] == address(0)) {
                currentRoundTotal[i] = SafeMath.sub(
                    address(this).balance, lastRoundTotal[i]
                );
            }else {
                currentRoundTotal[i] = SafeMath.sub(
                    IERC20(predefinedCurrencies[i]).balanceOf(address(this))
                    ,lastRoundTotal[i]);
            }
        }
        lastUnlockTime = unlockTime;
        unlockTime = SafeMath.add(block.timestamp, SafeMath.mul(lockPeriod, 365 days));
    }
    //solidity does not support mapping as function parameter
    function setList(Employee[] memory _list) public override {
        require(msg.sender == listContract, "Only the List contract is allowed to call this function");
        delete list;

        list = _list;
        uint256[] memory total;
        for(uint256 i = 0; i < _list.length; i++) {
            for(uint256 k = 0; k < _list[i].currencies.length; k++) {
                total[i] = _list[i].currencies[k].amount;
            }
        }
        /*you can delete the next line(I use it for testing so that
        I don't have to wait for the timer to end but it 
        does not affect the code in production)*/
        unlockTime = block.timestamp;
        
        //checking if the contract has enough funds
        for(uint256 i = 0; i < total.length; i++) {
            uint256 amount;
            if(predefinedCurrencies[i] == address(0)) {
                amount = SafeMath.sub(address(this).balance, lastRoundTotal[i]);
            }else {
                amount = SafeMath.sub(
                    IERC20(predefinedCurrencies[i]).balanceOf(address(this)),
                    lastRoundTotal[i]
                );
            }
            require(amount >= total[i], "you should provide enough funds before calling this function");
            //if someone was dropped out of the list we can know for
            //sure that he is not going to be able to withdraw the amount.
            //Instead of the contract owner waiting for 2 years to pass
            //he can withdraw the kicked person's balance right away
            if(predefinedCurrencies[i] == address(0)) {
                if(SafeMath.sub(total[i], amount) > 0) {
                    payable(owner).transfer(SafeMath.sub(total[i], amount));
                }
            }else {
                if(SafeMath.sub(total[i], amount) > 0) {
                    IERC20(predefinedCurrencies[i]).transfer(owner,
                    SafeMath.sub(total[i], amount));
                }
            }
            currentRoundTotal[i] -= SafeMath.sub(total[i], amount);
        }
    }
    function withdraw() public override {
        require(block.timestamp < SafeMath.add(unlockTime, SafeMath.mul(lockPeriod, 365 days))
        || block.timestamp < SafeMath.add(lastUnlockTime, SafeMath.mul(lockPeriod, 365 days)), 
        "Your are not allowed to withdraw anymore");
        require(unlockTime < block.timestamp || lastUnlockTime < block.timestamp,
         "Your are not allowed to withdraw yet");
        for(uint i = 0; i < list.length; i++) {
            if(list[i].employee == msg.sender) {
                Currency[] storage amounts = list[i].currencies;
                //I reset the amount before sending it to prevent double spending
                delete list[i];
                for(uint j = 0; j < amounts.length; j++) {
                    if(amounts[j].amount > 0) {
                        if(block.timestamp < unlockTime) {
                            lastRoundTotal[j] -= amounts[j].amount;
                        }else {
                            currentRoundTotal[j] -= amounts[j].amount;
                        }
                        if(address(amounts[j].currency) == address(0)) {
                            payable(msg.sender).transfer(amounts[j].amount);
                        }else {
                            IERC20(amounts[j].currency).transfer(msg.sender, amounts[j].amount);
                        }
                    }
                }
                break;
            }
        }
    }
    function ownerWithdraw() public override {
        require(msg.sender == owner, "Only the owner is able to call this function");
        require(block.timestamp > SafeMath.add(unlockTime, SafeMath.mul(SafeMath.mul(lockPeriod, 2), 365 days))
        || block.timestamp > SafeMath.add(lastUnlockTime, SafeMath.mul(SafeMath.mul(lockPeriod, 2), 365 days)),
        "You are not able to withdraw yet");
        if(block.timestamp < SafeMath.add(unlockTime, SafeMath.mul(SafeMath.mul(lockPeriod, 2), 365 days))) {
            for(uint256 i = 0; i < predefinedCurrencies.length; i++) {
                if(lastRoundTotal[i] > 0) {
                    if(address(predefinedCurrencies[i]) == address(0)) {
                        payable(owner).transfer(SafeMath.sub(address(this).balance, currentRoundTotal[i]));
                    }else {
                        IERC20(predefinedCurrencies[i]).transfer(owner, SafeMath.sub(
                           IERC20(predefinedCurrencies[i]).balanceOf(address(this)),
                            currentRoundTotal[i]
                        ));
                    }
                }
            }
            delete lastRoundTotal;
        }else {
            for(uint256 i = 0; i < predefinedCurrencies.length; i++) {
                if(address(predefinedCurrencies[i]) == address(0)) {
                    payable(owner).transfer(address(this).balance);
                }else {
                    IERC20(predefinedCurrencies[i]).transfer(owner, 
                    IERC20(predefinedCurrencies[i]).balanceOf(address(this)));
                }
                delete currentRoundTotal;
                delete lastRoundTotal;
            }
        }
    }
}
