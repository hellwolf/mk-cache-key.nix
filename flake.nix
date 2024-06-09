{
  description = "A nix expression to make cache keys for 'half board' nix projects";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
    }:
    flake-utils.lib.eachSystem (flake-utils.lib.allSystems) (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        defaultPackage = pkgs.writeShellScriptBin "mk-cache-key.nix" ''
          export _MK_CACHE_KEY_NIX_DIST_DIR=${./.}
          source ${./lib.sh}
          mk_cache_key "$@"
        '';
      in
      {
        packages.default = defaultPackage;
        apps.default = {
          type = "app";
          program = "${defaultPackage.outPath}/bin/mk-cache-key.nix";
        };
      }
    );
}
