const { ethers } = require("hardhat");

function revertMessage(error) {
    // for hardhat version<2.4.0 return 'VM Exception while processing transaction: revert ' + error;
    return error;
}

function getBalanceAsNumber(bn, decimals, accuracy) {
    const r1 = ethers.BigNumber.from(10).pow(decimals - accuracy);
    const r2 = bn.div(r1);
    const r3 = r2.toNumber();
    const r4 = r3 / (10 ** accuracy);
    return r4;
}

async function deployContracts() {
    let tokenERC20, tokenERC721, escrow;
   
    const c1 = await hre.ethers.getContractFactory("TokenERC20");
    tokenERC20 = await c1.deploy();
    await tokenERC20.deployed();
    
    const c2 = await hre.ethers.getContractFactory("TokenERC721");
    tokenERC721 = await c2.deploy();
    await tokenERC721.deployed();

    const c3 = await hre.ethers.getContractFactory("Escrow");
    escrow = await c3.deploy(tokenERC20.address, tokenERC721.address);
    await escrow.deployed();

    return { tokenERC20, tokenERC721, escrow };
}


module.exports = {
    revertMessage,
    getBalanceAsNumber,
    deployContracts,
}
