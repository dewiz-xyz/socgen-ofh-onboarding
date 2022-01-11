all        :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp --use solc:0.6.12 build
clean      :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp clean
test-local :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp --use solc:0.6.12 test
test       :; DAPP_REMAPPINGS=`cat ./remappings.txt` ./test.sh ${match}
update     :; DAPP_REMAPPINGS=`cat ./remappings.txt` dapp --use solc:0.6.12 update
deploy     :; dapp create TokenWrapper
