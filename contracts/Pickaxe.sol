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
import "./interfaces/ICryptoMiner.sol";

import "hardhat/console.sol";


contract Pickaxes is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    // Event handling
    event TokensMinted(address indexed owner, uint256 amount);
    event MinerStarted(string minerType, address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 tokenId);

    // Pickaxe counter
    Counters.Counter private _commonTokenIds;

    // Pickaxe supply control
    uint256 public commonSupply = 250;

    uint256 public constant pwr = 1; // pickaxe pickaxePower increase value

    address public cm; // crypto miner contract

    // Pickaxe Data
    struct Pickaxe {
        string pickaxeType; // the pickaxe type
        uint256 pickaxePower; // individual pickaxe power
        string imageURI; // pickaxe image
    }

    mapping(uint256 => Pickaxe) public pickaxes; // Access pickaxe struct
    mapping(uint256 => address) private minerOwners; // Pickaxe owners by address
    mapping (address => uint) public pickaxeMints; // Tracking of pickaxes minted per user
    mapping(address => uint) public requiredPower; // keeps track of required power for an address to upgrade pickaxe or mint miner
    

    constructor(address _cm
    ) ERC721("Pickaxes", "pAXE") {
        cm = _cm;
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
        Pickaxe memory pickaxeToken = pickaxes[_tokenId];

        string memory pickPWR = Strings.toString(pickaxeToken.pickaxePower);

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                pickaxeToken.pickaxeType,
                ' -- Pickaxe #: ',
                Strings.toString(_tokenId),
                '", "description": "Boost your Pickaxe power to rank up!", "image": "',
                pickaxeToken.imageURI,
                '", "attributes": [ { "trait_type": "Pickaxe Power", "value": ',pickPWR,'}]}'
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    // Mint a pickaxe
    function mintPickaxe(string memory _imageURI) public {
            uint256 pickaxeToken = _commonTokenIds.current().add(1);
           
            pickaxes[pickaxeToken] = Pickaxe({  
                pickaxeType: "Common",
                pickaxePower: 0, // Replace this with the appropriate power
                imageURI: _imageURI
                });
                safeMintCommonPickaxe(msg.sender);

             pickaxeMints[msg.sender]++;
             requiredPower[msg.sender] = 8;
        
    }
    // Boost a pickaxes hashrate
    function boostPickaxePower(uint256 tokenId) internal {
        // Ensure the caller is the owner of the pickaxe
        address owner = ownerOf(tokenId);
        require(tokenId >= 1 && tokenId < 30000, "invalid token Id");
        require(msg.sender == owner, "Not the owner of the token");

        // Get the pickaxe details
        Pickaxe storage pickaxe = pickaxes[tokenId];
        
        // Update the token stats based on the boosted pickaxe's parameters
            pickaxe.pickaxePower = pickaxe.pickaxePower.add(pwr);
    }

    function mintMiner(uint256 tokenId) external {
            uint256 _pid = 0;
            Pickaxe storage pickaxe = pickaxes[tokenId];
            require(pickaxe.pickaxePower > requiredPower[msg.sender], "your pickaxe does not have enough power");
            ICryptoMiner(cm).mintMiner(_pid);

            pickaxe.pickaxePower = pickaxe.pickaxePower.sub(8);        
        
    }

    // Safemint

    function safeMintCommonPickaxe(address to) internal {
        uint256 tokenId = _commonTokenIds.current().add(1);
        _commonTokenIds.increment();
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

}