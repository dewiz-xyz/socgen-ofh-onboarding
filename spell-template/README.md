# SocGen OFH Onboarding - Spell Template

The contracts in this directory are meant to be used as a template for a spell to onboard SocGen OFH deal as a MIP21.

It is based on the RWA Onboarding Template from [`ces-spells-goerli`](https://github.com/clio-finance/ces-spells-goerli/tree/297e296a3490db7f3c87451626345c97bf49632e/template/rwa-onboarding) with some modifications:

1. Whitelist additional addresses as `operator` and `mate` for SocGen and DIIS Group wallets.
2. Add SocGen own wallet as a fallback `mate` in case DIIS Group cannot submit the required transactions in a timely manner.

## How to use this?

⚠️ **WARNING**: **DO NOT** copy all files in this directory into the spells repo because they will probably be outdated.

The only file safe for copy is [`Goerli-DssSpellCollateralOnboarding.sol`](./Goerli-DssSpellCollateralOnboarding.sol), all other files should be carefully extracted into the actual spell. Use them as guides.
