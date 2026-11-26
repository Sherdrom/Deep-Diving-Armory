#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
deploy_root=${1:-$repo_root}
mkdir -p "$deploy_root"
deploy_root=$(cd "$deploy_root" && pwd)

for platform in Windows Linux Mac; do
    for target in Client Server; do
        project="$repo_root/.AssemblyCSharpSource/DDACsSource/${target}Project/${platform}${target}.csproj"
        dotnet build "$project" -c Release -m:1 -p:ModDeployDir="$deploy_root"
    done
done
