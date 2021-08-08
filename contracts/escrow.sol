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

    constructor(address erc20, address erc721){
        tokenAddresses[AssetType.ERC20] = erc20;
        tokenAddresses[AssetType.ERC721] = erc721;
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

    function deposit(Asset[] memory assets, address recipient) external {
        for (uint i = 0; i < assets.length; i++){
            Asset memory asset = assets[i];
            require(asset.assetType == AssetType.ERC20 || asset.assetType == AssetType.ERC721, "Incorrect asset type");
            if (asset.assetType == AssetType.ERC20){
                escrowBalances[recipient].erc20 = escrowBalances[recipient].erc20.add(asset.amount);
                escrowBalances[recipient].assets.push(asset);

                require(IERC20(tokenAddresses[AssetType.ERC20]).transferFrom(msg.sender, address(this), asset.amount), "token transfer failed");
            } else{
                escrowBalances[recipient].erc721 = escrowBalances[recipient].erc721.add(1);
                escrowBalances[recipient].assets.push(asset);

                IERC721(tokenAddresses[AssetType.ERC721]).transferFrom(msg.sender, address(this), asset.tokenId);
            }
        }
    }

    function withdraw() external{
        require(escrowBalances[msg.sender].erc20 > 0 || escrowBalances[msg.sender].erc721 > 0, "nothing to withdraw");
        bool withdrawn = false;
        for (uint i = 0; i < escrowBalances[msg.sender].assets.length; i++){
            Asset memory asset = escrowBalances[msg.sender].assets[i];
            if (asset.endTime == 0 || asset.endTime > block.timestamp){
                withdrawn = true;
                if (asset.assetType == AssetType.ERC20){
                    escrowBalances[msg.sender].erc20 = 0;
                    require(IERC20(tokenAddresses[AssetType.ERC20]).transfer(msg.sender, asset.amount), "token transfer failed");
                } else{
                    escrowBalances[msg.sender].erc721 = escrowBalances[msg.sender].erc721.sub(1);
                    IERC721(tokenAddresses[AssetType.ERC721]).transferFrom(address(this), msg.sender, asset.tokenId);
                }
                delete escrowBalances[msg.sender].assets[i];
            }
        }

        require(withdrawn, "nothing to withdraw");
        escrowBalances[msg.sender]=escrowBalances[msg.sender];
    }


}