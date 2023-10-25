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

  });

  beforeEach(async () => {
  });

  describe("Tokens", function () {
    it("weth", async () => {
      expect(await weth.balanceOf(admin.address)).to.equal(0);
      let amount = ethers.utils.parseEther("1");
      await getWeth(admin.address, amount);
      expect(await weth.balanceOf(admin.address)).to.equal(amount);
    });
    it("usdt", async () => {
      expect(await usdt.balanceOf(admin.address)).to.equal(0);
      let amount = ethers.utils.parseUnits("1", 6);
      await getUsdt(admin.address, amount);
      expect(await usdt.balanceOf(admin.address)).to.equal(amount);
    });
    it("usdc", async () => {
      expect(await usdc.balanceOf(admin.address)).to.equal(0);
      let amount = ethers.utils.parseUnits("1", 6);
      await getUsdc(admin.address, amount);
      expect(await usdc.balanceOf(admin.address)).to.equal(amount);
    });
    it("dai", async () => {
      expect(await dai.balanceOf(admin.address)).to.equal(0);
      let amount = ethers.utils.parseEther("1");
      await getDai(admin.address, amount);
      expect(await dai.balanceOf(admin.address)).to.equal(amount);
    });
  });
});