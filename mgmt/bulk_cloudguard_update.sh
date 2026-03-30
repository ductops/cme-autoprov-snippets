#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SID_FILE="/var/tmp/${SCRIPT_NAME}.sid"
LOG_FILE="/var/log/${SCRIPT_NAME%.sh}.log"
GATEWAY_LIST_FILE="${1:-gateways.txt}"
POLICY_PACKAGE="${2:-Standard}"
MGMT_CLI="/usr/bin/mgmt_cli"

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

cleanup() {
  [[ -f "$SID_FILE" ]] && rm -f "$SID_FILE"
}
trap cleanup EXIT

require_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Missing file: $f" >&2; exit 1; }
}

login() {
  log "Logging in to management API..."
  "$MGMT_CLI" login -r true > "$SID_FILE"
}

logout() {
  log "Logging out..."
  "$MGMT_CLI" logout -s "$SID_FILE" >/dev/null
}

gateway_exists() {
  local gw="$1"
  "$MGMT_CLI" show simple-gateway name "$gw" -s "$SID_FILE" >/dev/null 2>&1
}

update_gateway_comment() {
  local gw="$1"
  local comment="Updated by bulk script on $(date '+%Y-%m-%d %H:%M:%S')"
  log "Updating comment on gateway: $gw"
  "$MGMT_CLI" set simple-gateway name "$gw" comments "$comment" -s "$SID_FILE" >/dev/null
}

publish_changes() {
  log "Publishing changes..."
  "$MGMT_CLI" publish -s "$SID_FILE" >/dev/null
}

install_policy() {
  local gw="$1"
  log "Installing policy package '$POLICY_PACKAGE' on '$gw'..."
  "$MGMT_CLI" install-policy policy-package "$POLICY_PACKAGE" targets.1 "$gw" -s "$SID_FILE" >/dev/null
}

main() {
  require_file "$GATEWAY_LIST_FILE"
  login

  while IFS= read -r gw; do
    [[ -z "${gw// }" ]] && continue
    [[ "${gw:0:1}" == "#" ]] && continue
    if gateway_exists "$gw"; then
      update_gateway_comment "$gw"
    else
      log "WARNING: gateway not found: $gw"
    fi
  done < "$GATEWAY_LIST_FILE"

  publish_changes

  while IFS= read -r gw; do
    [[ -z "${gw// }" ]] && continue
    [[ "${gw:0:1}" == "#" ]] && continue
    if gateway_exists "$gw"; then
      install_policy "$gw"
    fi
  done < "$GATEWAY_LIST_FILE"

  logout
  log "Bulk update complete."
}

main "$@"
