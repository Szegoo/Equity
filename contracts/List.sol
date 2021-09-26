//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.7;
pragma experimental ABIEncoderV2;

import "./Equity.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

interface IList {
    function addList(IEquity.Employee[] calldata  _list) external;
}
contract List is IList, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    struct RemovedEmployee {
        address employee;
        uint256 timeWhenRemoved;
        address[] currencies;
        uint256[] amounts;
    }

    address public booleanOracle = 0xE9ac2C2e5906e67fBc0bDA89f0aD327022f2b7fB;
    address public numberOracle = 0x12EDD40D4E171568A4927B83ed17e5bb0c257b80;
    address public bytesOracle;

    bytes32 public booleanJobId;
    bytes32 public numberJobId;
    bytes32 public bytesJobId;
    
    uint256 public unlockTime;

    address public owner;
    IEquity.Employee[] public list;
    IEquity public equity;
    //this mapping stores an address only for 30 days
    RemovedEmployee[] public removedEmployees;

    constructor() public {
        setPublicChainlinkToken();
        owner = msg.sender;
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
    function shouldRemove() public returns (bytes32 requestId) {
            Chainlink.Request memory request = buildChainlinkRequest(booleanJobId, address(this), this.getResponse.selector);
            request.add("get", "http://localhost:3000/remove");
            uint fee = 0.1 * 10 ** 18;
            return sendChainlinkRequestTo(booleanOracle, request, fee);
    }
    //get the number of the employees that should be removed
    function getNumberOfEmployees() public returns(bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(numberJobId, address(this), this.getNumber.selector);
        request.add("get", "http://localhost:3000/number-of-employees");
        uint fee = 0.1 * 10 ** 18;
        return sendChainlinkRequestTo(numberOracle, request, fee);
    }
    function getEmployeeAtIndx(uint8 i) public returns(bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(bytesJobId, address(this), this.getAddress.selector);
        string memory indx = uint2str(i);
        string memory url = concat("http://localhost:3000/employee?indx=", indx);
        request.add("get", url);
        uint fee = 0.1 * 10 ** 18;
        return sendChainlinkRequestTo(bytesOracle, request, fee);
    }
    function getAddress(bytes32 _requestId, bytes memory data) public recordChainlinkFulfillment(_requestId) {
        address employee = bytesToAddress(data);

        remove(employee);
    }
    function getNumber(bytes32 _requestId, uint number) public recordChainlinkFulfillment(_requestId) {
        for(uint8 i = 0; i < number; i++) {
            getEmployeeAtIndx(i);
        }
    }
    function getResponse(bytes32 _requestId, bool remove) public recordChainlinkFulfillment(_requestId)
    {
        if(!remove) {
            return;
        }else {
            getNumberOfEmployees();
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
    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys,20))
        } 
    }
    function concat(string memory _base, string memory _value) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        string memory _tmpValue = new string(_baseBytes.length + _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for(i=0; i<_baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for(i=0; i<_valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}