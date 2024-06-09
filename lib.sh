# use posix shell type for the library
# shellcheck shell=sh

if [ -z "$_MK_CACHE_KEY_NIX_DIST_DIR" ]; then
   # infer dist dir for bash
   # ref: https://stackoverflow.com/questions/5166657/how-do-i-tell-what-type-my-shell-is
   # shellcheck disable=SC3028,SC3054
   if test -n "$BASH_VERSION"; then
       _MK_CACHE_KEY_NIX_DIST_DIR="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
   fi
fi
# otherwise, user must provider _MK_CACHE_KEY_NIX_DIST_DIR manually
# ref: https://unix.stackexchange.com/questions/4650/how-to-determine-the-path-to-a-sourced-tcsh-or-bash-shell-script-from-within-the
[ -n "$_MK_CACHE_KEY_NIX_DIST_DIR" ] ||
    { echo "_MK_CACHE_KEY_NIX_DIST_DIR not inferred or provided"; exit 42; }

mk_cache_key() {
    gitdir="$1"; shift
    modulePath="$1"; shift
    additionalContextFile="$1"; shift

    [ -d "$gitdir" ] || { echo "Invalid gitdir: $gitdir"; exit 1; }
    [ -e "$modulePath" ] || { echo "Invalid module path: $modulePath"; exit 2; }
    if [ -n "$additionalContextFile" ]; then
        [ -f "$additionalContextFile" ] || [ -p "$additionalContextFile" ] || {
            echo "Invalid context file: $additionalContextFile";
            exit 3;
        }
        extraArgs="$extraArgs additionalContextFile = ${additionalContextFile};"
    fi

    nix eval --file "$_MK_CACHE_KEY_NIX_DIST_DIR"/nix/mk-cache-key.nix \
        --apply "f: f {
              nixpkgs = import <nixpkgs> {};
              gitdir = $(readlink -f "${gitdir}");
              modulePath = $(readlink -f "${modulePath}");
              ${extraArgs}
            }" \
        "$@"
}

mk_cache_key_json() { mk_cache_key "$@" --json; }
