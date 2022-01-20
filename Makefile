# include .env file and export its env vars
# (-include to ignore error if it does not exist)-include .env
-include .env

update:; dapp update
npm:; yarn install

# install solc version
# example to install other versions: `make solc 0_6_12`
SOLC_VERSION := 0_6_12
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_${SOLC_VERSION}


# Build & test
build:; dapp build
test-remote:; dapp test --rpc-url $(call network,goerli) # --ffi # enable if you need the `ffi` cheat code on HEVM
test-local:; dapp test --rpc  # --ffi # enable if you need the `ffi` cheat code on HEVM
clean:; dapp clean
lint:; yarn run lint
estimate:; ./scripts/estimate-gas.sh ${file} ${contract} ${args}
size:; ./scripts/contract-size.sh ${file} ${contract} ${args}

# mainnet
deploy-mainnet: export ETH_RPC_URL = $(call network,mainnet)
deploy-mainnet: check-api-key; @./scripts/deploy-mainnet.sh mainnet

# goerli
deploy-goerli: export ETH_RPC_URL = $(call network,goerli)
deploy-goerli: check-api-key; @./scripts/deploy-goerli.sh goerli

# goerli CES fork
deploy-ces-goerli: export ETH_RPC_URL = $(call network,goerli)
deploy-ces-goerli: check-api-key; @./scripts/deploy-ces-goerli.sh goerli

# verify on Etherscan
verify:; ETH_RPC_URL=$(call network,$(network_name)) dapp verify-contract $(contract) $(contract_address)

check-api-key:
ifndef ALCHEMY_API_KEY
	$(error ALCHEMY_API_KEY is undefined)
endif

# Returns the URL to deploy to a hosted node.
# Requires the ALCHEMY_API_KEY env var to be set.
# The first argument determines the network (mainnet / rinkeby / ropsten / kovan / goerli)
define network
https://eth-$1.alchemyapi.io/v2/${ALCHEMY_API_KEY}
endef
