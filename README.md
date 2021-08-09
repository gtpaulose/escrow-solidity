# Escrow

An escrow contract written in solidity which allows users to deposit any ERC20 and/or ERC721 token to the escrow, to be withdrawn by a specified recipient. The depositor can specify an end time which locks the assets till that specified time. 

To enable thorough testing, sample ERC20 and ERC721 contracts have been included in the contract folder.
## Overview

The only prerequisite to use the escrow contract is that the token should be transferrable on behalf of the depositor. This can done be by using the `approve()` function present in all ERC20 contracts and the `approveForAll()` function present in all ERC721 contracts. By doing so, will add the escrow contract as an approver, so it can transfer the specified tokens from depositor's address to the escrows contract's address.

### Deposit
This function can be used by any user to deposit assets to the escrow. The depositor must specify the asset type _(0 for ERC20 tokens and 1 for ERC721 tokens)_, the corresponding token contract address _(this will allow the escrow contract to interface with token contract)_ and recipient address. When depositing ERC20 tokens, the user can specify the amount of tokens to deposit and for ERC721 tokens, the user can specify the tokenID to deposit. Finally, the user can also specify the end time for withdrawal. This is a unix timestamp that specifies the time post which the recipient can claim the corresponding asset. 

Users can also deposit multiple assets to multiple recipients into the escrow in one function call. This however is limited by an internal variable called `_max`. This will prevent large backlog of unclaimed assets in the contract for a specific recipient, which could result in high gas fees and unexpected state modification. 

For each asset deposit, a fee is taken from the depositor (0.001 ether default) and credited to the contract owner (admin).

Each recipient will also receive a claim token to be used to withdraw the assets.

Eg,
```
[
  [ 0, 0xF008880ba4eB87d79Dd4688511ebBc25cf69DB06, 0xE107F3488C7699938A583983d34668805F9F2C02, 0, 14, 1660043368 ],
  [ 1, 0x2000b8F5CbEE128054B432EFbd3E431b0136D5e6, 0xE107F3488C7699938A583983d34668805F9F2C02, 56, 0, 0 ],
  [ 0, 0xF008880ba4eB87d79Dd4688511ebBc25cf69DB06, 0x10bc83E08178FD803e45d146d68611c6f6B918e1, 0, 5, 0 ],
]
```

The above deposit request, interacts with 2 different token contracts (ERC20 - `0xF008880ba4eB87d79Dd4688511ebBc25cf69DB06` and ERC721 - `0x2000b8F5CbEE128054B432EFbd3E431b0136D5e6`) and will deposit assets to two recipients: 

1. `0xE107F3488C7699938A583983d34668805F9F2C02` - 14 ERC20 tokens which can be claimed on 22/08/2022 and ERC721 token corresponding to `tokenID=56` which can be claimed instantly
2.  `0xF008880ba4eB87d79Dd4688511ebBc25cf69DB06` - 5 ERC20 tokens which can be claimed instantly

The total fees incurred by the depositor will be no. of indivual requests multipled by the fixed fee, i.e `3 * 0.001 = 0.003 ether`

### Withdraw
Recipients can withdraw assets from the escrow. The function will only execute if the user has assets that can be withdrawn, so as to save gas fees. The criteria for claimable assets are if either the ERC20 or ERC721 balances for the recipient more than 0 and the time is greater than the lock-in time for at least one asset. Once all assets have been withdrawn, the associated claim token will be burnt. 

### Claim Token
Whenever a deposit is made to the escrow contract, a claim token is minted and transferred to the recipient. This serves to increase the security of the withdrawal workflow. Only one claim token is issued per recipient per assets in claim list, i.e if a recipient has no assets to claim, then when the first deposit request is processed they will receive a claim token. If the user doesn't or is unable to claim the asset and a user deposits additional assets for the recipient to claim, the contract will not issue another claim token. 

The existing claim token is enough to withdraw all assets in the list. If ever the list becomes empty, the claim token is burnt. This saves gas fees instead of issuing claim tokens for every deposit. If the user does not have a claim token at the time of withdrawal, the contract throws an error.

### Admin and Misc Functions
Admins can set new values for fees and max unclaimed asset limit. 
As added security, only admins and recipients can view an address' current escrow balance and claim token details. 

## Commands

### Test

For `.zsh` shells, users will have to manually source the `.env`

```bash
$ npm run test
```

 _Test cases are purposely verbose to help elucidate and support the contract_

### Compile

```bash
$ npm run compile
```

## Assumptions
1. There is a maximum number of assets that can be left unclaimed for a recipient (reason above)
2. Claim token is fixed while there are assets left to claim (reason above)
3. Fee is taken as a function of number of individual deposit  requests and fees are taken only from the depositor
4. Escrow end time is not mandatory and if supplied corresponds to the absolute time after which the recipient can claim the asset
5. Exact fees are passed to the function