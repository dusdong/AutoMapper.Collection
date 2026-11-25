#!/bin/bash
set -euo pipefail

usage() {
    echo '用法：bash pack-r3-candidate.sh <11.0.0-r3.N> <引擎 nupkg> <引擎 SHA-256> <新输出目录>' >&2
    exit 2
}

[[ $# -eq 4 && "$1" =~ ^11[.]0[.]0-r3[.]([1-9][0-9]*)$ ]] || usage
version=$1
engine_version="14.0.0-r3.${BASH_REMATCH[1]}"
engine=$2
engine_sha=$3
engine_name="Du.AutoMapper.$engine_version.nupkg"
[[ -f "$engine" && "${engine##*/}" == "$engine_name" && "$engine_sha" =~ ^[a-f0-9]{64}$ ]] || usage
actual_sha=$(shasum -a 256 < "$engine")
if [[ "${actual_sha%% *}" != "$engine_sha" ]]; then
    echo "引擎包 SHA-256 不符：$engine" >&2
    exit 1
fi

source=$(cd "$(dirname "$0")" && pwd -P)
dotnet=${DOTNET:-dotnet}
mkdir -- "$4"
output=$(cd "$4" && pwd -P)
trap 'printf "%s\n" "$?" > "$output/exit-code.txt"' EXIT
mkdir "$output/inputs" "$output/logs" "$output/packed"
cp -- "$engine" "$output/inputs/$engine_name"
cd "$output"
printf '%s\n' '{"sdk":{"version":"10.0.404","rollForward":"disable","allowPrerelease":false}}' > global.json
cat > NuGet.Config <<'EOF'
<configuration>
  <packageSources>
    <clear />
    <add key="inputs" value="./inputs" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="inputs"><package pattern="Du.AutoMapper" /></packageSource>
    <packageSource key="nuget.org"><package pattern="*" /></packageSource>
  </packageSourceMapping>
</configuration>
EOF

export NUGET_PACKAGES="$output/packages" NUGET_HTTP_CACHE_PATH="$output/http-cache" DOTNET_CLI_HOME="$output/dotnet-home"
export DOTNET_CLI_UI_LANGUAGE=en DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 MSBUILDDISABLENODEREUSE=1
run() {
    local label=$1 rc=0
    shift
    printf '%q ' "$@" >> commands.log
    printf '> %s\n' "logs/$label.log" >> commands.log
    "$@" > "logs/$label.log" 2>&1 || rc=$?
    printf '退出码 %s\n' "$rc" >> commands.log
    if [[ "$rc" -ne 0 ]]; then
        tail -n 30 "logs/$label.log" >&2
    fi
    return "$rc"
}

project="$source/src/AutoMapper.Collection/AutoMapper.Collection.csproj"
tests="$source/src/AutoMapper.Collection.Tests/AutoMapper.Collection.Tests.csproj"
properties=(-p:Configuration=Release -p:UseSharedCompilation=false "-p:ArtifactsPath=$output/artifacts"
    -p:DuR3CollectionCandidate=true "-p:DuR3CollectionEngineVersion=$engine_version" "-p:MinVerVersionOverride=$version")
run sdk "$dotnet" --info
run restore "$dotnet" restore "$tests" "${properties[@]}" --configfile "$output/NuGet.Config" --disable-build-servers
run test "$dotnet" test "$tests" "${properties[@]}" --no-restore --disable-build-servers --verbosity normal \
    --logger 'trx;LogFileName=collection.trx' --results-directory "$output/tests" "-bl:$output/test.binlog"
run test-count python3 -c '
import sys
import xml.etree.ElementTree as ET
counters = ET.parse(sys.argv[1]).find(".//{*}Counters").attrib
print(counters)
sys.exit(not (int(counters["executed"]) > 0 and counters["executed"] == counters["passed"] == counters["total"]))
' "$output/tests/collection.trx"
run pack "$dotnet" pack "$project" "${properties[@]}" --no-build --no-restore --disable-build-servers \
    --output "$output/packed" "-bl:$output/pack.binlog"

package="Du.AutoMapper.Collection.$version"
test -f "packed/$package.nupkg" && test -f "packed/$package.snupkg"
mkdir feed symbols
mv "packed/$package.nupkg" feed/
mv "packed/$package.snupkg" symbols/
shasum -a 256 "feed/$package.nupkg" "symbols/$package.snupkg" "inputs/$engine_name" > packages.sha256
