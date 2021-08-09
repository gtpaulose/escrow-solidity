pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Escrow is Ownable, ERC721 {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

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

        uint256 claimTokenID;
    }

    Counters.Counter private _claimtokenIds;

    mapping(address => AssetBalance) private escrowBalances;
    mapping(AssetType => address) private tokenAddresses;
    
    uint256 private _fee;
    // maximum number of withdrawable escrow payments for an address
    // this prevents large loops and unexpected state modification
    uint16 private _max;

    constructor(address erc20, address erc721) ERC721("Claim Token", "CTKN"){
        tokenAddresses[AssetType.ERC20] = erc20;
        tokenAddresses[AssetType.ERC721] = erc721;
        _fee = 0.001 ether;
        _max = 10;
    }

    /** 
    * @dev Check the caller has created the order referenced with the given orderId
     *
     */
    modifier eitherAdminOrOwner(address account) {
        require((msg.sender == owner()) || (msg.sender == account), "not authorized");
        _;
    }

    /** 
    * @dev gets the amount of locked token in escrow for a given account
     *
     */
    function escrowBalance(address account) public view eitherAdminOrOwner(account) returns (uint256, uint256, uint256) {
        require((msg.sender == owner()) || (msg.sender == account), "not authorized");
        return (
            escrowBalances[account].erc20,
            escrowBalances[account].erc721,
            escrowBalances[account].assets.length
        );
    }

    /** 
    * @dev returns the assets left to be claimed for an address along with the claim tokenID
     *
     */
    function getClaimDetails(address account) public view eitherAdminOrOwner(account) returns (uint256, uint256) {
        return (
            escrowBalances[account].assets.length,
            escrowBalances[account].claimTokenID
        );
    }

    function updateMaxAssets(uint16 max) public onlyOwner {
        _max=max;
    }

    function updateFee(uint256 fee) public onlyOwner {
        _fee=fee;
    }

    function deposit(Asset[] memory assets) payable external {
        require(msg.value == _fee.mul(assets.length), "incorrect payment to perform transaction");
        for (uint i = 0; i < assets.length; i++){
            Asset memory asset = assets[i];
            require(escrowBalances[asset.recipient].assets.length < _max, "too many unclaimed assets for recipient");
            
            if (asset.assetType == AssetType.ERC20){
                escrowBalances[asset.recipient].erc20 = escrowBalances[asset.recipient].erc20.add(asset.amount);
                escrowBalances[asset.recipient].assets.push(asset);

                require(IERC20(tokenAddresses[AssetType.ERC20]).transferFrom(msg.sender, address(this), asset.amount), "token transfer failed");
            } else{
                escrowBalances[asset.recipient].erc721 = escrowBalances[asset.recipient].erc721.add(1);
                escrowBalances[asset.recipient].assets.push(asset);

                IERC721(tokenAddresses[AssetType.ERC721]).transferFrom(msg.sender, address(this), asset.tokenId);
            }

            if (escrowBalances[asset.recipient].claimTokenID == 0){
                uint256 _claimTokenID = _mint(asset.recipient);
                escrowBalances[asset.recipient].claimTokenID = _claimTokenID;
            }
        }

        payable(owner()).transfer(msg.value);
    }

    function withdraw() external{
        require(escrowBalances[msg.sender].erc20 > 0 || escrowBalances[msg.sender].erc721 > 0, "nothing to withdraw");
        bool withdrawn = false;
        for (int i = 0; i < int(escrowBalances[msg.sender].assets.length); i++){
            Asset memory asset = escrowBalances[msg.sender].assets[uint(i)];
            if (asset.endTime < block.timestamp){
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
        _burn(escrowBalances[msg.sender].claimTokenID);
    }

    function _burn(uint256 _claimtokenId) internal override {
        require(balanceOf(msg.sender) == 1, "no claim token");
        if (escrowBalances[msg.sender].assets.length == 0){
            escrowBalances[msg.sender].claimTokenID = 0;
            super._burn(_claimtokenId);
        }
    }


     function _mint(address recipient) internal returns (uint256)
    { 
        _claimtokenIds.increment();
        _mint(recipient, _claimtokenIds.current());
        return _claimtokenIds.current();
    }
}