#!/usr/bin/env bash
# Type-checks index.ts, which loads react-native-css/types and sets the className props it adds, and control.ts, which
# loads react-native alone. Exits 1 while an error shows only in the index.ts program, 0 once none does and index.ts
# type-checks, and 2 when a step fails, the program does not load react-native-css's types.d.ts, or index.ts has errors
# of its own (a className prop is gone).
set -uo pipefail

cd "$(dirname "$0")" || exit 2

package_version() {
  node -p "require('./node_modules/$1/package.json').version" 2>/dev/null || printf 'not installed'
}

error_keys() {
  sed -n -E 's/^([^ (]+\([0-9]+,[0-9]+\)): error (TS[0-9]+):.*/\1 \2/p' "$1" | sort -u
}

type_check() {
  local project=$1 output=$2
  npx --no-install tsc -p "$project" --pretty false --listFiles >"$output" 2>&1
  local status=$?
  if [ "$status" -gt 2 ] || ! grep -q -E '/lib\.es5\.d\.ts$' "$output"; then
    tail -n 20 "$output"
    echo "SUMMARY: step failed: tsc -p $project exited $status without listing its files ($output)"
    return 2
  fi
}

if [ -f package-lock.json ]; then
  install_command=(npm ci --ignore-scripts --no-audit --no-fund)
else
  install_command=(npm install --ignore-scripts --no-audit --no-fund)
fi
if ! "${install_command[@]}" >install.log 2>&1; then
  tail -n 20 install.log
  echo "SUMMARY: step failed: ${install_command[*]} (install.log)"
  exit 2
fi

system_name=$(uname -s) || exit 2
node_version=$(node --version) || exit 2
npm_version=$(npm --version) || exit 2
package_versions=""
for package in react-native-css react-native typescript; do
  version=$(package_version "$package") || exit 2
  package_versions+=", $package $version"
done
echo "System: $system_name, node $node_version, npm $npm_version$package_versions"

type_check tsconfig.json compiler-output.txt || exit 2
type_check tsconfig.control.json compiler-output-control.txt || exit 2

if ! grep -q 'node_modules/react-native-css/types\.d\.ts$' compiler-output.txt; then
  echo "SUMMARY: step failed: the program did not load node_modules/react-native-css/types.d.ts"
  exit 2
fi

error_keys compiler-output.txt >errors.txt || exit 2
error_keys compiler-output-control.txt >errors-control.txt || exit 2
comm -23 errors.txt errors-control.txt >errors-added.txt || exit 2
new_errors=$(grep "^node_modules/" errors-added.txt)
parse_errors=$(grep -E " TS1[0-9]{3}$" <<<"$new_errors")
index_errors=$(grep -E '^index\.ts\(' compiler-output.txt)

if [ -n "$parse_errors" ]; then
  echo "$parse_errors"
  echo "SUMMARY: step failed: a declaration does not parse, so the check cannot judge it"
  exit 2
fi
if [ -n "$new_errors" ]; then
  while read -r position code; do
    grep -m 1 -F "$position: error $code:" compiler-output.txt | cut -c 1-200
  done <<<"$new_errors"
  in_package=$(grep -c '^node_modules/react-native-css/' <<<"$new_errors")
  in_react_native=$(grep -c '^node_modules/react-native/' <<<"$new_errors")
  echo "SUMMARY: defect: loading react-native-css/types adds $in_package errors in react-native-css/types.d.ts and $in_react_native in react-native's declarations"
  exit 1
fi
if [ -n "$index_errors" ]; then
  echo "$index_errors"
  echo "SUMMARY: step failed: react-native-css/types adds no error, but index.ts no longer type-checks, so a className prop it sets is gone"
  exit 2
fi
echo "SUMMARY: fixed: react-native-css/types adds no error, and index.ts sets className and contentContainerClassName"
exit 0
