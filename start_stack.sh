#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

current_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# secrets can be placed into secrets.env file
if [ -f "${current_dir}/secrets.env" ]; then
  echo 'loading env  : secrets.env'
  source "${current_dir}/secrets.env"
else
  echo "password can be set using the file : ${current_dir}/secrets.env"
fi

# ensure local images are built
if [ $(docker images | grep -c 'node-red-with-influx') -lt 1 ]; then
  echo "Building node-red image"
  docker build --file "${current_dir}/node-red/nodered-DockerFile.yml" --tag node-red-with-influx:latest .
fi

echo "Process secrets"
# not all images manage secrets the way `docker secret`
# so keep to the manual way

# Create the working copy of the files
[ -d "${current_dir}/temp" ] && rm -rf "${current_dir}/temp"
mkdir -p "${current_dir}/temp"
find "${current_dir}" -maxdepth 1 -type f \
    -exec cp {} "${current_dir}/temp/" \;
find "${current_dir}" -maxdepth 1 -type d \
    -not -name 'temp' \
    -not -name '.git' \
    -not -name '.' \
    -not -path "${current_dir}" \
    -exec cp -R '{}' "${current_dir}/temp/" \;

_sed_args=''
_need_abort=''
for p in INFLUXDB_ADMIN_PASSWORD INFLUXDB_USER_PASSWORD INFLUXDB_READ_PASSWORD GF_SECURITY_ADMIN_PASSWORD; do
  if [ -z "${!p:-}" ]; then
    >&2 echo "Please set environment variable ${p} : ${!p:-}"
    _need_abort='yes'
  fi
  [ ! -z "${_sed_args}" ] && _sed_args="${_sed_args};" 
  _sed_args="${_sed_args} s/@@${p}@@/${!p:-}/g"
done
[ -z ${_need_abort} ] || exit 1

# echo "debug sed : ${_sed_args} "
find temp -type f -exec sed -i "${_sed_args}" '{}' \;

#
# Run the stack
#

echo "Starting stack"
docker stack deploy telemetry --compose-file "${current_dir}/temp/compose.yml"

docker stack services telemetry
