# direnv-az

> Azure for direnv — load Key Vault secrets into your environment and pick the subscription per directory.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/direnv-contrib/direnv-az/actions/workflows/ci.yml/badge.svg)](https://github.com/direnv-contrib/direnv-az/actions/workflows/ci.yml)

Stop copying secrets into `.env` files. `direnv-az` adds two functions to your `.envrc`: `use_az_secret` reads Azure Key Vault secrets when you enter a directory and exports them as environment variables, and `use_az_subscription` points the Azure SDKs and Terraform at the right subscription for that directory.

## Requirements

- [direnv](https://direnv.net) (`direnv`)
- [jq](https://jqlang.org) (`jq`)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`), signed in with an account that can read the secrets

**macOS (Homebrew):**

```bash
brew install direnv jq azure-cli
```

**Nix:**

```bash
nix profile install nixpkgs#direnv nixpkgs#jq nixpkgs#azure-cli
```

## Installation

direnv loads every `*.sh` file in `~/.config/direnv/lib/` before it evaluates a `.envrc`, so installing means making the files in `lib/` available there.

### Using Nix

Add the flake as an input:

```nix
inputs.direnv-az.url = "github:direnv-contrib/direnv-az";
```

With Home Manager, import the module and enable it. It sources the scripts from direnv's standard library, so `programs.direnv.enable` must be on as well:

```nix
imports = [ inputs.direnv-az.homeManagerModules.default ];

programs.direnv-az.enable = true;
```

Without Home Manager, install the package, which places the scripts in `share/direnv-az`:

```nix
environment.systemPackages = [ inputs.direnv-az.packages.${system}.default ];
```

Then source them from the standard library with a loop in `~/.config/direnv/lib/direnv-az.sh`, pointing at the package path:

```bash
for lib in /path/to/direnv-az/share/direnv-az/*.sh; do
  source "$lib"
done
```

### Manual

```bash
git clone https://github.com/direnv-contrib/direnv-az.git ~/.local/share/direnv-az
mkdir -p ~/.config/direnv/lib
ln -s ~/.local/share/direnv-az/lib/*.sh ~/.config/direnv/lib/
```

## Usage

Call the functions from a `.envrc`:

```bash
use_az_subscription 00000000-0000-0000-0000-000000000000   # SDKs and Terraform use this subscription

use_az_secret my-vault/db-creds              # JSON secret: one variable per key
use_az_secret DB_URL=my-vault/db-url         # the raw secret string, with an explicit name
use_az_secret my-vault/api-token@0123abcd    # a specific version, the default is the latest
```

### use_az_secret

Each argument is `[NAME=]vault/secret[@version]`, where `vault` is the name of the Key Vault, not its URL.

| Argument | Result |
|----------|--------|
| `my-vault/db-creds`, a JSON object | One variable per key, uppercased. Non-string values are exported as JSON |
| `my-vault/db-url`, a plain string | One variable named after the secret, `DB_URL` |
| `NAME=my-vault/db-url` | The raw secret string, exported as `NAME` |
| `my-vault/db-url@0123abcd` | That version of the secret, an id as listed by `az keyvault secret list-versions`. Without `@`, the latest version is read |

Variable names are uppercased, and characters outside `A-Z`, `0-9` and `_` become `_`. The secret is read with `az keyvault secret show`, which talks to the vault directly, so no subscription is needed.

### use_az_subscription

Sets `AZURE_SUBSCRIPTION_ID`, which the Azure SDKs and `azd` read, and `ARM_SUBSCRIPTION_ID`, which Terraform and Pulumi read. The `az` CLI has no environment variable for the subscription, so it keeps using the default of your `az login`.

## Credentials

The helpers use whatever account `az` is signed in with. Run `az login` once, or set up a service principal or managed identity the way you already do for `az`.

## Behavior

- A failed read, a secret without a string value, or a name that is not a valid variable name stops the call and returns status 1 with an error message. Variables exported by earlier arguments in the same call stay set.
- Values are exported into the environment of that directory. Anything that runs there can read them, and direnv's `.envrc` trust model applies, so review a `.envrc` before you run `direnv allow`.
- A `.envrc` that uses these functions contains vault names, secret names and subscription ids only, never the values, so it is safe to commit.

## Development

```bash
nix develop
bats tests/
```

The tests stub `az` with a shell function and load direnv's own standard library, so they run without Azure access.

## The direnv-contrib Ecosystem

| Repo | What it provides |
|------|-----------------|
| [direnv-aws](https://github.com/direnv-contrib/direnv-aws) | AWS Secrets Manager and SSM Parameter Store for direnv |
| **direnv-az** ← you are here | Azure Key Vault and subscription selection for direnv |
| [direnv-gcp](https://github.com/direnv-contrib/direnv-gcp) | Google Secret Manager and project selection for direnv |
| [direnv-op](https://github.com/direnv-contrib/direnv-op) | 1Password secrets and items for direnv |

## License

[MIT](LICENSE) — Copyright (c) 2026 direnv-contrib

<!-- markdownlint-disable-file MD013 -->
