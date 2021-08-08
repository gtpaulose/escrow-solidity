pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenERC20 is ERC20, Ownable{
    constructor() ERC20("TEST", "TST") {}

    function mint(uint256 amount) external{
        _mint(msg.sender, amount);
    }
}