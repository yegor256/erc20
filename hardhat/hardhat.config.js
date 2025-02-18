// SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
// SPDX-License-Identifier: MIT

require("@nomicfoundation/hardhat-toolbox");

/** @type import("hardhat/config").HardhatUserConfig */

module.exports = {
  solidity: "0.8.28",
  defaultNetwork: "foo",
  networks: {
    hardhat: {
      chainId: 4242,
      gas: 10,
      gasPrice: 4,
      maxFeePerGas: 100,
      maxPriorityFeePerGas: 100,
      initialBaseFeePerGas: 100,
      accounts: [
        {
          privateKey: "81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a",
          balance: "55555555555555555555555"
        },
        {
          privateKey: "91f9111b1744d55361e632771a4e53839e9442a9fef45febc0a5c838c686a15b",
          balance: "66666666666666666666666"
        }
      ]
    },
    foo: {
      chainId: 4242,
      url: "http://HOST:PORT"
    }
  }
};
