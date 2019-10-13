#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

current_dir=$(cd -P -- "$(dirname -- "$BASH_SOURCE[0]")" && pwd -P)

echo "Starting stack"
docker stack deploy telemetry --compose-file "${current_dir}/compose.yml"

docker stack services telemetry
