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

   ```bash
   REPAYMENT_DATE=$(date -d "+7 days" +%s) # i.e.: 7 days from now as UNIX timestamp
   DAI_AMOUNT=$(seth call "$RWA_URN_PROXY_VIEW" "estimateWipeAllWad(address, uint)" \
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

5. Wipe the debt from the urn

   **⚠️ IMPORTANT:** This step **MUST** take place **AFTER** `REPAYMENT_DATE`.

   ```bash
   seth send "$URN" "wipe(uint)" $DAI_AMOUNT
   ```

6. Free the gem from the urn

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '0.999999' ETH) # cannot be 1 because of rounding issues
   seth send "$URN" "free(uint)" $TOKEN_AMOUNT
   ```

7. Burn the gem

   ```bash
   NULL_ADDRESS=0x0000000000000000000000000000000000000000
   seth send "$TOKEN" "transfer(address, uint)" $NULL_ADDRESS $TOKEN_AMOUNT
   ```

8. Claim any DAI remaining in the urn

   ```bash
   REMAINING_DAI=$(seth call "$MCD_DAI" "balanceof(address)" "$URN" | seth --from-wei)
   echo "Remaining DAI Balance: ${REMAINING_DAI} DAI"

   # If the amount is relevant, then run:
   seth send "$URN" "quit()"
   ```

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

   ```bash
   REPAYMENT_DATE=$(date -d "+7 days" +%s) # i.e.: 7 days from now as UNIX timestamp
   DAI_AMOUNT=$(seth call "$RWA_URN_PROXY_VIEW" "estimateWipeAllWad(address, uint)" \
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

5. Wipe the debt from the urn

   **⚠️ IMPORTANT:** This step **MUST** take place **AFTER** `REPAYMENT_DATE`.

   ```bash
   seth send "$OPERATOR" "_(address)" "$URN"
   seth send "$OPERATOR" "wipe(uint)" $DAI_AMOUNT
   ```

6. Free the gem from the urn

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '0.999999' ETH) # cannot be 1 because of rounding issues
   seth send "$OPERATOR" "free(uint)" $TOKEN_AMOUNT
   ```

7. Burn the gem

   ```bash
   NULL_ADDRESS=0x0000000000000000000000000000000000000000
   seth send "$OPERATOR" "_(address)" "$TOKEN"
   seth send "$OPERATOR" "transfer(address, uint)" $NULL_ADDRESS $TOKEN_AMOUNT
   ```

8. Claim any DAI remaining in the urn

   ```bash
   REMAINING_DAI=$(seth call "$MCD_DAI" "balanceof(address)" "$URN" | seth --from-wei)
   echo "Remaining DAI Balance: ${REMAINING_DAI} DAI"

   # If the amount is relevant, then run:
   seth send "$OPERATOR" "_(address)" "$URN"
   seth send "$OPERATOR" "quit()"
   ```
