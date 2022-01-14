all        :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp --use solc:0.6.12 build
clean      :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp clean
test-local :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp --use solc:0.6.12 test --rpc-url "https://goerli.infura.io/v3/93c6c8b89c6f487dad0a4d519e631df3"
test       :; DAPP_REMAPPINGS=`cat ./remappings.txt` ./test.sh ${match}
update     :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp --use solc:0.6.12 update
deploy     :; dapp create TokenWrapper
