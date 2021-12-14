all    :; DAPP_REMAPPINGS=$(cat ./remappings.txt) dapp --use solc:0.6.12 build
clean  :; dapp clean
test   :; DAPP_REMAPPINGS=$(cat ./remappings.txt) ./test.sh ${match}
deploy :; dapp create TokenWrapper
