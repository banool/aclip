# Move Module

## Setting up the aptos CLI
```
cd ~
aptos config init
```

If you already have a config but you need to recreate the account, e.g. for a new release, do this (this is for long-lived testnet):
```
aptos config init --private-key `yq .profiles.default.private_key < .aptos/config.yaml` --assume-yes --rest-url https://testnet.aptoslabs.com/v1 --faucet-url https://faucet.testnet.aptoslabs.com
```

## Setting up the module
Make sure the addresses in Move.toml matches the `account` field in ~/.aptos/config.yml`.

First, publish maptable. Check the README there.

Publish the module:
```
cd ~
aptos move publish --package-dir github/aclip/move
```

## Uprading the version of aptos-framework
You'll see that in Move.toml, the version of aptos-framework is pinned to a particular revision of the repo. This is important, because over time we land changes to the framework that aren't immediately reflected in the devnet. While those changes (ideally) would work on a test net running from that same revision, a newer version of the framework might not work on the current test net. Each time a new devnet is released, we can (and might have to) pin to a later revision.

## Troubleshooting
- When testing / publishing, you might find some unexpected weird compilation errors. It's possible that we haven't invalidated the move package cache properly. In that case, run `rm ~/.move`
- The build dependencies aren't the only thing that matter, you need to make sure you're using the correct version of the CLI as well. You may even need to test with one version but publish with another.

To add an item to a list directly, try something like this:
```
aptos move run --function-id "$(yq .profiles.default.account < ~/.aptos/config.yml)::$(cat github/aclip/move/sources/aclip.move | grep -o -E 'RootV\d+' | head -n 1)::add_simple" --args string:google.com
```
