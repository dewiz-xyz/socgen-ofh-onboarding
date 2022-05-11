# Borrowing DAI with `RWA008`

⚠️ Replace the `SYMBOL` variable below accordingly.

## Using Authorized Wallets

1. Read from the proper environment variables:

   ```bash
   SYMBOL="RWA008"
   ```

   ```bash var_expand() {
       if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
           printf 'var_expand: expected one non-empty argument\n' >&2;
       return 1;
           fi
       eval printf '%s' "\"\${$1?}\""
   }

   ILK="${SYMBOL}_A"
   OPERATOR=$(var_expand "${ILK}_OPERATOR")
   MATE=$(var_expand "${ILK}_MATE")
   TOKEN=$(var_expand "${SYMBOL}")
   INPUT_CONDUIT=$(var_expand "${ILK}_INPUT_CONDUIT")
   OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   URN=$(var_expand "${ILK}_URN")
   ```

2. Approve the urn to pull the wrapped token from the operator's balance

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '.01' ETH)
   seth send "$TOKEN" "approve(address,uint)" "$URN" $TOKEN_AMOUNT
   ```

3. Lock the tokens into the urn

   ```bash
   seth send "$URN" "lock(uint)" $TOKEN_AMOUNT
   ```

4. Draw DAI

   ```bash
   DAI_AMOUNT=$(seth --to-wei 1000 ETH)
   seth send "$URN" "draw(uint)" $DAI_AMOUNT
   ```

5. Pick the DAI recipient

   ```bash
   seth send "$OUTPUT_CONDUIT" "pick(address)" "$OPERATOR"
   ```

6. Push DAI to the recipient

   ⚠️ Requires permission to call `push`.

   ```bash
   seth send "$OUTPUT_CONDUIT" "push()"
   ```

7. Check the balance of the operator:

   ```bash
   OPERATOR_BALANCE=$(seth call $MCD_DAI "balanceOf(address)(uint)" $OPERATOR | seth --from-wei)
   echo "Operator Balance: ${OPERATOR_BALANCE} DAI"
   ```

## Using `ForwardProxy` (dev environment only)

1. Read from the proper environment variables:

   ```bash
   SYMBOL="RWA008"
   ```

   ```bash var_expand() {
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
   INPUT_CONDUIT=$(var_expand "${ILK}_INPUT_CONDUIT")
   OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   URN=$(var_expand "${ILK}URN")
   ```

2. Approve the urn to pull the wrapped token from the operator's balance

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '.01' ETH)
   seth send "$OPERATOR" "_(address)" "$TOKEN"
   seth send "$OPERATOR" "approve(address,uint)" "$URN" $TOKEN_AMOUNT
   ```

3. Lock the tokens into the urn

   ```bash
   seth send "$OPERATOR" "_(address)" "$URN"
   seth send "$OPERATOR" "lock(uint)" $TOKEN_AMOUNT
   ```

4. Draw DAI

   ```bash
   DAI_AMOUNT=$(seth --to-wei 1000 ETH)
   seth send "$OPERATOR" "draw(uint)" $DAI_AMOUNT
   ```

5. Pick the DAI recipient

   ```bash
   seth send "$OPERATOR" "_(address)" "$OUTPUT_CONDUIT"
   seth send "$OPERATOR" "pick(address)" "$OPERATOR"
   ```

6. Push DAI to the recipient

   ```bash
   seth send "$MATE" "_(address)" "$OUTPUT_CONDUIT"
   seth send "$MATE" "push()"
   ```

7. Check the balance of the operator:

   ```bash
   OPERATOR_BALANCE=$(seth call $MCD_DAI "balanceOf(address)(uint)" $OPERATOR | seth --from-wei)
   echo "Operator Balance: ${OPERATOR_BALANCE} DAI"
   ```
