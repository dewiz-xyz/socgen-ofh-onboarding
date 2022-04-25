# Repaying DAI to get `RWA008`

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

1. Transfer Dai to the input conduit
   ```bash
   DAI_AMOUNT=$(seth --to-wei '1000 ether')
   seth send "$_OPERATOR" "_(address)" "$MCD_DAI"
   seth send "$_OPERATOR" "transfer(address,uint)" "$_INPUT_CONDUIT" $DAI_AMOUNT
   ```
2. Push Dai into the urn
   ```bash
   seth send "$_MATE" "_(address)" "$_INPUT_CONDUIT"
   seth send "$_MATE" "push()"
   ```
3. Wipe the debt from the urn
   ```bash
   seth send "$_OPERATOR" "_(address)" "$_URN"
   seth send "$_OPERATOR" "wipe(uint)" $DAI_AMOUNT
   ```
4. Free the gem from the urn
   ```bash
   TOKEN_AMOUNT=$(seth --to-wei ".01 ether")
   seth send "$_OPERATOR" "free(uint)" $TOKEN_AMOUNT
   ```
