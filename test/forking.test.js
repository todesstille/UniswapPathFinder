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


describe("Test ethereum forking", function () {

  before(async () => {
    forking = initForking("eth", 18000000);
    await forking.start();

    [admin] = await ethers.getSigners();

    weth = await ethers.getContractAt("IERC20", "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
    usdt = await ethers.getContractAt("IERC20", "0xdAC17F958D2ee523a2206206994597C13D831ec7");
    usdc = await ethers.getContractAt("IERC20", "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48");
    dai = await ethers.getContractAt("IERC20", "0x6b175474e89094c44da98b954eedeac495271d0f");

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
      console.log(await feed.callStatic.testFindPathOneHop(amountUsdt, usdt.address, dai.address, true));
      console.log(await feed.callStatic.testFindPathOneHop(amountDai, usdt.address, dai.address, false));
    });

  });
});