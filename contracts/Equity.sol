//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEquity {
    struct Employee {
        address employee;
        //the currencies that the user gets when calls
        //the withdraw function
        address[] currencies;
        uint256[] amounts;
    }
    struct Currency {
        address currency;
        uint256 amount;
    }

    function deposit() external;

    function withdraw() external;

    function setList(Employee[] calldata _list) external;

    function ownerWithdraw() external;
}

contract Equity is IEquity {
    address[] public predefinedCurrencies;

    address public owner;
    address public listContract;

    uint256 public unlockTime;
    uint256 public lastUnlockTime;
    //2 years

    uint256 public timeToWait;

    //employee -> amount
    Employee[] public list;

    uint256[] public currentRoundTotal;
    uint256[] public lastRoundTotal;

    //to use the currency of the blockchain(e.g ETH) set the
    //address of _predefinedCurrency.currency
    //to address 0x0000000000000000000000000000000000000000
    constructor(
        address _listContract,
        address[] memory _predefinedCurrencies,
        uint256 _timeToWait
    ) {
        owner = msg.sender;
        listContract = _listContract;
        predefinedCurrencies = _predefinedCurrencies;
        lastRoundTotal.push(0);
        timeToWait = _timeToWait;
    }

    fallback() external payable {}

    receive() external payable {}

    function getCurrencies(uint256 employeeId) public view returns (Currency[] memory) {
        //the length of the array is equal to the length of the
        //currency array for the specific user
        Currency[] memory currencies = new Currency[](list[employeeId].currencies.length);
        for (uint256 i = 0; i < list[employeeId].currencies.length; i++) {
            address currency = list[employeeId].currencies[i];
            uint256 amount = list[employeeId].amounts[i];
            currencies[i] = Currency(currency, amount);
        }
        return currencies;
    }

    //use this function if you have defined a custom predefinedCurrency
    function deposit() public override {
        //there should be at least one currency
        require(unlockTime < block.timestamp, "The fund function can only be called once");
        require(msg.sender == owner, "Only the owner can call this function");
        lastRoundTotal = currentRoundTotal;
        for (uint256 i = 0; i < predefinedCurrencies.length; i++) {
            setCurrentRoundTotal(predefinedCurrencies[i], i);
        }
        setUnlockTime();
    }

    //solidity does not support mapping as function parameter
    function setList(Employee[] memory _list) public override {
        require(msg.sender == listContract, "Only the List contract is allowed to call this function");
        delete list;

        for (uint256 i = 0; i < _list.length; i++) {
            list.push(_list[i]);
        }
        /*you can delete the next line(I use it for testing so that
        I don't have to wait for the timer to end but it 
        does not affect the code in production)*/
        unlockTime = block.timestamp;
    }

    function withdraw() public override {
        require(
            block.timestamp < SafeMath.add(unlockTime, timeToWait) ||
                block.timestamp < SafeMath.add(lastUnlockTime, timeToWait),
            "Your are not allowed to withdraw anymore"
        );
        require(
            unlockTime < block.timestamp || lastUnlockTime < block.timestamp,
            "Your are not allowed to withdraw yet"
        );
        uint256 indx = getEmployeeIndex(msg.sender);
        uint256[] storage amounts = list[indx].amounts;
        //I reset the amount before sending it to prevent double spending
        delete list[indx];
        for (uint256 j = 0; j < amounts.length; j++) {
            if (amounts[j] > 0) {
                sendAmount(msg.sender, amounts[j], indx, j);
                subtractTotal(amounts[j], list[indx].currencies[j]);
            }
        }
    }

    function ownerWithdraw() public override {
        require(msg.sender == owner, "Only the owner is able to call this function");
        require(
            block.timestamp > SafeMath.add(unlockTime, timeToWait) ||
                block.timestamp > SafeMath.add(lastUnlockTime, timeToWait),
            "You are not able to withdraw yet"
        );
        for (uint256 i = 0; i < predefinedCurrencies.length; i++) {
            uint256 amount = calculateOwnerAmount(i);
            sendOwnerAmount(amount, i);
            bool canOwnerWithdrawCurrent = canOwnerWithdrawCurrentTotal();
            /*
                if the employer can withdraw from the current round
                the contract can be 100% sure that he can also withdraw
                the last round total.
            */
            if (canOwnerWithdrawCurrent) {
                delete currentRoundTotal;
                delete lastRoundTotal;
            } else {
                delete lastRoundTotal;
            }
        }
    }

    function setCurrentRoundTotal(address currency, uint256 indx) internal {
        uint256 lastTotal = 0;
        if (lastRoundTotal.length > indx && lastRoundTotal[indx] > lastTotal) {
            lastTotal = lastRoundTotal[indx];
        }
        if (currency == address(0)) {
            currentRoundTotal.push(SafeMath.sub(address(this).balance, lastTotal));
        } else {
            currentRoundTotal.push(
                SafeMath.sub(IERC20(predefinedCurrencies[indx]).balanceOf(address(this)), lastTotal)
            );
        }
    }

    //returns the index of the employee in the list array
    function getEmployeeIndex(address employee) internal view returns (uint256) {
        uint256 indx;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].employee == employee) {
                indx = i;
                break;
            }
        }
        return indx;
    }

    function sendAmount(
        address to,
        uint256 amount,
        uint256 receiverIndx,
        uint256 currencyIndx
    ) internal {
        if (address(list[receiverIndx].currencies[currencyIndx]) == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(list[receiverIndx].currencies[currencyIndx]).transfer(to, amount);
        }
    }

    function sendOwnerAmount(uint256 amount, uint256 currencyIndx) internal {
        if (predefinedCurrencies[currencyIndx] == address(0)) {
            payable(owner).transfer(amount);
        } else {
            IERC20(predefinedCurrencies[currencyIndx]).transfer(owner, amount);
        }
    }

    function subtractTotal(uint256 amount, address currency) internal {
        uint256 currencyIndx = getCurrencyIndx(currency);
        if (block.timestamp < unlockTime) {
            lastRoundTotal[currencyIndx] -= amount;
        } else {
            currentRoundTotal[currencyIndx] -= amount;
        }
    }

    function getCurrencyIndx(address currency) internal view returns (uint256) {
        uint256 indx;
        for (uint256 i = 0; i < predefinedCurrencies.length; i++) {
            if (predefinedCurrencies[i] == currency) {
                indx = i;
                break;
            }
        }
        return indx;
    }

    function canOwnerWithdrawCurrentTotal() internal view returns (bool) {
        /*
            the employer can withdraw the current round total
            if the current time is greater than the unlock time for
            the employee + whatever the value of timeToWait is
        */
        if (block.timestamp > SafeMath.add(unlockTime, timeToWait)) {
            return true;
        } else {
            return false;
        }
    }

    function calculateOwnerAmount(uint256 currencyIndx) internal view returns (uint256) {
        uint256 amount;
        uint256 subtractedAmount;
        if (!canOwnerWithdrawCurrentTotal()) {
            subtractedAmount = currentRoundTotal[currencyIndx];
        }
        if (address(predefinedCurrencies[currencyIndx]) == address(0)) {
            amount = SafeMath.sub(address(this).balance, subtractedAmount);
        } else {
            amount = SafeMath.sub(
                IERC20(predefinedCurrencies[currencyIndx]).balanceOf(address(this)),
                subtractedAmount
            );
        }
        return amount;
    }

    function setUnlockTime() internal {
        lastUnlockTime = unlockTime;
        unlockTime = SafeMath.add(block.timestamp, timeToWait);
    }
}
