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

    // allowable AssetTypes that can be deposited in the escrow
    enum AssetType {ERC20,ERC721}

    // Asset represents an escrow deposit request 
    // An array of the following structure can be passed to the deposit function
    // The same structure will be used transfer the necessary tokens to the recipient
    struct Asset {
        // AssetType corresponding to the Asset
        AssetType assetType;
        // address of the token contract
        address token;

        // recipient of the asset
        address recipient;
       
       // in case of ERC721, associated tokenID
        uint256 tokenId;
        // in case of ERC20, associated amount
        uint256 amount;
       
       // endTime corresponds to the timestamp after which the user can withdraw the asset from escrow
       // to set no endTime, simply pass 0
        uint256 endTime;
    }

    // Consolidated view of a recipients escrow balance
    struct AssetBalance{
        uint256 erc20;
        uint256 erc721;
        Asset[] assets;

        // claimTokenID for all current assets in array
        uint256 claimTokenID;
    }

    Counters.Counter private _claimtokenIds;

    mapping(address => AssetBalance) private escrowBalances;
    
    // fee taken for every escrow deposit
    uint256 private _fee;
    // maximum number of withdrawable escrow payments for an address
    // this prevents large loops and unexpected state modification
    uint16 private _max;

    constructor() ERC721("Claim Token", "CTKN"){
        _fee = 0.001 ether;
        _max = 10;
    }

    /** 
     * @dev Check if the caller is either the admin or the owner of the account
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

    /** 
     * @dev returns the balance of the claim token for an account
     *
     */
    function balanceOfClaimToken(address account) public view eitherAdminOrOwner(account) returns (uint256){
        return balanceOf(account);
    }

    /** 
     * @dev updates maximum assets that can be unclaimed by the user. Updating this may lead to large gas fees
     *
     */
    function updateMaxAssets(uint16 max) public onlyOwner {
        _max=max;
    }

    /** 
     * @dev updates the fee taken by the escrow admin for each deposit
     *
     */
    function updateFee(uint256 fee) public onlyOwner {
        _fee=fee;
    }

    /** 
     * @dev deposit will add assets to be claimed by the corresponding recipients to the state
     * each deposit incurs a fee calculated by (num_of_deposits * _fee)
     * the function will prevent insertion greater than _max
     * assets are transfered to the contract address
     * if the recipient doesn't have a claim token, they are issued one. this will be used to withdraw the assets in escrow
     */
    function deposit(Asset[] memory assets) payable external {
        require(msg.value == _fee.mul(assets.length), "incorrect payment to perform transaction");
        for (uint i = 0; i < assets.length; i++){
            Asset memory asset = assets[i];
            require(escrowBalances[asset.recipient].assets.length < _max, "too many unclaimed assets for recipient");
            require(asset.amount != 0 || asset.tokenId != 0, "need to supply either amount or tokenId");
            
            if (asset.assetType == AssetType.ERC20){
                escrowBalances[asset.recipient].erc20 = escrowBalances[asset.recipient].erc20.add(asset.amount);
                escrowBalances[asset.recipient].assets.push(asset);

                require(IERC20(asset.token).transferFrom(msg.sender, address(this), asset.amount), "token transfer failed");
            } else{
                escrowBalances[asset.recipient].erc721 = escrowBalances[asset.recipient].erc721.add(1);
                escrowBalances[asset.recipient].assets.push(asset);

                IERC721(asset.token).transferFrom(msg.sender, address(this), asset.tokenId);
            }

            // mint claim token if doesn't exist
            if (escrowBalances[asset.recipient].claimTokenID == 0){
                uint256 _claimTokenID = _mint(asset.recipient);
                escrowBalances[asset.recipient].claimTokenID = _claimTokenID;
            }
        }

        payable(owner()).transfer(msg.value);
    }

    /** 
     * @dev withdraw will allow recipients to withdraw assets
     * to save on gas fees, the function will return an error if no assets can be withdrawn
     * recipients can only withdraw assets if they have associated asset balances and if the endTime has elapsed
     * existence of the claim token is also checked
     * if an asset is claimed, it is popped from the assets array
     * if all assets are claimed, claim token is burnt
     */
    function withdraw() external {  
        require(escrowBalances[msg.sender].erc20 > 0 || escrowBalances[msg.sender].erc721 > 0, "nothing to withdraw");
        bool withdrawn = false;
        for (int i = 0; i < int(escrowBalances[msg.sender].assets.length); i++){
            Asset memory asset = escrowBalances[msg.sender].assets[uint(i)];
            if (asset.endTime < block.timestamp){
                withdrawn = true;
                
                if (asset.assetType == AssetType.ERC20){
                    escrowBalances[msg.sender].erc20 = 0;
                    require(IERC20(asset.token).transfer(msg.sender, asset.amount), "token transfer failed");
                } else{
                    escrowBalances[msg.sender].erc721 = escrowBalances[msg.sender].erc721.sub(1);
                    IERC721(asset.token).transferFrom(address(this), msg.sender, asset.tokenId);
                }
                
                // swap and pop from the array.
                // decrement loop variable since length of array decreases.
                uint l = escrowBalances[msg.sender].assets.length;
                escrowBalances[msg.sender].assets[uint(i)] = escrowBalances[msg.sender].assets[l - 1];
                i--;
                escrowBalances[msg.sender].assets.pop();
            }
        }

        require(withdrawn, "nothing to withdraw");
        _checkAndburn(escrowBalances[msg.sender].claimTokenID);
    }

    /** 
     * @dev _checkAndburn will check for the existence of the token and burn the token if all assets are withdrawn
     */
    function _checkAndburn(uint256 _claimtokenId) internal {
        require(balanceOfClaimToken(msg.sender) == 1, "no claim token");
        if (escrowBalances[msg.sender].assets.length == 0){
            escrowBalances[msg.sender].claimTokenID = 0;
            super._burn(_claimtokenId);
        }
    }


    /** 
     * @dev _mint will mint the claim token
     */
     function _mint(address recipient) internal returns (uint256)
    { 
        _claimtokenIds.increment();
        _mint(recipient, _claimtokenIds.current());
        return _claimtokenIds.current();
    }
}