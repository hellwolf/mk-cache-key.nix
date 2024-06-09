# mk-cache-key.nix

A nix expression to make cache keys for "half board" nix projects.

# Background

## What Is a "Half Board" Nix Project?

A "half board" nix project is a project that is not entirely "nixified". According to some informal
definition, a nixified project is where its build is described fully with nix expressions, and its
nix build results nix store outputs. A "half board" project only defines its development tooling in
nix shells and immutable outputs are guaranteed not by Nix but by mechanisms provided by those
development tooling, usually with their build description and lock files.

## Why Don't You Just Nixify Your Project?

There are several reasons for not nixifying your project (yet):

1. Nixification of projects in some languages needs more support.
2. In a team environment, if only some people use Nix for local development, it could result in a divergence
   between CI and local development results.
3. Procrastination.

## How Do a "Half Board" Nix Project Look Like?

A "half board" nix project is consistent of a set of "half board" nix modules defined in nix
expressions with their dependencies with each other.

# "Half Board" Nix Module Specification

The complete specification is embedded in [nix/mk-cache-key.nix](nix/mk-cache-key.nix)

Some examples are provided in the [test folders](test/) along with a [test runner for
them](test/run-test.sh).

# Usage

## Produce Cache Description

```shell

```

## Using Flake

The following snippets makes `mk-cache-key.nix` script available in your dev shell:

```nix
inputs.mk-cache-key = {
  url = "github:hellwolf/mk-cache-key.nix/master";
  inputs.flake-utils.follows = "flake-utils";
  inputs.nixpkgs.follows = "nixpkgs";
};

devShells.mk-cache-key = pkgs.mkShell {
  buildInputs = [ mk-cache-key.packages.${system}.default ];
};
```

To use this, and include the git submodule status as part of the build context:

```shell
# create additional build context
{
    # include git submodule status
    git submodule status
} > additional-build-context.ignored

mk-cache-key.nix "$PWD" "$modulePath" ./additional-build-context.ignored --json
```
