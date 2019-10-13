#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

current_dir=$(cd -P -- "$(dirname -- "$BASH_SOURCE[0]")" && pwd -P)

# ensure local images are built
if [ $(doker images | grep -c 'node-red-with-influx:latest') -lt 1 ]; then
  echo "Building node-red image"
  docker build --file "${current_dir}/node-red/nodered-DockerFile.yml" --tag node-red-with-influx:latest .
fi

echo "Starting stack"
docker stack deploy telemetry --compose-file "${current_dir}/compose.yml"

docker stack services telemetry
