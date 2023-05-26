// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";

interface IERC20Token {
  function transfer(address, uint256) external returns (bool);
  function balanceOf(address) external view returns (uint256);
}

contract DropTheNews is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    constructor() ERC721("Proof of Tips", "POT") {}

    uint public newsLength = 0;
    address internal cUsdTokenAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1; // cUSd token contract address

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
        uint tipIndex;
    }

    event NewsPosted(address indexed poster, string title, string description);
    event NewsDeleted(address indexed deleter, uint indexed index);
    event NewsLiked(uint indexed index, address indexed liker);
    event NewsDisliked(uint indexed index, address indexed disliker);
    event CreatorTipped(uint indexed index, address indexed tipper, uint amount);
    event NFTClaimed(address indexed claimer, uint256 tokenId, string tokenURI);

    mapping(uint => News) internal postedNews;
    mapping(uint => mapping(address => bool)) public likers;
    mapping(address => Claimer) internal claimers;
    mapping(address => NFTParams) internal claimedNFTs;

    struct NFTParams {
        uint nftId;
        string token_uri;
    }

    function postNews(string calldata _title, string calldata _description) public {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        for (uint i = 0; i < newsLength; i++) {
            require(keccak256(bytes(postedNews[i].title)) != keccak256(bytes(_title)), "News with the same title already exists");
        }

        uint _likes = 0;
        uint _tips = 0;
        postedNews[newsLength] = News(payable(msg.sender), _title, _description, _likes, _tips);
        newsLength++;

        emit NewsPosted(msg.sender, _title, _description);
    }

    function getNews(uint _index) public view returns (address payable, string memory, string memory, uint, uint) {
        require(_index < newsLength, "Invalid news article index");

        return (
            postedNews[_index].owner,
            postedNews[_index].title,
            postedNews[_index].description,
            postedNews[_index].likes,
            postedNews[_index].tips
        );
    }

    function deleteNews(uint _index) public {
        require(_index < newsLength, "Invalid news article index");
        require(msg.sender == postedNews[_index].owner, "Only the news creator can delete the news");

        for (uint i = _index; i < newsLength - 1; i++) {
            postedNews[i] = postedNews[i + 1];
        }

        delete postedNews[newsLength - 1];
        newsLength--;

        emit NewsDeleted(msg.sender, _index);
    }

    function likeAndDislikeNews(uint _index) public {
        require(_index < newsLength, "Invalid news article index");

        bool currentLikeStatus = likers[_index][msg.sender];

        if (!currentLikeStatus) {
            postedNews[_index].likes++;
        } else {
            postedNews[_index].likes--;
        }

        likers[_index][msg.sender] = !currentLikeStatus;

        if (!currentLikeStatus) {
            emit NewsLiked(_index, msg.sender);
        } else {
            emit NewsDisliked(_index, msg.sender);
        }
    }

    function tipCreator(uint _index, uint _amount) public payable {
        require(_index < newsLength, "Invalid news article index");

        News storage newsCreator = postedNews[_index];
        address _receiver = newsCreator.owner;

        require(IERC20Token(cUsdTokenAddress).balanceOf(msg.sender) >= _amount, "Insufficient balance in cUSD token");

        require(
            IERC20Token(cUsdTokenAddress).transfer(_receiver, _amount),
            "Transfer of tips failed"
        );

        if (!claimers[msg.sender].isEligible) {
            claimers[msg.sender].isEligible = true;
            claimers[msg.sender].tipIndex = _index;
        }

        newsCreator.tips += _amount;

        emit CreatorTipped(_index, msg.sender, _amount);
    }

    function claimNFT(string calldata tokenURI) public {
        require(claimers[msg.sender].isEligible, "You are not eligible to claim the NFT");
        require(!claimers[msg.sender].isClaimed, "You have already claimed your NFT");
        require(claimers[msg.sender].tipIndex < newsLength, "Invalid news article index");

        uint _index = claimers[msg.sender].tipIndex;
        uint _amount = postedNews[_index].tips;

        require(_amount > 0, "You have not tipped the creator");

        tokenId.increment();
        uint256 newItemId = tokenId.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        claimers[msg.sender].isClaimed = true;

        claimedNFTs[msg.sender] = NFTParams(newItemId, tokenURI);

        emit NFTClaimed(msg.sender, newItemId, tokenURI);
    }

    function getClaimedNFT() public view returns (uint, string memory) {
        NFTParams storage claimedNFT = claimedNFTs[msg.sender];

        return (
            claimedNFT.nftId,
            claimedNFT.token_uri
        );
    }
}
