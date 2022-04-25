# Borrowing DAI with `RWA008AT3`

1. Approve the urn to pull the wrapped token from the operator's balance
   ```bash
   RWA008AT3_AMOUNT=$(seth --to-wei ".01 ether")
   seth send "$RWA008AT3_A_OPERATOR" "_(address)" "$RWA008AT3"
   seth send "$RWA008AT3_A_OPERATOR" "approve(address,uint)" "$RWA008AT3_A_URN" $RWA008AT3_AMOUNT
   ```
2. Lock the tokens into the urn
   ```bash
   seth send "$RWA008AT3_A_OPERATOR" "_(address)" "$RWA008AT3_A_URN"
   seth send "$RWA008AT3_A_OPERATOR" "lock(uint)" $RWA008AT3_AMOUNT
   ```
3. Draw Dai
   ```bash
   DAI_AMOUNT=$(seth --to-wei '1000 ether')
   seth send "$RWA008AT3_A_OPERATOR" "draw(uint)" $DAI_AMOUNT
   ```
4. Pick the Dai recipient
   ```bash
   seth send "$RWA008AT3_A_OPERATOR" "_(address)" "$RWA008AT3_A_OUTPUT_CONDUIT"
   seth send "$RWA008AT3_A_OPERATOR" "pick(address)" "$RWA008AT3_A_OPERATOR"
   ```
5. Push Dai to the recipient
   ```bash
   seth send "$RWA008AT3_A_MATE" "_(address)" "$RWA008AT3_A_OUTPUT_CONDUIT"
   seth send "$RWA008AT3_A_MATE" "push()"
   ```

Last check the balance of the operator:

```bash
OPERATOR_BALANCE=$(seth call $MCD_DAI "balanceOf(address)(uint)" $RWA008AT3_A_OPERATOR | seth --from-wei)
echo "Operator Balance: ${OPERATOR_BALANCE} Dai"
```
