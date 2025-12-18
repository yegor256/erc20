# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

Feature: Command Line Processing
  As a simple ETH/ERC20 user I want to send payments

  Scenario: Help can be printed
    When I run bin/erc20 with "--help"
    Then Exit code is zero
    And Stdout contains "--help"

  Scenario: Gas price price can be retrieved
    When I run bin/erc20 with "price --attempts=4"
    Then Exit code is zero

  Scenario: ETH private key can be generated
    When I run bin/erc20 with "key"
    Then Exit code is zero

  Scenario: ETH address can be created
    When I run bin/erc20 with "address 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1"
    Then Exit code is zero

  Scenario: ERC20 balance can be checked
    When I run bin/erc20 with "balance 0x7232148927F8a580053792f44D4d59d40Fd00ABD --verbose"
    Then Exit code is zero

  Scenario: ETH balance can be checked
    When I run bin/erc20 with "eth_balance 0x7232148927F8a580053792f44D4d59d40Fd00ABD --verbose"
    Then Exit code is zero

  Scenario: ERC20 payment can be sent
    When I run bin/erc20 with "pay --dry --verbose 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 0x7232148927F8a580053792f44D4d59d40Fd00ABD $10"
    Then Exit code is zero

