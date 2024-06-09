#!/usr/bin/env bash
oops() {
    echo "$*"$'\n'"(from: ${FUNCNAME[*]})" >&2
    exit 1
}

_S="$(readlink -f "${BASH_SOURCE[0]}")"
_D="$(readlink -f "$(dirname "$_S")")"
_GITDIR="$_D"/..
cd "$_GITDIR" || oops "cd to project root folder failed"

source "$_D"/../lib.sh

# Test Cases

_mk_output_with_context() {
    mk_cache_key_json "$_GITDIR" "$_D"/"$1" "$2"
}

_mk_output() {
    _mk_output_with_context "$1" ""
}

test_simplest_module_definition() {
    output=$(_mk_output simplest) || oops "mk_cache_key_json failed"
    expected=$expected_simplest_output

    test "$output" == "$expected" ||
        oops "unexpected output: "$'\n'"$output"$'\n'"with expected: "$'\n'"$expected"
}

test_typical_module() {
    output=$(_mk_output typical) || oops "mk_cache_key_json failed"
    expected=$expected_typical_output
    test "$output" == "$expected" ||
        oops "unexpected output: "$'\n'"$output"$'\n'"with expected: "$'\n'"$expected"
}

test_cyclical_dependency() {
    output=$(_mk_output cyclical) || oops "mk_cache_key_json failed"
    expected=$expected_cyclical_output
    test "$output" == "$expected" ||
        oops "unexpected output: "$'\n'"$output"$'\n'"with expected: "$'\n'"$expected"
}

test_changed_file() {
    f=./test/typical/test.data
    echo > "$f"
    output=$(_mk_output typical) || oops "mk_cache_key_json failed"
    git checkout "$f"

    test "$output" != "$expected_typical_output" ||
        oops "file changed, expecting a different output"
}

test_changed_dependency_file() {
    f=./test/typical/test.data
    echo > "$f"
    output=$(_mk_output cyclical) || oops "mk_cache_key_json failed"
    git checkout "$f"

    test "$output" != "$expected_cyclical_output" ||
        oops "file changed, expecting a different output"
}

test_ignored_file() {
    f=./test/typical/src/to-ignore.sh
    echo > "$f"
    output=$(_mk_output typical) || oops "mk_cache_key_json failed"
    git checkout "$f"

    test "$output" == "$expected_typical_output" ||
        oops "ignored file changed, expecting the same output"
}

test_additional_context() {
    output1=$(_mk_output typical) || oops "_mk_output failed: $output1"
    output2=$(_mk_output_with_context typical <(echo "hello")) ||
        oops "_mk_output_with_context failed: $output2"
    test "$output1" != "$output2" || oops "build context changed, expecting different output"
}

run_all() {
    grep -Eo '^test_[a-zA-Z_]+' "$_S" | while read -r i; do
        if ( "$i" ); then echo "✅ $i"; else echo "❌ $i"; fi
        echo
    done
}

main() {
    if [ -z "$1" ]; then run_all; else "$1"; fi
}

# Appendix: Test Vectors

expected_simplest_output=$(jq -c <<< '
{
  "additionalContext": "",
  "closure": [
    {
      "dependencies": [],
      "ignoredFiles": [],
      "includedFiles": [
        {
          "type": "regex",
          "value": ".*"
        }
      ],
      "modulePath": "./test/simplest",
      "outputs": []
    }
  ],
  "files": [
    "./test/simplest/default.nix"
  ],
  "hash": "e03950f117300eac6824d9445b9ec31aa787ec513b78d2232bc6b1839150eb4d",
  "outputs": []
}
')

expected_typical_output=$(jq -c <<< '
{
  "additionalContext": "",
  "closure": [
    {
      "dependencies": [],
      "ignoredFiles": [],
      "includedFiles": [
        {
          "type": "regex",
          "value": ".*"
        }
      ],
      "modulePath": "./test/simplest",
      "outputs": []
    },
    {
      "dependencies": [
        "./test/simplest"
      ],
      "ignoredFiles": [
        {
          "type": "regex",
          "value": ".*\\.md$"
        },
        {
          "type": "path",
          "value": "./test/typical/src/to-ignore.sh"
        }
      ],
      "includedFiles": [
        {
          "type": "path",
          "value": "./test/typical/src"
        },
        {
          "type": "regex",
          "value": ".*\\.data$"
        }
      ],
      "modulePath": "./test/typical",
      "outputs": [
        "./test/typical/out"
      ]
    }
  ],
  "files": [
    "./test/simplest/default.nix",
    "./test/typical/src/main.hs",
    "./test/typical/test.data"
  ],
  "hash": "109bb55736785a88110b5bd4dee272c98ec5d9e7b3461fd3efce200754af5e65",
  "outputs": [
    "./test/typical/out"
  ]
}
')

expected_cyclical_output=$(jq -c <<< '
{
  "additionalContext": "",
  "closure": [
    {
      "dependencies": [
        "./test/typical",
        "./test/cyclical-dep"
      ],
      "ignoredFiles": [],
      "includedFiles": [
        {
          "type": "regex",
          "value": ".*"
        }
      ],
      "modulePath": "./test/cyclical",
      "outputs": []
    },
    {
      "dependencies": [
        "./test/simplest",
        "./test/cyclical",
        "./test/cyclical-dep"
      ],
      "ignoredFiles": [],
      "includedFiles": [
        {
          "type": "regex",
          "value": ".*"
        }
      ],
      "modulePath": "./test/cyclical-dep",
      "outputs": []
    },
    {
      "dependencies": [],
      "ignoredFiles": [],
      "includedFiles": [
        {
          "type": "regex",
          "value": ".*"
        }
      ],
      "modulePath": "./test/simplest",
      "outputs": []
    },
    {
      "dependencies": [
        "./test/simplest"
      ],
      "ignoredFiles": [
        {
          "type": "regex",
          "value": ".*\\.md$"
        },
        {
          "type": "path",
          "value": "./test/typical/src/to-ignore.sh"
        }
      ],
      "includedFiles": [
        {
          "type": "path",
          "value": "./test/typical/src"
        },
        {
          "type": "regex",
          "value": ".*\\.data$"
        }
      ],
      "modulePath": "./test/typical",
      "outputs": [
        "./test/typical/out"
      ]
    }
  ],
  "files": [
    "./test/cyclical/default.nix",
    "./test/cyclical-dep/default.nix",
    "./test/simplest/default.nix",
    "./test/typical/src/main.hs",
    "./test/typical/test.data"
  ],
  "hash": "424d9d22b0450f3a513b2cfbafa1e4e676bbd54ebd8449a234681737fb110c6b",
  "outputs": [
    "./test/typical/out"
  ]
}
')

main "$@"