require('dotenv').config();

exports.initForking = function(ntw, blockNumber) {
    switch (ntw) {
        case "bsc":
            return initBsc(blockNumber);
        case "eth":
          return initEth(blockNumber);
        default:
          throw new Error("Network not implemented");
    }
}

function initBsc(blockNumber) {
    return {
        url: process.env.BSC_URL,
        blockNumber: blockNumber,
        chainId: 56,
        start: async function () {
          await startForking(this.url, this.blockNumber, this.chainId);
        },
        getToken: async function(tokenName, address, amount) {
          await receiveToken("bsc", tokenName, address, amount);
        }
    }
}

function initEth(blockNumber) {
  return {
      url: process.env.ETH_URL,
      blockNumber: blockNumber,
      chainId: 1,
      start: async function () {
        await startForking(this.url, this.blockNumber, this.chainId);
      },
      getToken: async function(tokenName, address, amount) {
        await receiveToken("eth", tokenName, address, amount);
      }
  }
}


async function startForking(url, blockNumber, chainId) {
    await hre.network.provider.request({
        method: "hardhat_reset",
        params: [
          {
            forking: {
              jsonRpcUrl: url,
              blockNumber: blockNumber,
              chainId: chainId,
            },
          },
        ],
      });
}

async function receiveToken(networkName, tokenName, address, amount) {
  let [tokenAddress, vault] = getImpersonateParameters(networkName, tokenName);
  let signer = await ethers.getImpersonatedSigner(vault);
  await hre.network.provider.send("hardhat_setBalance", [vault, "0xFFFFFFFFFFFFFFFF"]);
  let token = await ethers.getContractAt("IERC20", tokenAddress);
  await token.connect(signer).transfer(address, amount);
}

function getImpersonateParameters(networkName, tokenName) {
  if (networkName.toLowerCase() == "bsc") {
    switch (tokenName.toLowerCase()) {
      case "wbnb":
        return(["0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", "0x36696169C63e42cd08ce11f5deeBbCeBae652050"])
      case "usdt":
        return(["0x55d398326f99059ff775485246999027b3197955", "0xf977814e90da44bfa03b6295a0616a897441acec"]);
      case "usdc":
        return(["0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", "0xf89d7b9c864f589bbF53a82105107622B35EaA40"]);
      case "dai":
        return(["0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3", "0xF977814e90dA44bFA03b6295A0616a897441aceC"]);
    }
  } else if (networkName.toLowerCase() == "eth") {
    switch (tokenName.toLowerCase()) {
      case "weth":
        return(["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", "0x2f0b23f53734252bda2277357e97e1517d6b042a"])
      case "usdt":
        return(["0xdAC17F958D2ee523a2206206994597C13D831ec7", "0x2016c2FD134701BefEbCE60FcD42F0f9CD73a760"]);
      case "usdc":
        return(["0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503"]);
      case "dai":
        return(["0x6b175474e89094c44da98b954eedeac495271d0f", "0x60faae176336dab62e284fe19b885b095d29fb7f"]);
    }
  }

  throw new Error("Not implemented for this token and this network");
}