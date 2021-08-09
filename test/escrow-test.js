const { expect } = require("chai");
const { revertMessage, deployContracts } = require("../scripts/utils.js");

const hre = require("hardhat");
const timestamp = require("unix-timestamp")
const ethers = hre.ethers;

let deployer, account1, account2, account3;
let account1Addr, account2Addr, account3Addr;
const fee = ethers.constants.WeiPerEther.div(1000); // 0.001 ETH
let tokenERC20, tokenERC721, escrow;

function caluclateFee(num){
    return fee.mul(num * 1000000).div(1000000)
}

function buildPayloadERC20(recipient, amount, endTime){
    return [0, tokenERC20.address, recipient, 0, amount, endTime]
}

function buildPayloadERC721(recipient, tokenId, endTime){
    return [1, tokenERC721.address, recipient, tokenId, 0, endTime]
}

function buildInvalidPayloadERC20(recipient, amount, endTime){
    return [2, tokenERC20.address, recipient, 0, amount, endTime]
}

async function mintSampleERC20Tokens(owner, amount){
    await tokenERC20.connect(owner).mint(amount)
    await tokenERC20.connect(owner).approve(escrow.address, amount)
}

async function mintSampleERC721Tokens(owner, amount){
    for (i = 0; i < amount; i++){
        await tokenERC721.connect(owner).mint()
    }

    await tokenERC721.connect(owner).setApprovalForAll(escrow.address, true)
}


async function initTestVariables() {
    [deployer, account1, account2, account3] = await ethers.getSigners();
    deployerAddr = await deployer.getAddress();
    account1Addr = await account1.getAddress();
    account2Addr = await account2.getAddress();
    account3Addr = await account3.getAddress();
}

async function createContract() {
    const contracts = await deployContracts()
    escrow = contracts.escrow;
    tokenERC20 = contracts.tokenERC20;
    tokenERC721 = contracts.tokenERC721;
}

async function getBlockTimestamp(blockNum){
    const block = await ethers.provider.getBlock(blockNum)
    return block.timestamp
}

async function getLatestBlockNumber(){
    const num = await ethers.provider.getBlockNumber()
    return num
}

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }


describe("Escrow Deployment", async() => {
    before('', async() => {
        await initTestVariables();
    })
    it("Should verify that the escrow contract is deployed", async() => {
        await createContract();
        expect(escrow.address).to.not.equal('0x' + '0'.repeat(32));
    });
});

describe("Escrow Deposit", async() => {
    before('', async() => {
        await initTestVariables();
        await createContract();
        await mintSampleERC20Tokens(account1, 25)
        await mintSampleERC721Tokens(account1, 2)
    })
    it("Should verify initial balances", async() => {
        balances = await escrow.connect(account1).escrowBalance(account1Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(0)
        expect(erc721Balance).to.equal(0)
        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(0)
        expect(erc721Balance).to.equal(0)
        balances = await escrow.connect(account3).escrowBalance(account3Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(0)
        expect(erc721Balance).to.equal(0)
    });
    it("Should throw an error when sending insufficient escrow fee", async() => {
        await expect(escrow.connect(account1).deposit([buildPayloadERC20(account2Addr, 1, 0)])).to.be.revertedWith(revertMessage('incorrect payment to perform transaction'));
    });
    it("Should throw an error when passing an invalid asset type", async() => {
        await expect(escrow.connect(account1).deposit([buildInvalidPayloadERC20(account2Addr, 1, 0)], { value: caluclateFee(1), gasPrice: 0 })).to.be.revertedWith(revertMessage('function was called with incorrect parameters'));
    });
    it("Should throw an error when passing too many escrow requests", async() => {
        payload =[]
        for (i = 0; i<11; i++){
                payload.push(buildPayloadERC20(account2Addr, 1, 0))
        }

       await expect(escrow.connect(account1).deposit(payload, { value: caluclateFee(11), gasPrice: 0 })).to.be.revertedWith(revertMessage('too many unclaimed assets for recipient'));
    });
    it("Should be successful when passing valid erc20 argument and fee", async() => {
        const ethBalanceBefore = await account1.getBalance();
        const tokenBalanceBefore = await tokenERC20.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceBefore = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        
        await escrow.connect(account1).deposit([buildPayloadERC20(account2Addr, 1, 0)], { value: caluclateFee(1), gasPrice: 0 });
        
        const ethBalanceAfter = await account1.getBalance();
        const tokenBalanceAfter = await tokenERC20.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceAfter = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
       
        expect(ethBalanceAfter.eq(ethBalanceBefore.sub(caluclateFee(1)))).to.be.true;
        expect(tokenBalanceAfter.eq(tokenBalanceBefore.sub(1))).to.be.true;
        // since first escrow txn, mint claim token
        expect(claimTokenBalanceBefore).to.equal(0)
        expect(claimTokenBalanceAfter).to.equal(1)

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(1)
        expect(erc721Balance).to.equal(0)
    });
    it("Should be successful when passing multiple erc20 arguments and corresponding fees", async() => {
        const ethBalanceBefore = await account1.getBalance();
        const tokenBalanceBefore = await tokenERC20.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceBefore2 = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const claimTokenBalanceBefore3 = await escrow.connect(account3).balanceOfClaimToken(account3Addr);
        
        await escrow.connect(account1).deposit([
            buildPayloadERC20(account2Addr, 2, 0),
            buildPayloadERC20(account2Addr, 2, 0),
            buildPayloadERC20(account3Addr, 1, 0),
        ], { value: caluclateFee(3), gasPrice: 0 });
        
        const ethBalanceAfter = await account1.getBalance();
        const tokenBalanceAfter = await tokenERC20.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceAfter2 = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const claimTokenBalanceAfter3 = await escrow.connect(account3).balanceOfClaimToken(account3Addr);

        expect(ethBalanceAfter.eq(ethBalanceBefore.sub(caluclateFee(3)))).to.be.true;
        expect(tokenBalanceAfter.eq(tokenBalanceBefore.sub(5))).to.be.true;
        // since claim token already exists, don't mint another
        expect(claimTokenBalanceBefore2).to.equal(1)
        expect(claimTokenBalanceAfter2).to.equal(1)
        expect(claimTokenBalanceBefore3).to.equal(0)
        expect(claimTokenBalanceAfter3).to.equal(1)

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(5)
        expect(erc721Balance).to.equal(0)

        balances = await escrow.connect(account3).escrowBalance(account3Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(1)
        expect(erc721Balance).to.equal(0)
    });
    it("Should be successful when passing valid erc721 argument and fee", async() => {
        const ethBalanceBefore = await account1.getBalance();
        const tokenBalanceBefore = await tokenERC721.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceBefore = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        
        await escrow.connect(account1).deposit([buildPayloadERC721(account2Addr, 1, 0)], { value: caluclateFee(1), gasPrice: 0 });
        
        const ethBalanceAfter = await account1.getBalance();
        const tokenBalanceAfter = await tokenERC721.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceAfter = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
       
        expect(ethBalanceAfter.eq(ethBalanceBefore.sub(caluclateFee(1)))).to.be.true;
        expect(tokenBalanceAfter.eq(tokenBalanceBefore.sub(1))).to.be.true;
        expect(claimTokenBalanceBefore).to.equal(1)
        expect(claimTokenBalanceAfter).to.equal(1)

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(5)
        expect(erc721Balance).to.equal(1)
    });
    it("Should be successful when both erc721 and erc20 arguments as well as fee", async() => {
        const ethBalanceBefore = await account1.getBalance();
        const token20BalanceBefore = await tokenERC20.connect(account1).balanceOf(account1Addr);
        const token721BalanceBefore = await tokenERC721.connect(account1).balanceOf(account1Addr);
        
        await escrow.connect(account1).deposit([
            buildPayloadERC721(account3Addr, 2, 0),
            buildPayloadERC20(account2Addr, 1, 0)
        ], { value: caluclateFee(2), gasPrice: 0 });
        
        const ethBalanceAfter = await account1.getBalance();
        const token20BalanceAfter = await tokenERC20.connect(account1).balanceOf(account1Addr);
        const token721BalanceAfter = await tokenERC721.connect(account1).balanceOf(account1Addr);
        const claimTokenBalanceAfter2 = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const claimTokenBalanceAfter3 = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
       
        expect(ethBalanceAfter.eq(ethBalanceBefore.sub(caluclateFee(2)))).to.be.true;
        expect(token20BalanceAfter.eq(token20BalanceBefore.sub(1))).to.be.true;
        expect(token721BalanceAfter.eq(token721BalanceBefore.sub(1))).to.be.true;
        expect(claimTokenBalanceAfter2).to.equal(1)
        expect(claimTokenBalanceAfter3).to.equal(1)

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(6)
        expect(erc721Balance).to.equal(1)

        balances = await escrow.connect(account3).escrowBalance(account3Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(1)
        expect(erc721Balance).to.equal(1)
    });
    it("Should throw an error when adding more assets to escrow than the limit", async() => {
        details = await escrow.connect(account2).getClaimDetails(account2Addr)
        unclaimed = details[0].toNumber()

        payload =[]
        for (i = 0; i< 10 - unclaimed; i++){
                payload.push(buildPayloadERC20(account2Addr, 1, 0));
        }

        await escrow.connect(account1).deposit(payload, { value: caluclateFee(10 - unclaimed), gasPrice: 0 });
        
        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(11)
        expect(erc721Balance).to.equal(1)

        await expect(escrow.connect(account1).deposit([
            buildPayloadERC20(account2Addr, 1, 0)
        ], { value: caluclateFee(1), gasPrice: 0 })).to.be.revertedWith(revertMessage('too many unclaimed assets for recipient'));
    });
});

describe("Escrow Withdrawal", async() => {
    before('', async() => {
        await initTestVariables();
        await createContract();
        await mintSampleERC20Tokens(account1, 25)
        await mintSampleERC721Tokens(account1, 10)
    });
    it("Should throw an error if there is nothing to withdraw", async() => {
        await expect(escrow.connect(account2).withdraw()).to.be.revertedWith(revertMessage('nothing to withdraw'));
    });
    it("Should allow withdrawal if end-time is not specified (i.e 0)", async() => {
        const token20BalanceBefore = await tokenERC20.connect(account2).balanceOf(account2Addr);
        const token721BalanceBefore = await tokenERC721.connect(account2).balanceOf(account2Addr);

        await escrow.connect(account1).deposit([
            buildPayloadERC721(account2Addr, 1, 0),
            buildPayloadERC20(account2Addr, 1, 0)
        ], { value: caluclateFee(2), gasPrice: 0 });

       await escrow.connect(account2).withdraw();

        const claimTokenBalanceAfter = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const token20BalanceAfter = await tokenERC20.connect(account2).balanceOf(account2Addr);
        const token721BalanceAfter = await tokenERC721.connect(account2).balanceOf(account2Addr);
        
        expect(token20BalanceAfter.eq(token20BalanceBefore.add(1))).to.be.true;
        expect(token721BalanceAfter.eq(token721BalanceBefore.add(1))).to.be.true;
        expect(claimTokenBalanceAfter).to.equal(0);

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(0)
        expect(erc721Balance).to.equal(0)
    });
    it("Should throw an error to prevent multiple withdrawal", async() => {
        await expect(escrow.connect(account2).withdraw()).to.be.revertedWith(revertMessage('nothing to withdraw'));
    });
    it("Should throw an error for premature withdrawal", async() => {
        const time = Math.round(timestamp.now('+60s'))
        await escrow.connect(account1).deposit([
            buildPayloadERC20(account2Addr, 1, time)
        ], { value: caluclateFee(1), gasPrice: 0 });

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(1)
        expect(erc721Balance).to.equal(0)

        await expect(escrow.connect(account2).withdraw()).to.be.revertedWith(revertMessage('nothing to withdraw'));
    });
    it("Should allow withdrawal if user waits for specified time", async() => {
        const token20BalanceBefore = await tokenERC20.connect(account2).balanceOf(account2Addr);

        await ethers.provider.send('evm_setNextBlockTimestamp', [Math.round(timestamp.now('+120s'))]); 
        await escrow.connect(account2).withdraw()

        const claimTokenBalanceAfter = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const token20BalanceAfter = await tokenERC20.connect(account2).balanceOf(account2Addr);

        expect(token20BalanceAfter.eq(token20BalanceBefore.add(1))).to.be.true;
        expect(claimTokenBalanceAfter).to.equal(0);

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(0)
        expect(erc721Balance).to.equal(0)
    });
    it("Should allow burn claim token once all assets have been withdrawn", async() => {
        const token20BalanceBefore = await tokenERC20.connect(account2).balanceOf(account2Addr);
        const token721BalanceBefore = await tokenERC721.connect(account2).balanceOf(account2Addr);
        const claimTokenBalanceBefore = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        expect(claimTokenBalanceBefore).to.equal(0);
       
        const time = Math.round(timestamp.now('+180s'))
        await escrow.connect(account1).deposit([
            buildPayloadERC20(account2Addr, 1, 0),
            buildPayloadERC721(account2Addr, 2, time)
        ], { value: caluclateFee(2), gasPrice: 0 });
        
        await escrow.connect(account2).withdraw();
        
        const claimTokenBalanceAfter = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const token20BalanceAfter = await tokenERC20.connect(account2).balanceOf(account2Addr);

        expect(token20BalanceAfter.eq(token20BalanceBefore.add(1))).to.be.true;
        expect(claimTokenBalanceAfter).to.equal(1);

        balances = await escrow.connect(account2).escrowBalance(account2Addr)
        erc20Balance = balances[0]
        erc721Balance = balances[1]
        expect(erc20Balance).to.equal(0)
        expect(erc721Balance).to.equal(1)

        await ethers.provider.send('evm_setNextBlockTimestamp', [Math.round(timestamp.now('+200s'))]);
        await escrow.connect(account2).withdraw();

        const claimTokenBalanceFinal = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        const token721BalanceAfter = await tokenERC721.connect(account2).balanceOf(account2Addr);

        expect(token721BalanceAfter.eq(token721BalanceBefore.add(1))).to.be.true;
        expect(claimTokenBalanceFinal).to.equal(0);
    });
    it("Should prevent withdrawal in case of missing claim token", async() => {
        const claimTokenBalanceBefore = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        expect(claimTokenBalanceBefore).to.equal(0)

        await escrow.connect(account1).deposit([
            buildPayloadERC20(account2Addr, 1, 0)
        ], { value: caluclateFee(1), gasPrice: 0 });

        const claimTokenBalanceAfter = await escrow.connect(account2).balanceOfClaimToken(account2Addr);
        expect(claimTokenBalanceAfter).to.equal(1)

        details = await escrow.connect(account2).getClaimDetails(account2Addr);
        tokenID = details[1]
        await escrow.connect(account2).transferFrom(account2Addr, account3Addr, tokenID.toNumber());

        await expect(escrow.connect(account2).withdraw()).to.be.revertedWith(revertMessage('no claim token'));
    });
});