# Borrowing DAI with `RWA008`

⚠️ Replace the `SYMBOL` variable below accordingly.

0. Read from the proper environment variables:

   ```bash
   var_expand() {
       if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
           printf 'var_expand: expected one non-empty argument\n' >&2;
       return 1;
           fi
       eval printf '%s' "\"\${$1?}\""
   }

   SYMBOL="RWA008"
   ILK="${SYMBOL}_A"
   _TOKEN=$(var_expand "${SYMBOL}")
   _OPERATOR=$(var_expand "${ILK}_OPERATOR")
   _MATE=$(var_expand "${ILK}_MATE")
   _INPUT_CONDUIT=$(var_expand "${ILK}_INPUT_CONDUIT")
   _OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   _URN=$(var_expand "${ILK}_URN")
   ```

1. Approve the urn to pull the wrapped token from the operator's balance
   ```bash
   TOKEN_AMOUNT=$(seth --to-wei ".01 ether")
   seth send "$_OPERATOR" "_(address)" "$_TOKEN"
   seth send "$_OPERATOR" "approve(address,uint)" "$_URN" $TOKEN_AMOUNT
   ```
2. Lock the tokens into the urn
   ```bash
   seth send "$_OPERATOR" "_(address)" "$_URN"
   seth send "$_OPERATOR" "lock(uint)" $TOKEN_AMOUNT
   ```
3. Draw Dai
   ```bash
   DAI_TOKEN_AMOUNT=$(seth --to-wei '1000 ether')
   seth send "$_OPERATOR" "draw(uint)" $DAI_TOKEN_AMOUNT
   ```
4. Pick the Dai recipient
   ```bash
   seth send "$_OPERATOR" "_(address)" "$_OUTPUT_CONDUIT"
   seth send "$_OPERATOR" "pick(address)" "$_OPERATOR"
   ```
5. Push Dai to the recipient
   ```bash
   seth send "$_MATE" "_(address)" "$_OUTPUT_CONDUIT"
   seth send "$_MATE" "push()"
   ```

Last check the balance of the operator:

```bash
OPERATOR_BALANCE=$(seth call $MCD_DAI "balanceOf(address)(uint)" $_OPERATOR | seth --from-wei)
echo "Operator Balance: ${OPERATOR_BALANCE} Dai"
```
