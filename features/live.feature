# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

Feature: Command Line Processing
  As a simple ETH/ERC20 user I want to use it live

  Scenario: Gas price price can be retrieved
    When I run bin/erc20 with "price --attempts=4"
    Then Exit code is zero

  Scenario: ERC20 balance can be checked
    When I run bin/erc20 with "balance 0x7232148927F8a580053792f44D4d59d40Fd00ABD --verbose --attempts=4"
    Then Exit code is zero

  Scenario: ETH balance can be checked
    When I run bin/erc20 with "eth_balance 0x7232148927F8a580053792f44D4d59d40Fd00ABD --verbose --attempts=4"
    Then Exit code is zero
