# Repaying DAI to get `RWA008`

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

2. Transfer DAI to the input conduit

   ```bash
   DAI_AMOUNT=$(seth --to-wei 1000 ETH)
   seth send "$MCD_DAI" "transfer(address,uint)" "$INPUT_COUNDUIT" $DAI_AMOUNT
   ```

3. Push DAI into the urn

   ⚠️ Requires permission to call `push`.

   ```bash
   seth send "$INPUT_COUNDUIT" "push()"
   ```

4. Wipe the debt from the urn

   ```bash
   seth send "$URN" "wipe(uint)" $DAI_AMOUNT
   ```

5. Free the gem from the urn [optional]

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '.01' ETH)
   seth send "$URN" "free(uint)" $TOKEN_AMOUNT
   ```

## Using `ForwardProxy` (dev environment only)

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

2. Transfer DAI to the input conduit

   ```bash
   DAI_AMOUNT=$(seth --to-wei 1000 ETH)
   seth send "$OPERATOR" "_(address)" "$MCD_DAI"
   seth send "$OPERATOR" "transfer(address,uint)" "$INPUT_COUNDUIT" $DAI_AMOUNT
   ```

3. Push DAI into the urn

   ```bash
   seth send "$MATE" "_(address)" "$INPUT_COUNDUIT"
   seth send "$MATE" "push()"
   ```

4. Wipe the debt from the urn

   ```bash
   seth send "$OPERATOR" "_(address)" "$URN"
   seth send "$OPERATOR" "wipe(uint)" $DAI_AMOUNT
   ```

5. Free the gem from the urn [optional]

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '.01' ETH)
   seth send "$OPERATOR" "free(uint)" $TOKEN_AMOUNT
   ```
