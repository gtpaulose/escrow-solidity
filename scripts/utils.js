function revertMessage(error) {
    // for hardhat version<2.4.0 return 'VM Exception while processing transaction: revert ' + error;
    return error;
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
    deployContracts,
}
