# Pods 1155 Contracts

_This repository contains additions and modifications by Pods. The original repo can be found [here](https://github.com/ourzora/zora-protocol)._

Pods 1155 contracts allow creators to mint their podcast episodes as semi-fungible tokens on Ethereum with a set of flexible properties. These contracts are built off of Zora 1155s and have been modified to better fit the needs for publishing podcasts onchain.

The main implementation of the Pods 1155 Contracts includes the following modules:

- Metadata Control
- Royalties Control
- Minting Control
- Permissions Control
- Royalties Controls

Most controls exist on a per-contract and per-token level. Per contract level is defined as any configuration existing in the pre-reserved 0 token space.

## Official docs

[View the official docs](https://docs.zora.co/docs/smart-contracts/creator-tools/Deploy1155Contract)

## Bug Bounty

5 ETH for any critical bugs that could result in loss of funds. Rewards will be given for smaller bugs or ideas.

## Publishing a new version to npm

Generate a new changeset in your branch with:

    npx changeset

When the branch is merged to main, the versions will be automatically updated in the corresponding packages.

To publish the updated version:

    yarn publish-packages
