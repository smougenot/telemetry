#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

current_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# secrets can be placed into secrets.conf file
if [ -f "${current_dir}/secrets.conf" ]; then
  echo 'loading conf  : secrets.conf'
  source "${current_dir}/secrets.conf"
else
  echo "password can be set using the file : ${current_dir}/secrets.conf"
fi

_host=${influx_host:-pi4:8086}
_database=${influx_db:-home_db}
_mesurement=${influx_measurement:-weather}
_user=${influx_user:-}
_pswd=${influx_pwd:-}

# -------------------------------
# Tooling
# -------------------------------

logTimestamp() {
  date +%Y%m%d-%T
}

# log message
# $* message
log() {
  echo -e "$(logTimestamp) " "$@"
}

# Error message plus exit
# $* message
fail() {
  >&2 echo -e "$(logTimestamp) " "$@"
  exit 1
}

queryEndpoint() {
  echo "http://${_host}/query?db=${_database}" 
}

# prepare tmp file
TMPFILE=$(mktemp -t influx_list_XXXXXX.log )
# TMPFILEDELETE=$(mktemp -t influx_delete_XXXXXX.log )

# Cleanup at end of script execution
cleanup () {
  [ -z ${TMPFILE} ] || rm -f ${TMPFILE}
  [ -z ${TMPFILEDELETE:-} ] || rm -f ${TMPFILEDELETE}
}
trap cleanup EXIT

# -------------------------------
# Run
# -------------------------------

#_query="SELECT time, temperature FROM ${_mesurement} WHERE temperature < -100 ORDER BY time DESC limit 500"
_query="SELECT time, temperature FROM ${_mesurement} WHERE temperature > 100 ORDER BY time DESC limit 500"
#_query="SELECT time, pressure FROM ${_mesurement} WHERE pressure > 1000000  AND time >= '2019-11-30T11:30:00Z'  ORDER BY time DESC limit 500"
#_query="SELECT time, humidity FROM ${_mesurement} WHERE humidity > 100  ORDER BY time DESC limit 600"
#_query="SELECT time, light FROM ${_mesurement} WHERE light > 1000"
#_query="SELECT time, UV FROM ${_mesurement} WHERE UV > 2000"

# _query="show queries"

log "User : ${_user}"
log "Query : ${_query}"

# Get timestamps to delete 
log "Query on data for time "
curl -G "$(queryEndpoint)" \
  -u "${_user}:${_pswd}" \
  --data-urlencode "q=${_query}" \
  -H "Accept: application/csv" \
  > "${TMPFILE}" 

if [ $(wc -l < "${TMPFILE}") -le 1 ]; then
  fail "Could not find data : $(cat "${TMPFILE}")"
fi

log "Some lines are to delete : $(wc -l < "${TMPFILE}")"
line1=$(head -n 1 "${TMPFILE}")
if [ "error" == "${line1}" ]; then
  fail "Error during request : $(cat "${TMPFILE}")"
fi

# transform time stamps into delete queries
sed -i "1d; s|.*,.*,\(.*\),.*|\1|g; s|\(.*\)|delete from ${_mesurement} where time = \1;|g" "${TMPFILE}"
# sed -i "1d; s|.*,.*,\(.*\),.*|\1|g; s|\(.*\)|select * from ${_mesurement} where time = \1;|g" "${TMPFILE}"
log "Nb lines to delete : $(wc -l < "${TMPFILE}")"
# cat "${TMPFILE}" | tr -d '\n' > "${TMPFILEDELETE}"
# log "content >\n$(cat "${TMPFILEDELETE}")"

# curl -v -G "$(queryEndpoint)" \
#   -u "${_user}:${_pswd}" \
#   --data-urlencode "q=$(cat "${TMPFILE}")" \
#   -H "Accept: application/csv" \
  
curl -v -F "q=@${TMPFILE}" -F "async=true" "$(queryEndpoint)" \
  -u "${_user}:${_pswd}" 
