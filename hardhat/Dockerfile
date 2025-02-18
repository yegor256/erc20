# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

FROM node:22

ENV HOME=/hh
WORKDIR /app
EXPOSE 8545

COPY package.json .
RUN npm install

# These two must be provided via '--build-arg':
ARG PORT=8080
ARG HOST=localhost
COPY hardhat.config.js .
RUN sed -i "s/PORT/$PORT/g" hardhat.config.js
RUN sed -i "s/HOST/$HOST/g" hardhat.config.js

COPY contracts contracts
COPY ignition ignition

RUN rm -rf ignition/deployments

RUN npx hardhat compile

RUN rm -rf cache
