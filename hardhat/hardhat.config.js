// Copyright (c) 2025 Yegor Bugayenko
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

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
