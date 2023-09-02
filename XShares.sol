pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract XSharesSharesV2 is OwnableUpgradeable {
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    event Trade(address trader, address subject, bool isBuy, uint256 shareAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 subjectEthAmount, uint256 supply);

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    // SharesSubject => CurveIndex
    mapping(address => uint256) public sharesCurveIndex;


    function initialize() public initializer {
        __Ownable_init();
        protocolFeeDestination = 0x803e17c7A84af859F5d85A8Cd75736265a133980;
        protocolFeePercent = 1e17;
    }


    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function getPrice(uint256 supply, uint256 amount, uint256 curveIndex) public pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : ((supply - 1) * (supply) * (2 * (supply - 1) + 1) * 1 ether) / (curveIndex * 6);
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : ((supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) * 1 ether) / (curveIndex * 6);
        uint256 summation = sum2 - sum1;
        // ((x ** 2 - 1) / p) + 1 / 16000
        return summation / 16000;
    }


    function getBuyPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject], amount, sharesCurveIndex[sharesSubject]);
    }

    function getSellPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject] - amount, amount, sharesCurveIndex[sharesSubject]);
    }

    function getBuyPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        return price + protocolFee + subjectFee;
    }

    function getSellPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        return price - protocolFee - subjectFee;
    }

    function buyShares(address sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > 0, "Users are not registered and cannot purchase");
        uint256 price = getPrice(supply, amount, sharesCurveIndex[sharesSubject]);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + subjectFee, "Insufficient payment");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
        sharesSupply[sharesSubject] = supply + amount;
        emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, subjectFee, supply + amount);
        (bool success1,) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2,) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");
    }

    function sellShares(address sharesSubject, uint256 amount) public {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount, sharesCurveIndex[sharesSubject]);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
        sharesSupply[sharesSubject] = supply - amount;
        emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, subjectFee, supply - amount);
        (bool success1,) = msg.sender.call{value: price - protocolFee - subjectFee}("");
        (bool success2,) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3,) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }

    function register(uint256 curveIndex) public  {
        address sharesSubject = msg.sender;
        uint256 supply = sharesSupply[sharesSubject];
        require(supply == 0 , "Supply must be 0");
        require(curveIndex >= 1 && curveIndex <= 10, "The curveIndex can only be between 1 and 10");
        sharesBalance[sharesSubject][sharesSubject] = sharesBalance[sharesSubject][sharesSubject] + 1;
        sharesSupply[sharesSubject] = supply + 1;
        sharesCurveIndex[sharesSubject] = curveIndex;
        emit Trade(sharesSubject, sharesSubject, true, 1, 0, 0, 0, supply + 1);
    }




}