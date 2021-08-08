pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TokenERC721 is ERC721, Ownable{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("TEST", "TST") {}

    function mint() external returns (uint256)
    { 
         _tokenIds.increment();
        _mint(msg.sender, _tokenIds.current());
        return _tokenIds.current();
    }
}