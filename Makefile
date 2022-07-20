# include .env file and export its env vars
# (-include to ignore error if it does not exist)-include .env
-include .env

update:; dapp update
nodejs-deps:; yarn install
lint:; yarn run lint

# install solc version
# example to install other versions: `make solc 0_6_12`
# install solc version
# example to install other versions: `make solc 0_6_12`
SOLC_VERSION := 0_6_12
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_${SOLC_VERSION}

build:; forge build

estimate:; ./scripts/estimate-gas.sh ${file} ${contract} ${args}

size:; ./scripts/contract-size.sh ${file} ${contract} ${args}

# mainnet
deploy-mainnet: check-api-key; @ETH_RPC_URL=$(call alchemy-url,mainnet) ./scripts/deploy-mainnet.sh
# goerli
deploy-goerli: check-api-key; @ETH_RPC_URL=$(call alchemy-url,goerli) ./scripts/deploy-goerli.sh
# goerli CES fork
deploy-ces-goerli: check-api-key; @ETH_RPC_URL=$(call alchemy-url,goerli) ./scripts/deploy-ces-goerli.sh

# verify on Etherscan
verify-mainnet: check-api-key; @ETH_RPC_URL=$(call alchemy-url,mainnet) ./scripts/verify-contracts.sh mainnet
verify-goerli: check-api-key; @ETH_RPC_URL=$(call alchemy-url,goerli) ./scripts/verify-contracts.sh goerli
verify-ces-goerli: check-api-key; @ETH_RPC_URL=$(call alchemy-url,goerli) ./scripts/verify-contracts.sh ces-goerli

check-api-key:
ifndef ALCHEMY_API_KEY
	$(error ALCHEMY_API_KEY is undefined)
endif

# Returns the URL to deploy to a hosted node.
# Requires the ALCHEMY_API_KEY env var to be set.
# The first argument determines the network (mainnet / rinkeby / ropsten / kovan / goerli)
define alchemy-url
https://eth-$1.alchemyapi.io/v2/${ALCHEMY_API_KEY}
endef
