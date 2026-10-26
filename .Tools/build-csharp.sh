#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
deploy_root=${1:-$repo_root}
mkdir -p "$deploy_root"
deploy_root=$(cd "$deploy_root" && pwd)

for solution in "$repo_root"/.AssemblyCSharpSource/*/*.sln; do
    [[ -e "$solution" ]] || continue
    [[ "$solution" == */LuaCsModTemplate/* ]] && continue
    dotnet build -c Release -m:1 -p:ModDeployDir="$deploy_root/" "$solution"
done
