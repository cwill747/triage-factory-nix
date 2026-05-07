# triage-factory-nix

Nix flake for building [Triage Factory](https://github.com/sky-ai-eng/triage-factory) from source. Fetches a release tarball, builds the React frontend and Go binary, and produces a single `triagefactory` executable.

## Install directly

```bash
# Run without installing
nix run github:cwill747/triage-factory-nix

# Install to profile
nix profile install github:cwill747/triage-factory-nix
```

## Use as a flake input

Add this flake as an input in your own `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    triage-factory.url = "github:cwill747/triage-factory-nix";
  };

  outputs = { nixpkgs, triage-factory, ... }:
    let
      system = "aarch64-darwin"; # or x86_64-linux, etc.
      pkgs = nixpkgs.legacyPackages.${system};
      triagefactory = triage-factory.packages.${system}.default;
    in
    {
      # Add to a devShell
      devShells.${system}.default = pkgs.mkShell {
        packages = [ triagefactory ];
      };

      # Or include in a NixOS/nix-darwin system config
      # environment.systemPackages = [ triagefactory ];
    };
}
```

## Binary cache (Cachix)

Prebuilt binaries are pushed to [`triage-factory.cachix.org`](https://triage-factory.cachix.org) by CI on every push to `main`. Configure your machine to pull from it and avoid local rebuilds:

```bash
# One-time setup
cachix use triage-factory
```

Or, configure it directly in `nix.conf` / `/etc/nix/nix.conf`:

```
substituters = https://cache.nixos.org https://triage-factory.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= triage-factory.cachix.org-1:BcpRtKUQM7KQgT9tAaFF1a9H8qSSM5vfL8UU8HdZlOA=
```

For NixOS / nix-darwin / Home Manager:

```nix
nix.settings = {
  substituters = [ "https://triage-factory.cachix.org" ];
  trusted-public-keys = [ "triage-factory.cachix.org-1:BcpRtKUQM7KQgT9tAaFF1a9H8qSSM5vfL8UU8HdZlOA=" ];
};
```

## Supported platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Updating to a new release

```bash
# Latest release
./update.sh

# Specific version
./update.sh v1.8.0
```

This fetches the source tarball, computes all three Nix hashes (source, npm deps, Go modules), updates `flake.nix`, and runs a verification build.

A GitHub Action is also available — trigger the **Update to latest release** workflow manually from the Actions tab to open a PR with the version bump automatically.

## Dev shell

```bash
nix develop
```

Provides `go`, `nodejs`, `gopls`, and `gotools`.
