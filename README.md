# socgen-ofh-onboarding
Repository for onboarding SocGen's [OFH](https://forum.makerdao.com/t/security-tokens-refinancing-mip6-application-for-ofh-tokens/10605/8) to MCD. Forked and adapted from [MIP21-RWA-Example](https://github.com/makerdao/MIP21-RWA-Example) template repo.

## Dev

- Clone the repo

- (Optional) You can run ```nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_6_12``` for a lasting installation of the solidity version used.

- Install lib dependencies
```bash
dapp update
```
- Create local .env file & edit placeholder values
```bash
cp .env.exaples .env
```
- Build contracts
```bash
dapp build
```
- Test contracts
```bash
dapp test
```
- Deploy contracts
```bash
bash scripts/deploy-goerli.sh
```

You can also reffer to the Makefile (```make <command>```) for full list of commands.


## License
AGPL-3.0 LICENSE