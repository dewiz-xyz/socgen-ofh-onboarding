# Closing the vault

⚠️ Replace the `SYMBOL` variable below accordingly.

## Using Authorized Wallets

1. Read from the proper environment variables:

   ```bash
   SYMBOL="RWA008"
   ```

   ```bash
   var_expand() {
       if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
           printf 'var_expand: expected one non-empty argument\n' >&2;
       return 1;
           fi
       eval printf '%s' "\"\${$1?}\""
   }

   ILK="${SYMBOL}_A"
   TOKEN=$(var_expand "${SYMBOL}")
   OPERATOR=$(var_expand "${ILK}_OPERATOR")
   MATE=$(var_expand "${ILK}_MATE")
   INPUT_COUNDUIT=$(var_expand "${ILK}_INPUT_CONDUIT")
   OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   URN=$(var_expand "${ILK}_URN")
   ```

2. Estimate the amount required to make the full repayment

   **ℹ️ NOTICE:** You might want to send some extra DAI in this step in case the vault closing transaction cannot be included in the blockchain **after** `REPAYMENT_DATE`. Any outstanding DAI after `close()` is called will be automatically sent to the `OUTPUT_CONDUIT`.

   ```bash
   REPAYMENT_DATE=$(date -d "+7 days" +%s) # i.e.: 7 days from now as UNIX timestamp
   DAI_AMOUNT=$(seth call "$RWA_URN_PROXY_ACTIONS" "estimateWipeAllWad(address, uint)" \
       "$URN" $REPAYMENT_DATE)
   ```

3. Transfer DAI to the input conduit

   ```bash
   seth send "$MCD_DAI" "transfer(address, uint)" "$INPUT_COUNDUIT" $DAI_AMOUNT
   ```

4. Push DAI into the urn

   ⚠️ Requires permission to call `push`.

   ```bash
   seth send "$INPUT_COUNDUIT" "push()"
   ```

5. Close the vault with the help of `RWA_URN_PROXY_ACTIONS`

   ```bash
   seth send "$RWA_URN_PROXY_ACTIONS" "close(address)" $URN
   ```

   The step above will:

   - Wipe all the debt from the urn
   - Free all the collateral token (`RWA008`) from the urn
   - Burn the `RWA008`
   - Transfer any remaining DAI to the `OUTPUT_CONDUIT`

## Using `ForwardProxy` (dev environment only)

⚠️ Replace the `SYMBOL` variable below accordingly.

1. Read from the proper environment variables:

   ```bash
   SYMBOL="RWA008"
   ```

   ```bash
   var_expand() {
       if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
           printf 'var_expand: expected one non-empty argument\n' >&2;
       return 1;
           fi
       eval printf '%s' "\"\${$1?}\""
   }

   ILK="${SYMBOL}_A"
   TOKEN=$(var_expand "${SYMBOL}")
   OPERATOR=$(var_expand "${ILK}_OPERATOR")
   MATE=$(var_expand "${ILK}_MATE")
   INPUT_COUNDUIT=$(var_expand "${ILK}_INPUT_CONDUIT")
   OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   URN=$(var_expand "${ILK}_URN")
   ```

2. Estimate the amount required to make the full repayment

   **ℹ️ NOTICE:** You might want to send some extra DAI in this step in case the vault closing transaction cannot be included in the blockchain **after** `REPAYMENT_DATE`. Any outstanding DAI after `close()` is called will be automatically sent to the `OUTPUT_CONDUIT`.

   ```bash
   REPAYMENT_DATE=$(date -d "+7 days" +%s) # i.e.: 7 days from now as UNIX timestamp
   DAI_AMOUNT=$(seth call "$RWA_URN_PROXY_ACTIONS" "estimateWipeAllWad(address, uint)" \
       "$URN" $REPAYMENT_DATE)
   ```

3. Transfer DAI to the input conduit

   ```bash
   seth send "$OPERATOR" "_(address)" "$MCD_DAI"
   seth send "$OPERATOR" "transfer(address, uint)" "$INPUT_COUNDUIT" $DAI_AMOUNT
   ```

4. Push DAI into the urn

   ```bash
   seth send "$MATE" "_(address)" "$INPUT_COUNDUIT"
   seth send "$MATE" "push()"
   ```

5. Close the vault with the help of `RWA_URN_PROXY_ACTIONS`

   ```bash
   seth send "$OPERATOR" "_(address)" "$RWA_URN_PROXY_ACTIONS"
   seth send "$OPERATOR" "close(address)" $URN
   ```

   The step above will:

   - Wipe all the debt from the urn
   - Free all the collateral token (`RWA008`) from the urn
   - Burn the `RWA008`
   - Transfer any remaining DAI to the `OUTPUT_CONDUIT`
