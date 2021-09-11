//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Equity.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

interface IList {
    function addList(IEquity.Employee[] memory  _list) external;
}
contract List is IList, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    struct RemovedEmployee {
        address employee;
        uint256 timeWhenRemoved;
        address[] currencies;
        uint256[] amounts;
    }

    address public oracle;
    bytes32 public jobId;
    uint256 public unlockTime;

    address public owner;
    IEquity.Employee[] public list;
    IEquity public equity;
    //this mapping stores an address only for 30 days
    RemovedEmployee[] public removedEmployees;

    constructor(address _oracle) {
        owner = msg.sender;
        oracle = _oracle;
        jobId = "d5270d1c311941d0b08bead21fea7747";
    }
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner is able to call this function");
        _;
    }
    //returns all the currencies for the specific employee
    function getCurrencies(uint256 employeeId) public view returns(IEquity.Currency[] memory) {
        //the length of the array is equal to the length of the
        //currency array for the specific user
        IEquity.Currency[] memory currencies = new IEquity.Currency[](list[employeeId].currencies.length);
        for(uint i = 0; i < list[employeeId].currencies.length; i++) {
            address currency = list[employeeId].currencies[i];
            uint amount = list[employeeId].amounts[i];
            currencies[i] = IEquity.Currency(currency, amount);
        }
        return currencies;
    }
    function setEquityContract(address contractAddress) public onlyOwner {
        //checking if the equity contract is already set
        require(address(equity) == address(0), "The equity contract is already set");
        equity = IEquity(contractAddress);
    }
    //this function should be called only once in a round
    function addList(IEquity.Employee[] memory _list) public override onlyOwner {
        require(list.length == 0, "You can set this only once");
        require(address(equity) != address(0), "Set the Equity contract address before calling this function");
        unlockTime = SafeMath.add(block.timestamp, 365 days);
        for(uint i = 0; i < _list.length; i++) {
            list.push(_list[i]);
        }
        //We could use Chainlink keepers for automatic function calling
        //https://docs.chain.link/docs/chainlink-keepers/introduction/
        while(true) {
            if(block.timestamp == unlockTime) {
                sendList();
                break;
            }
        }
    }
    //ask the api if someone needs to be removed
    function getRemovalRequest() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        request.add("get", "http://localhost:8080/removal-requests");

        uint fee = 0.1 * 10 ** 18;
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    function fulfill(bytes32 _requestId, address[] memory employees) public recordChainlinkFulfillment(_requestId)
    {
        for(uint i = 0; i < employees.length; i++) {
            remove(employees[i]);
        }
    }
    //only the oracle is able to call this function
    function remove(address employee) internal {
        for(uint256 i = 0; i < list.length; i++) {
            if(list[i].employee == employee) {
                //this leaves a gap in the array
                removedEmployees.push(RemovedEmployee(list[i].employee, 
                block.timestamp, list[i].currencies, list[i].amounts)); 
                delete list[i];
            }
        } 
    }
    function returnRemoved(address employee) internal {
        for(uint i = 0; i < removedEmployees.length; i++) {
            if(removedEmployees[i].employee == employee) {
                //you have only 30 days to return an employee to the list
                require(removedEmployees[i].timeWhenRemoved + 30 days > block.timestamp,
                    "You are not able to return the employee anymore");
                list.push(IEquity.Employee(removedEmployees[i].employee, removedEmployees[i].currencies,
                removedEmployees[i].amounts));
                delete removedEmployees[i];
            }
        }
    }
    function sendList() internal {
        equity.setList(list);
        delete list;
    }
}