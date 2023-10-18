// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/Base64.sol";
import "./interfaces/IDistributionPool.sol";

import "hardhat/console.sol";


contract CryptoMiner is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    // Event handling
    event TokensMinted(address indexed owner, uint256 amount);
    event MinerStarted(string minerType, address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 tokenId);

    // mapping (address => address) public referrals;
    // mapping (address => uint) public claimTokensRewarded;


    // Pause minting or boosting
    bool public minerPaused;

    // Miner counter
    Counters.Counter private _btcMinerTokenIds;

    // Miner supply control
    uint256 public bitcoinMinerSupply = 2000;

    // Pricing 
    uint256 public cryptoMinerPrice;
    uint256 public discountedPrice;
    uint256 public burnAmount;

    // Hashrate pricing
    uint256 public minerBoostRate;

    // Used for calculating emission rate per block
    uint256 public setHashrate; 
    uint256 public dailyBlocks;
    uint256 initialHashrate = 5; // the initial hashrate of a miner once minted, default is 2.
    uint256 public constant hsh = 1; // cryptominer hash equivalent to 1TH used when hashrate is increased
    uint256 public constant minerPower = 1; // Used for miner power calculations

    struct TokenInfo {
        IERC20 paytoken;
        string name;
    }

    TokenInfo[] public AllowedCrypto;
    mapping(uint256 => uint) public rates;
    address public dp; // distribution pool
    // address public wm; // windmill contract
    address public cm; // claim token contract

    // Emission rates, can be modified by owner or controller
    uint256 public cryptoReward;

    // Miner Data
    struct Miner {
        string token; // Token being mined by miner
        uint256 tokenId; // Token Id of miner
        string name; // Name of miner set by owner
        uint256 hashrate; // Miner hashrate
        string hashMeasured; // Hashrate measured in GH or TH
        uint256 rewardPerBlock; // The miners earning per block
        uint lastUpdateBlock; // The last time a reward was claimed or when the miner began staking
        uint256 accumulated; // Unclaimed accumulated rewards left over before hashboost
        uint256 dailyEstimate; // pending rewards for a miner
        string imageURI; // miner image
    }

    mapping(uint256 => Miner) public miners; // Access miner struct
    mapping(uint256 => address) private minerOwners; // Miner owners by address
    mapping (address => uint) public minerMints; // Tracking of miners minted per user

    // Token mining global statistics
    struct CryptoMiners {
        uint256 minersHashing; // number of miners hashing
        uint256 totalHashrate; // the total hashrate of all Bitcoin miners
        uint256[] minerTokenIds; // Used for updating global emission rate data across all miners
    }
    CryptoMiners public cryptominer;
    

    constructor(
        string[] memory minerImageURIs
    ) ERC721("CryptoMiner", "MINER") {
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
        {
            uint256 ownerTokenCount = balanceOf(_owner);
            uint256[] memory tokenIds = new uint256[](ownerTokenCount);
            for (uint256 i; i < ownerTokenCount; i++) {
                tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
            }
            return tokenIds;
    }

     function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        Miner memory minerToken = miners[_tokenId];

        string memory strHashrate = Strings.toString(minerToken.hashrate);
        string memory strBlckRwd = Strings.toString(minerToken.rewardPerBlock);

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                minerToken.name,
                ' -- CryptoMiner #: ',
                Strings.toString(_tokenId),
                '", "description": "Mine more blocks with your Crypto Miner", "image": "',
                minerToken.imageURI,
                '", "attributes": [ { "trait_type": "Hashrate", "value": ',strHashrate,'}, { "trait_type": "Block Reward", "value": ',
                strBlckRwd,'} ]}'
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    // Pause minting and boosting
    modifier whenBtcNotPaused() {
        require(!minerPaused, "Bitcoin miner minting is paused");
        _;
    }

    // Mint a miner
    function mintMiner(uint256 _pid, string memory _imageURI) public {

        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        uint256 amount = 1;
        uint256 
            price = cryptoMinerPrice;
            require(!minerPaused, "Bitcoin miner minting is paused"); // Check if Bitcoin minting is paused
            require(cryptominer.minersHashing.add(amount) <= bitcoinMinerSupply, "Bitcoin miner supply exceeded");
            require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
            paytoken.transferFrom(msg.sender, address(this), price.mul(amount));
            

            uint256 minerToken = _btcMinerTokenIds.current().add(1);
            minerMints[msg.sender]++;
            miners[minerToken] = Miner({
                
                tokenId: minerToken,
                token: "Bitcoin", // Replace this with the appropriate token name
                name: "JohnnyNewcome", // Miner name
                hashrate: initialHashrate, // Replace this with the appropriate hashrate
                hashMeasured: "VH", // Measured in VoxelHashes
                rewardPerBlock: initialHashrate.mul(cryptoReward), // Calculate the rewardPerBlock based on hashrate and cryptoReward
                lastUpdateBlock: block.number, // Initialize the lastUpdateBlock with the current block
                accumulated: 0,
                dailyEstimate: initialHashrate.mul(cryptoReward).mul(dailyBlocks),
                imageURI: _imageURI
                });
                safeMintBtcMiner(msg.sender);

                cryptominer.minersHashing = cryptominer.minersHashing.add(amount);
                cryptominer.minerTokenIds.push(minerToken);
                cryptominer.totalHashrate = cryptominer.totalHashrate.add(initialHashrate.mul(amount));
                bitcoinMinerSupply ++;
        
    }
    // Boost a miners hashrate
    function boostMinerHash(uint256 tokenId, uint256 _pid) public {
        // Ensure the caller is the owner of the miner
        address owner = ownerOf(tokenId);
        require(tokenId >= 1 && tokenId < 2000, "invalid token Id");
        require(msg.sender == owner, "Not the owner of the token");
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        // Deduct the boost cost from the sender's balance
        uint256 price = minerBoostRate;
            require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
            paytoken.transferFrom(msg.sender, address(this), price);

        // Get the miner details
        Miner storage miner = miners[tokenId];
        
        // Update the token stats based on the boosted miner's parameters
            miner.accumulated = (block.number.sub(miner.lastUpdateBlock).mul(cryptoReward)).mul(miner.hashrate).add(miner.accumulated);
            miner.hashrate = miner.hashrate.add(hsh);
            miner.rewardPerBlock = miner.hashrate.mul(cryptoReward);
            miner.lastUpdateBlock = block.number;
            miner.dailyEstimate = miner.rewardPerBlock.mul(dailyBlocks);
            cryptominer.totalHashrate = cryptominer.totalHashrate.add(1);
    }

    // Update the name of a miner
    function updateMinerName(uint256 _tokenId, string memory _newName, uint256 _pid) public {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        require(bytes(_newName).length <= 14, "Name exceeds 14 characters limit");

        address owner = ownerOf(_tokenId);
        require(owner != address(0), "Invalid token Id"); // Check if the token exists
        require(msg.sender == owner, "Not the owner of the token");

        // Deduct the boost cost from the sender's balance
        require(paytoken.balanceOf(msg.sender) >= burnAmount, "Insufficient funds");
        paytoken.transferFrom(msg.sender, address(0), burnAmount);

        Miner storage miner = miners[_tokenId];
        miner.name = _newName;
    }


    function claimRewards(uint256 tokenId) public {
       require(tokenId >= 1 && tokenId < 13999, "invalid token Id");
        uint256 _pid = 0; // whatever the reward tokens id is
        address user = msg.sender; // the address is a required parameter of the pool contract

        // Check if the caller owns the token
        require(minerOwners[tokenId] == user, "Not the owner of the token");
        
        Miner storage miner = miners[tokenId];
        // Distribute rewards to the user
        uint256 rewards = getPendingRewards(tokenId); // Implement reward calculation
        // Call the appropriate claim function in the DistributionPool contract based on minerType
        IDistributionPool(dp).claim(user, _pid, rewards);
        
        miner.accumulated = 0;
        miner.lastUpdateBlock = block.number;

        // Emit an event or perform other actions as needed
        emit RewardClaimed(user, tokenId);
    }

    // Retrieve pending rewards for a miner
    function getPendingRewards(uint256 tokenId) public view returns (uint256) {
        Miner storage miner = miners[tokenId];

        uint256 currentBlockNumber = block.number;
        uint256 blocksSinceLastUpdate = currentBlockNumber.sub(miner.lastUpdateBlock);

        // Determine which miners reward is being retrieved
        uint256 rewards = blocksSinceLastUpdate.mul(cryptoReward).mul(miner.hashrate).add(miner.accumulated).div(10**10);
        return rewards;
    }


    // Safemint

    function safeMintBtcMiner(address to) internal {
        uint256 tokenId = _btcMinerTokenIds.current().add(1);
        _btcMinerTokenIds.increment();
        minerOwners[tokenId] = msg.sender;
        _safeMint(to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // onlyOwner functions

    // Initialize chest contract
    function initializeDp(
        address _dp
        ) external onlyOwner {
        dp = _dp;
    }

    // Add an erc20 token to be used in the contract
    function addCurrency(
        IERC20 _paytoken, string memory _name
    ) public onlyOwner {
        AllowedCrypto.push(
            TokenInfo({
                paytoken: _paytoken, name: _name
            })
        );
    }

    // Update the token address and name for a specific id being used in the contract
    function updateCurrency(uint256 _pid, IERC20 _newPaytoken, string memory _newName) public onlyOwner {
        require(_pid < AllowedCrypto.length, "Invalid pid");
        
        TokenInfo storage tokenInfo = AllowedCrypto[_pid];
        tokenInfo.paytoken = _newPaytoken;
        tokenInfo.name = _newName;
    }

    // Function to update the claim token contract address if needed
    function initializeCm(address _cm) public onlyOwner {
        cm = _cm;
    }

    // Pause minting or boosting if necessary
    function toggleMinerPaused() public onlyOwner {
        minerPaused = !minerPaused;
    }

    // Set rate for PROSPECT token used to boost miner
    // a rate of 1 would be equivalent to; 1 PROSPECT to 1 ETH
    // a rate of 10 would be equivalent to; 10 PROSPECT to 1 ETH
    function setRate(uint256 _pid, uint _rate) public onlyOwner {
        rates[_pid] = _rate;
    }

    // Set the hashrate for the overall distribution pool
    // Can be adjusted daily according to the amount of tokens you want to distribute
    // Final calculation works with setRewardEmissionRate function to determine
    // how many rewards will be distributed to each miner
    function setGlobalHashrate(uint256 _hashrate) public onlyOwner {
        setHashrate = _hashrate;
    }
    // Number of daily blocks, needs to be set
    // This can be an estimate
    // Also used in the setRewardEmissionRate function
    function setDailyBlocks(uint256 _dBlocks) public onlyOwner {
        dailyBlocks = _dBlocks;
    }

    // Set global emission rates for all miner tokens, using Stat structs to obtain tokenIds for each miner
    // Reward emission rate
    

    function setRewardEmissionRate(uint256 _minedRewards) public onlyOwner {
        uint256 rewardsPerVH = _minedRewards.div(setHashrate); // Convert to the token's precision

        

        uint256[] memory totalMinerTokenIds = cryptominer.minerTokenIds;

        for (uint256 i = 0; i < totalMinerTokenIds.length; i++) {
            uint256 tokenId = totalMinerTokenIds[i];
            Miner storage miner = miners[tokenId];
            // log accumulated rewards before updating global hashrate
            miner.accumulated = (block.number.sub(miner.lastUpdateBlock).mul(cryptoReward)).mul(miner.hashrate).add(miner.accumulated);
            miner.lastUpdateBlock = block.number;
            // Set the new global reward per block
            cryptoReward = rewardsPerVH.div(dailyBlocks);
            // Calculate the rewardPerBlock with the token's precision
            miner.rewardPerBlock = cryptoReward.mul(miner.hashrate);
            miner.dailyEstimate = miner.rewardPerBlock.mul(dailyBlocks);

        }
    }

    // Set the price for boosting a miner
    function setMinerBoostRate(uint256 _rate) public onlyOwner {
        minerBoostRate = _rate;
    }

    // Set the price for purchasing a miner
    function setCryptoMinerPrice(uint256 _price) public onlyOwner {
        cryptoMinerPrice = _price;
    }

    // Set the amount of tokens to burn, used for updating your miners name
    function setBurnAmount(uint256 _amount) public onlyOwner {
        burnAmount = _amount;
    }

    // Withdraw PROSPECT and other ERC20 tokens used in the contract
    function withdraw(uint256 _pid) public payable onlyOwner() {
            TokenInfo storage tokens = AllowedCrypto[_pid];
            IERC20 paytoken;
            paytoken = tokens.paytoken;
            paytoken.transfer(msg.sender, paytoken.balanceOf(address(this)));
    }

    // Withdraw Ethereum tokens
    function withdraw() public onlyOwner {
        uint amount = address(this).balance;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success,"Failed to withdraw");
   }

}