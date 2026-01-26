# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

Feature: Command Line Processing
  As a simple ETH/ERC20 user I want to use it

  Scenario: Help can be printed
    When I run bin/erc20 with "help"
    Then Exit code is zero
    And Stdout contains "help"

  Scenario: ETH private key can be generated
    When I run bin/erc20 with "key"
    Then Exit code is zero

  Scenario: ETH address can be created
    When I run bin/erc20 with "address 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1"
    Then Exit code is zero
