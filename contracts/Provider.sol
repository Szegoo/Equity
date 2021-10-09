//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;
import "./Equity.sol";
import "./List.sol";

contract Provider {
    address owner;
    IList public listContract;
    IEquity public equityContract;

    constructor(address equityAddress, address listAddress) {
        owner = msg.sender;
        equityContract = IEquity(equityAddress);
        listContract = IList(listAddress);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner is able to call this function");
        _;
    }

    fallback() external payable {}

    function sendListWithCurrencies(IEquity.Employee[] memory _list) public {
        for(uint i = 0; i < _list.length; i++) {
            for(uint k = 0; k < _list[i].currencies.length; k++) {
                address currency = _list[i].currencies[k];
                uint amount = _list[i].amounts[k];
                if(currency== address(0)) {
                    require(address(this).balance >=amount, 
                    "The contract does not have enough balance for this transaction.");
                }else {
                    require(IERC20(currency).balanceOf(address(this)) >= amount,
                    "The contract does not have enough balance for this transaction.");
                }
            }
        }
        listContract.addList(_list);
        equityContract.deposit();
    }
}