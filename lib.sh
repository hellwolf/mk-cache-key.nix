mk_cache_key() {
    gitdir="$1"; shift
    modulePath="$1"; shift
    additionalContextFile="$1"; shift

    [ -d "$gitdir" ]  || { echo "Invalid gitdir: $gitdir": exit 1; }
    [ -e "$modulePath" ] || { echo "Invalid module path: $modulePath"; exit 2; }
    if [ -n "$additionalContextFile" ]; then
        [ -f "$additionalContextFile" ] || [ -p "$additionalContextFile" ] || {
            echo "Invalid context file: $additionalContextFile";
            exit 3;
        }
        extraArgs="$extraArgs additionalContextFile = ${additionalContextFile};"
    fi

    nix eval --file nix/mk-cache-key.nix \
        --apply "f: f {
              nixpkgs = import <nixpkgs> {};
              gitdir = $(readlink -f "${gitdir}");
              modulePath = $(readlink -f "${modulePath}");
              ${extraArgs}
            }" \
        "$@"
}

mk_cache_key_json() { mk_cache_key "$@" --json; }
