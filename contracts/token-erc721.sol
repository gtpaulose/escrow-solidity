pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract TokenERC721 is ERC721, Ownable{
    constructor() ERC721("TEST", "TST") {}
}