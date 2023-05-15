// SPDX-License-Identifier: MIT  
pragma solidity >=0.7.0 <0.9.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";

interface IERC20Token {
  function transfer(address, uint256) external returns (bool);
  function approve(address, uint256) external returns (bool);
  function transferFrom(address, address, uint256) external returns (bool);
  function totalSupply() external view returns (uint256);
  function balanceOf(address) external view returns (uint256);
  function allowance(address, address) external view returns (uint256);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

// https://gateway.pinata.cloud/ipfs/QmTm9gokrJsHY8PWRUbHmCBdULUoaQZsgiqRWoLjEiwR1K (tokenuri)

contract DropTheNews is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    constructor() ERC721("Proof of Tips", "POT") {} 
    uint public newsLength = 0; 
    // uint public nftID = 1; 
    
    address internal cUsdTokenAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;  //cUSd token contract address

	struct News {
		address payable owner;
		string title;
		string description;
		uint likes;
        uint tips;
	}

    struct Claimer {
        bool isEligible;
        bool isClaimed;
    }

    struct NFTParams {
        uint nftId;
        string token_uri;
    }

    event NewsPosted(address indexed poster, string title, string description);
    event NewsDeleted(address indexed deleter, uint indexed index);
    event NewsLiked(uint indexed index, address indexed liker);
    event NewsDisliked(uint indexed index, address indexed disliker);
    event CreatorTipped(uint indexed index, address indexed tipper, uint amount);
    event NFTClaimed(address indexed claimer, uint256 tokenId, string tokenURI);



	//mapping for posted news
    mapping(uint => News) internal postedNews;


    mapping(uint => mapping(address => bool)) public likers;

	//mapping for addresses eligible to claim NFT 
    mapping(address => Claimer) internal claimers; // Addresses eligible to claim NFT (addresses that tipped), can only claim once

    // claimed NFTS
    mapping (address => NFTParams) internal claimedNFTs;

    // post news
    function postNews(string calldata _title, string calldata _description) public {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        for (uint i = 0; i < newsLength; i++) {
        if (keccak256(abi.encodePacked(postedNews[i].title)) == keccak256(abi.encodePacked(_title))) {
            revert("News with same title already exists.");
        }
    }

        uint _likes = 0;
        uint _tips = 0;
        postedNews[newsLength] = News(payable(msg.sender), _title, _description, _likes, _tips);
        newsLength++;

        emit NewsPosted(msg.sender, _title, _description);
    }

	// Fetch a news
    function getNews(uint _index) public view returns(address payable, string memory, string memory, uint, uint) {
        return 
        (
            postedNews[_index].owner,
            postedNews[_index].title,
            postedNews[_index].description,
            postedNews[_index].likes,
            postedNews[_index].tips

        );
    }

    function deleteNews(uint _index) public {
        require(msg.sender == postedNews[_index].owner, "Only news creator can delete news");

        delete postedNews[_index];
        emit NewsDeleted(msg.sender, _index);
    }

    // Like and dislike news
    function likeAndDislikeNews(uint _index) public {


        if(likers[_index][msg.sender] == false) {
            likers[_index][msg.sender] = true;
            postedNews[_index].likes++;
            emit NewsLiked(_index, msg.sender);
            
        } else if(likers[_index][msg.sender] == true) {
            likers[_index][msg.sender] = false;
            postedNews[_index].likes--;
            emit NewsDisliked(_index, msg.sender);
        }
    }

    function tipCreator(uint _index, uint _amount) public payable {

        require(_index < newsLength, "Invalid news article index");
        
        News memory newsCreator = postedNews[_index];
        address _receiver = newsCreator.owner;
        require(IERC20Token(cUsdTokenAddress).balanceOf(msg.sender) >= _amount, "Insufficient balance in cUSD token");
        require(
            IERC20Token(cUsdTokenAddress).transferFrom(msg.sender, _receiver, _amount), "Transfer failed."
        );

        // Make msg.sender eligible to claim NFT
        if(claimers[msg.sender].isEligible == false) {
            claimers[msg.sender].isEligible = true;
        }
        // // Increment tips
        postedNews[_index].tips = postedNews[_index].tips + _amount;

        emit CreatorTipped(_index, msg.sender, _amount);


    }

    function claimNFT(string calldata tokenURI) public {
        // In the frontend, upload NFT image and metadata on ipfs, pass the medata hash url as the uri parameter

        require(claimers[msg.sender].isEligible == true, "You are not eligible to claim NFT");
        require(claimers[msg.sender].isClaimed == false, "You have already claimed your NFT");
        tokenId.increment();
        uint256 newItemId = tokenId.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        // Can't claim twice
        claimers[msg.sender].isClaimed = true;

        // SET CLAIMED NFT
        claimedNFTs[msg.sender] = NFTParams(newItemId, tokenURI);

        emit NFTClaimed(msg.sender, newItemId, tokenURI);
    }

    function getClaimedNFT() public view returns(uint, string memory) {
        return (
            claimedNFTs[msg.sender].nftId,
            claimedNFTs[msg.sender].token_uri
        );
    }
}
