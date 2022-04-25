# Repaying DAI to get `RWA008AT3`

1. Transfer Dai to the input conduit
   ```bash
   DAI_AMOUNT=$(seth --to-wei '1000 ether')
   seth send "$RWA008AT3_A_OPERATOR" "_(address)" "$MCD_DAI"
   seth send "$RWA008AT3_A_OPERATOR" "transfer(address,uint)" "$RWA008AT3_A_INPUT_CONDUIT" $DAI_AMOUNT
   ```
2. Push Dai into the urn
   ```bash
   seth send "$RWA008AT3_A_MATE" "_(address)" "$RWA008AT3_A_INPUT_CONDUIT"
   seth send "$RWA008AT3_A_MATE" "push()"
   ```
3. Wipe the debt from the urn
   ```bash
   seth send "$RWA008AT3_A_OPERATOR" "_(address)" "$RWA008AT3_A_URN"
   seth send "$RWA008AT3_A_OPERATOR" "wipe(uint)" $DAI_AMOUNT
   ```
4. Free the gem from the urn
   ```bash
   RWA008AT3_AMOUNT=$(seth --to-wei ".01 ether")
   seth send "$RWA008AT3_A_OPERATOR" "free(uint)" $RWA008AT3_AMOUNT
   ```
