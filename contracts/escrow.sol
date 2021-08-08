pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract Escrow is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;

    enum AssetType {ERC20,ERC721}

    struct Asset {
        AssetType assetType;

        address recipient;
       
        uint256 tokenId;
        uint256 amount;
       
        uint256 endTime;
    }

    struct AssetBalance{
        uint256 erc20;
        uint256 erc721;
        Asset[] assets;
    }

    mapping(address => AssetBalance) private escrowBalances;
    mapping(AssetType => address) private tokenAddresses;
    uint256 private fee;
    // maximum number of withdrawable escrow payments for an address
    // this prevents large loops and unexpected state modification
    uint16 private max;

    constructor(address erc20, address erc721){
        tokenAddresses[AssetType.ERC20] = erc20;
        tokenAddresses[AssetType.ERC721] = erc721;
        fee = 0.001 ether;
        max = 10;
    }

    /** 
    * @dev gets the amount of locked token in escrow for a given account
     *
     */
    function balanceOf(address account) public view returns (uint256, uint256) {
        require((msg.sender == owner()) || (msg.sender == account), "not authorized");
        return (
            escrowBalances[account].erc20,
            escrowBalances[account].erc721
        );
    }

    function deposit(Asset[] memory assets) payable external {
        require(msg.value == fee.mul(assets.length), "insufficient payment to perform transaction");
        for (uint i = 0; i < assets.length; i++){
            Asset memory asset = assets[i];
            require(asset.assetType == AssetType.ERC20 || asset.assetType == AssetType.ERC721, "Incorrect asset type");
            require(escrowBalances[asset.recipient].assets.length < max, "too many unwithdrawn assets for recipient");
            
            if (asset.assetType == AssetType.ERC20){
                escrowBalances[asset.recipient].erc20 = escrowBalances[asset.recipient].erc20.add(asset.amount);
                escrowBalances[asset.recipient].assets.push(asset);

                require(IERC20(tokenAddresses[AssetType.ERC20]).transferFrom(msg.sender, address(this), asset.amount), "token transfer failed");
            } else{
                escrowBalances[asset.recipient].erc721 = escrowBalances[asset.recipient].erc721.add(1);
                escrowBalances[asset.recipient].assets.push(asset);

                IERC721(tokenAddresses[AssetType.ERC721]).transferFrom(msg.sender, address(this), asset.tokenId);
            }
        }

        payable(owner()).transfer(msg.value);
    }

    function withdraw() external{
        require(escrowBalances[msg.sender].erc20 > 0 || escrowBalances[msg.sender].erc721 > 0, "nothing to withdraw");
        bool withdrawn = false;
        for (int i = 0; i < int(escrowBalances[msg.sender].assets.length); i++){
            Asset memory asset = escrowBalances[msg.sender].assets[uint(i)];
            if (asset.endTime == 0 || asset.endTime < block.timestamp){
                withdrawn = true;
                if (asset.assetType == AssetType.ERC20){
                    escrowBalances[msg.sender].erc20 = 0;
                    require(IERC20(tokenAddresses[AssetType.ERC20]).transfer(msg.sender, asset.amount), "token transfer failed");
                } else{
                    escrowBalances[msg.sender].erc721 = escrowBalances[msg.sender].erc721.sub(1);
                    IERC721(tokenAddresses[AssetType.ERC721]).transferFrom(address(this), msg.sender, asset.tokenId);
                }
                uint l = escrowBalances[msg.sender].assets.length;
                if (l - 1 > 0){
                    escrowBalances[msg.sender].assets[uint(i)] = escrowBalances[msg.sender].assets[l - 1];
                    i--;
                }
                escrowBalances[msg.sender].assets.pop();
            }
        }

        require(withdrawn, "nothing to withdraw");
        escrowBalances[msg.sender]=escrowBalances[msg.sender];
    }

}