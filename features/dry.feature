# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

Feature: Command Line Processing, in Dry Mode
  As a simple ETH/ERC20 user I want to test it in dry mode

  Scenario: Gas price price can be retrieved
    When I run bin/erc20 with "price --attempts=4 --dry"
    Then Exit code is zero

  Scenario: ERC20 balance can be checked
    When I run bin/erc20 with "balance 0x7232148927F8a580053792f44D4d59d40Fd00ABD --verbose --dry"
    Then Exit code is zero

  Scenario: ETH balance can be checked
    When I run bin/erc20 with "eth_balance 0x7232148927F8a580053792f44D4d59d40Fd00ABD --verbose --dry"
    Then Exit code is zero

  Scenario: ERC20 payment can be sent in tokens
    When I run bin/erc20 with "pay --dry --verbose 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 0x7232148927F8a580053792f44D4d59d40Fd00ABD 10"
    Then Exit code is zero

  Scenario: ERC20 payment can be sent in dollars
    When I run bin/erc20 with "pay --dry --verbose 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 0x7232148927F8a580053792f44D4d59d40Fd00ABD $10"
    Then Exit code is zero

  Scenario: ERC20 payment can be sent in USDT
    When I run bin/erc20 with "pay --dry --verbose 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 0x7232148927F8a580053792f44D4d59d40Fd00ABD 10usdt"
    Then Exit code is zero

  Scenario: ETH payment can be sent in wei
    When I run bin/erc20 with "eth_pay --dry --verbose 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 0x7232148927F8a580053792f44D4d59d40Fd00ABD 10000000"
    Then Exit code is zero

  Scenario: ETH payment can be sent in ETH
    When I run bin/erc20 with "eth_pay --dry --verbose 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 0x7232148927F8a580053792f44D4d59d40Fd00ABD 1eth"
    Then Exit code is zero
