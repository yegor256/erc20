// SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
// SPDX-License-Identifier: MIT

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const FooModule = buildModule("FooModule", (m) => {
  const foo = m.contract("Foo");
  return { foo };
});

export default FooModule;
