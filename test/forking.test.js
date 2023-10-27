const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
const { getContractFactory } = require("@nomiclabs/hardhat-ethers/types");
const {initForking} = require('./helpers/forking');

async function getWeth(address, amount) {
  await forking.getToken("weth", address, amount);
}

async function getUsdt(address, amount) {
  await forking.getToken("usdt", address, amount);
}

async function getUsdc(address, amount) {
  await forking.getToken("usdc", address, amount);
}

async function getDai(address, amount) {
  await forking.getToken("dai", address, amount);
}

async function printSwap(data) {
  let token = await ethers.getContractAt("IERC20Metadata", data.path[0]);
  console.log("Have", data.amounts[0].toString(), "of", await token.symbol());
  for (let i = 0; i < data.poolTypes.length; i ++) {
    let swapType = data.poolTypes[i];
    switch (swapType) {
      case 1: 
        console.log("Swapped with Uniswap V2");
        break;
      case 2:
        console.log("Swapped with Uniswap V3 fee 500");
        break;
      case 3:
        console.log("Swapped with Uniswap V3 fee 3000");
        break;
      case 4:
        console.log("Swapped with Uniswap V3 fee 10000");
        break;
      default:
        throw new Error("Wrong pool type");
    }
    token = await ethers.getContractAt("IERC20Metadata", data.path[i+1]);
    console.log("Have", data.amounts[i+1].toString(), "of", await token.symbol());
  }
  console.log("");
}


describe("Test ethereum forking", function () {

  before(async () => {
    forking = initForking("eth", 18000000);
    await forking.start();

    [admin] = await ethers.getSigners();

    weth = await ethers.getContractAt("IERC20Metadata", "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
    usdt = await ethers.getContractAt("IERC20Metadata", "0xdAC17F958D2ee523a2206206994597C13D831ec7");
    usdc = await ethers.getContractAt("IERC20Metadata", "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48");
    dai = await ethers.getContractAt("IERC20Metadata", "0x6b175474e89094c44da98b954eedeac495271d0f");

    PriceFeed = await ethers.getContractFactory("PriceFeed");

  });

  beforeEach(async () => {
    feed = await PriceFeed.deploy();
  });

  describe("Library", function () {
    it("usdt/dai", async () => {
      let amountUsdt = ethers.utils.parseUnits("1000", 6);
      let amountDai = ethers.utils.parseUnits("1000", 18);
      console.log(await feed.testV2(amountUsdt, usdt.address, dai.address, true));
      console.log(await feed.testV2(amountDai, usdt.address, dai.address, false));

      console.log(await feed.callStatic.testV3(amountUsdt, usdt.address, dai.address, 500, true));
      console.log(await feed.callStatic.testV3(amountDai, usdt.address, dai.address, 500, false));
    });

    it("usdt/dai find path", async () => {
      let amountUsdt = ethers.utils.parseUnits("1000", 6);
      let amountDai = ethers.utils.parseUnits("1000", 18);
      await printSwap(await feed.callStatic.testFindPathOneHop(amountUsdt, usdt.address, dai.address, true));
      await printSwap(await feed.callStatic.testFindPathOneHop(amountDai, usdt.address, dai.address, false));
    });

    it("weth/usdc", async () => {
      let amountUsdc = ethers.utils.parseUnits("1000", 6);
      let amountWeth = ethers.utils.parseUnits("1", 18);
      console.log(await feed.testV2(amountWeth, weth.address, usdc.address, true));
      console.log(await feed.testV2(amountUsdc, weth.address, usdc.address, false));

      console.log(await feed.callStatic.testV3(amountWeth, weth.address, usdc.address, 500, true));
      console.log(await feed.callStatic.testV3(amountUsdc, weth.address, usdc.address, 500, false));
    });

    it("weth/usdc find path", async () => {
      let amountUsdc = ethers.utils.parseUnits("1000", 6);
      let amountWeth = ethers.utils.parseUnits("1", 18);
      await printSwap(await feed.callStatic.testFindPathOneHop(amountWeth, weth.address, usdc.address, true));
      await printSwap(await feed.callStatic.testFindPathOneHop(amountUsdc, weth.address, usdc.address, false));
    });

    it("weth/usdc with path tokens", async () => {
      let amountUsdt = ethers.utils.parseUnits("1000", 6);
      let amountWeth = ethers.utils.parseUnits("1", 18);
      let path = [
        [
          '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
          '0x6B175474E89094C44Da98b954EedeAC495271d0F',
          '0xdAC17F958D2ee523a2206206994597C13D831ec7'
        ],
        [ 2, 2 ],
      ]
      await printSwap(await feed.callStatic.testFindPathOneHop(amountWeth, weth.address, usdt.address, true));
      await printSwap(await feed.callStatic.testFindPathOneHop(amountUsdt, weth.address, usdt.address, false));

      await printSwap(await feed.callStatic.testWithPath(amountWeth, weth.address, usdt.address, true, path));
      await printSwap(await feed.callStatic.testWithPath(amountUsdt, weth.address, usdt.address, false, path));

      await feed.addPathTokens([dai.address, usdc.address]);
      console.log("Added path tokens:", await feed.getPathTokens());

      await printSwap(await feed.callStatic.testFindPathOneHop(amountWeth, weth.address, usdt.address, true));
      await printSwap(await feed.callStatic.testFindPathOneHop(amountUsdt, weth.address, usdt.address, false));

    });

    it("amount 0", async () => {
      console.log(await feed.callStatic.testFindPathOneHop(0, weth.address, usdt.address, false));
    });

    it("tokens with no swaps", async () => {
      await feed.addPathTokens([dai.address, usdc.address]);
      console.log(await feed.getPathTokens());
      let MockToken = await ethers.getContractFactory("MockToken");
      let token0 = await MockToken.deploy();
      let token1 = await MockToken.deploy();
      console.log(await feed.callStatic.testFindPathOneHop(1, token0.address, token1.address, false));
    });

  });
});