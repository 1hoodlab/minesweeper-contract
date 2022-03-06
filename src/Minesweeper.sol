//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;
import "./interface/IMinesweeper.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Minesweeper is IMinesweeper, ReentrancyGuard, Pausable, Ownable,VRFConsumerBaseV2 {

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    address payable private beneficiary;
   
    uint256 public fee; // default 10%
    uint256 public priceOfTurn; // default: 1 ETH = 10 turns
    uint256 private seed;
    uint256 public s_requestId;
    
    uint[100] private awards; // store awards

    mapping(uint => bool) public isOpen;
    mapping(address => uint8) public turns;
    // Your subscription ID.
    uint64 s_subscriptionId;
    // Rinkeby coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;

    // Rinkeby LINK token contract. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address link = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords =  1;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_subscriptionId = subscriptionId;
        priceOfTurn = 100000000000000000; // 0.1 ETH
        fee = 10; // 10%
        beneficiary = payable(msg.sender);
         _pause();
    }
    
    function setPriceOfTurn(uint256 price) external nonReentrant onlyOwner {
        priceOfTurn = price;
    }
    function getAward() public view whenPaused returns(uint[100] memory) {
        return awards;
    }
    function buyTurn(uint8 numberOfTurns) payable external override nonReentrant{
        uint _amount = numberOfTurns * priceOfTurn;
        require(_amount != 0, "E0"); // E0: Not zero
        _handleIncomingFund(_amount);
        turns[msg.sender] = turns[msg.sender] + numberOfTurns;
        emit BuyTurn(msg.sender, numberOfTurns);
    }

    function getBeneficiary() public view onlyOwner returns (address) {
        return beneficiary;
    }
    function setBeneficiary(address payable _beneficiary) public nonReentrant onlyOwner {
        beneficiary = _beneficiary;
    }
    function setAwards(uint[100] memory _awards) public whenPaused onlyOwner {
        awards = _awards;
    }

    function stopGame() public onlyOwner {
        _pause();
    }

    function start() external override whenPaused nonReentrant onlyOwner{
        require(seed != 0, "E1"); // E1: seed is not null
        _handleShuffle(seed);
        _unpause();
    }

    function _deleteTurn() private {
        turns[msg.sender] = 0;
    }

    function openCell(uint key) external override nonReentrant whenNotPaused {
        require(turns[msg.sender] != 0 && !isOpen[key], "E3"); //E3: you have not turn
        _handleAward(key);
        isOpen[key] = true;
        emit OpenCell(msg.sender, key, awards[key]);
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
    function _handleIncomingFund(uint amount) private {
        require(msg.value == amount, "Transfer failed");
        (bool isSuccess,) = address(this).call{value: msg.value}("");
        require(isSuccess, "Transfer failed: gas error");
    }
    function _handleOutGoingFund(address to, uint amount) private {
        (bool isSuccess,) = to.call{value: amount}("");
        require(isSuccess, "Transfer failed: gas error");
    }
    function _handleAward(uint key) private {
        if(awards[key] == 0) _deleteTurn();
        if(awards[key] == 5) turns[msg.sender] = turns[msg.sender] - 1;
        
        uint award = awards[key] * address(this).balance / 100;
        uint forBeneficiary = award * fee / 100;
        uint forPlayer = award - forBeneficiary;

        _handleOutGoingFund(msg.sender, forPlayer);
        _handleOutGoingFund(beneficiary, forBeneficiary);

        turns[msg.sender] = turns[msg.sender] - 1;
    }
    function _handleShuffle(uint _seed) private {
        for (uint i = 0; i < awards.length; i++) {
            uint n = i + uint(keccak256(abi.encodePacked(_seed))) % (awards.length - i);
            uint temp = awards[n];
            awards[n] = awards[i];
            awards[i] = temp;
        }
    }
    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        seed = randomWords[0];
    
    }

    receive() external payable {}
}
