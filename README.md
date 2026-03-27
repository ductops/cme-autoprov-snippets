# CloudGuard AWS + CME Starter Pack

## Purpose

A practical starter pack for deploying and operating Check Point CloudGuard with AWS bootstrap scripting, CME templates, and `autoprov_cfg` examples for AWS, Azure, and GCP.

## Repo tree

```text
cloudguard-cme-starter-pack/
├── README.md
├── bootstrap/
│   ├── bootstrap-minimal.sh
│   ├── bootstrap-s3-loader.sh
│   ├── bootstrap-marker-only.sh
│   └── examples/
│       ├── bootstrap-string-minimal.txt
│       ├── bootstrap-string-marker.txt
│       └── bootstrap-string-s3-loader.txt
├── cfn/
│   └── cloudguard-aws-params.example.json
├── autoprov/
│   ├── aws/
│   │   ├── 01-add-template.sh
│   │   ├── 02-add-controller.sh
│   │   ├── 03-show-config.sh
│   │   └── notes.md
│   ├── azure/
│   │   ├── 01-add-template.sh
│   │   ├── 02-add-controller.sh
│   │   ├── 03-show-config.sh
│   │   └── notes.md
│   ├── gcp/
│   │   ├── 01-add-template.sh
│   │   ├── 02-add-controller.sh
│   │   ├── 03-show-config.sh
│   │   └── notes.md
│   └── common/
│       ├── 00-help.sh
│       ├── 98-backup-current-config.sh
│       └── 99-rollback-notes.md
├── mgmt/
│   ├── bulk_cloudguard_update.sh
│   └── gateways.txt
└── docs/
    ├── rollout-checklist.md
    ├── troubleshooting.md
    └── rollback.md
```

## Design rules

- Use **official deployment templates / parameters** for AWS.
- Keep **bootstrap/user-data** small and deterministic.
- Use **CME templates** for cloud-managed autoscaling behavior.
- Use **`mgmt_cli`** for central managed updates, publish, and policy install.
- Treat **`autoprov_cfg`** as a CLI automation path, not the preferred new UI path.

## Bootstrap examples

### `bootstrap/examples/bootstrap-string-minimal.txt`

```text
clish -c "lock database override"; clish -c "set dns primary 10.10.10.10"; clish -c "set dns secondary 10.10.10.11"; clish -c "set ntp active on"; clish -c "set ntp server primary 169.254.169.123 version 4"; clish -c "set ntp server secondary 0.pool.ntp.org version 4"; clish -c "save config"
```

### `bootstrap/examples/bootstrap-string-marker.txt`

```text
/bin/bash -c "echo BOOTSTRAP_START_$(date +%s) >> /var/log/bootstrap-marker.log"; clish -c "lock database override"; clish -c "set dns primary 10.10.10.10"; clish -c "set ntp active on"; clish -c "set ntp server primary 169.254.169.123 version 4"; clish -c "save config"; /bin/bash -c "echo BOOTSTRAP_DONE_$(date +%s) >> /var/log/bootstrap-marker.log"
```

### `bootstrap/examples/bootstrap-string-s3-loader.txt`

```text
/bin/bash -c "aws s3 cp s3://my-cg-bootstrap-bucket/aws/bootstrap-v1.sh /var/tmp/bootstrap-v1.sh && chmod 700 /var/tmp/bootstrap-v1.sh && /var/tmp/bootstrap-v1.sh"
```

### `bootstrap/bootstrap-minimal.sh`

```bash
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap-minimal.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== bootstrap-minimal start: $(date) ====="
sleep 60
clish -c "lock database override"
clish -c "set dns primary 10.10.10.10"
clish -c "set dns secondary 10.10.10.11"
clish -c "set ntp active on"
clish -c "set ntp server primary 169.254.169.123 version 4"
clish -c "set ntp server secondary 0.pool.ntp.org version 4"
clish -c "save config"
echo "===== bootstrap-minimal complete: $(date) ====="
```

### `bootstrap/bootstrap-marker-only.sh`

```bash
#!/bin/bash
set -euo pipefail

echo "bootstrap-start $(date)" >> /var/log/bootstrap-marker.log
sleep 30
echo "bootstrap-done $(date)" >> /var/log/bootstrap-marker.log
```

### `bootstrap/bootstrap-s3-loader.sh`

```bash
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap-s3-loader.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== bootstrap-s3-loader start: $(date) ====="
aws s3 cp s3://my-cg-bootstrap-bucket/aws/bootstrap-v1.sh /var/tmp/bootstrap-v1.sh
chmod 700 /var/tmp/bootstrap-v1.sh
/var/tmp/bootstrap-v1.sh
echo "===== bootstrap-s3-loader complete: $(date) ====="
```

## AWS parameter example

### `cfn/cloudguard-aws-params.example.json`

```json
[
  {"ParameterKey":"KeyName","ParameterValue":"my-aws-keypair"},
  {"ParameterKey":"Name","ParameterValue":"cg-prod-east"},
  {"ParameterKey":"GatewayPasswordHash","ParameterValue":"$6$replace_with_real_hash"},
  {"ParameterKey":"SICKey","ParameterValue":"ReplaceThisWithStrongSICKey123!"},
  {"ParameterKey":"ManagementServer","ParameterValue":"10.50.0.10"},
  {"ParameterKey":"GatewaysAddresses","ParameterValue":"private"},
  {"ParameterKey":"CloudWatchMetrics","ParameterValue":"true"},
  {"ParameterKey":"PrimaryNTPServer","ParameterValue":"169.254.169.123"},
  {"ParameterKey":"SecondaryNTPServer","ParameterValue":"0.pool.ntp.org"},
  {"ParameterKey":"BootstrapScript","ParameterValue":"clish -c \"lock database override\"; clish -c \"set dns primary 10.10.10.10\"; clish -c \"set dns secondary 10.10.10.11\"; clish -c \"set ntp active on\"; clish -c \"save config\""}
]
```

## `autoprov_cfg` quick notes

- Prefer **SmartConsole / Web SmartConsole / Smart-1 Cloud CME configuration** for new work.
- Use `autoprov_cfg add` and `autoprov_cfg set` on existing environments.
- Avoid `autoprov_cfg init` on a live CME deployment unless you explicitly intend to replace the config.

## Common helpers

### `autoprov/common/00-help.sh`

```bash
autoprov_cfg -h
autoprov_cfg add controller -h
autoprov_cfg add template -h
autoprov_cfg set controller -h
autoprov_cfg set template -h
autoprov_cfg show all
```

### `autoprov/common/98-backup-current-config.sh`

```bash
#!/bin/bash
set -euo pipefail
OUT="/var/log/autoprov-backup-$(date +%Y%m%d-%H%M%S).txt"
autoprov_cfg show all | tee "$OUT"
echo "Backup written to $OUT"
```

## AWS `autoprov_cfg`

### `autoprov/aws/01-add-template.sh`

```bash
autoprov_cfg add template \
  -tn tpl-aws-prod \
  -otp 'StrongSICKey123!' \
  -ver R81.20 \
  -po Standard \
  -rp Restrictive-First \
  -ia -appi -ips -uf -ab -av -te -vpn -ca -hi -atp \
  -sl "PrimaryLog1" \
  -sbl "BackupLog1" \
  -sa "AlertLog1" \
  -cg '$FWDIR/conf/gw-script.sh env=prod cloud=aws' \
  -g 1 \
  -secn "CME Auto Rules" \
  -pn awsprod \
  -nk "save-logs-locally" "true" \
  -aap
```

### `autoprov/aws/02-add-controller.sh`

```bash
autoprov_cfg add controller AWS \
  -cn aws-prod-east \
  -r us-east-1,us-east-2 \
  -iam \
  -sr arn:aws:iam::123456789012:role/CheckpointCME-Role \
  -se my-external-id-123 \
  -ct tpl-aws-prod \
  -dto 10 \
  -sv \
  -slb \
  -ss
```

### `autoprov/aws/03-show-config.sh`

```bash
autoprov_cfg show controllers
autoprov_cfg show templates
autoprov_cfg show all
```

### `autoprov/aws/notes.md`

- `-aap` is AWS-only and applies automatic policy logic for supported AWS autoscaling / TGW patterns.
- `-r` is the AWS region list.
- `-iam` uses IAM role profile auth.
- `-sr` / `-se` support STS assume-role.
- `-sv`, `-slb`, and `-ss` enable VPN sync, LB rule automation, and subnet scanning options.

## Azure `autoprov_cfg`

### `autoprov/azure/01-add-template.sh`

```bash
autoprov_cfg add template \
  -tn tpl-azure-prod \
  -otp 'StrongSICKey123!' \
  -ver R81.20 \
  -po Standard \
  -ia -appi -ips -uf -ab -av -te -vpn -ca -hi -atp \
  -sl "PrimaryLog1" \
  -cg '$FWDIR/conf/gw-script.sh env=prod cloud=azure' \
  -g 1 \
  -secn "CME Auto Rules" \
  -pn azprod \
  -an \
  -v6
```

### `autoprov/azure/02-add-controller.sh`

```bash
autoprov_cfg add controller Azure \
  -cn azure-prod-central \
  -sb 11111111-2222-3333-4444-555555555555 \
  -en AzureCloud \
  -at 66666666-7777-8888-9999-aaaaaaaaaaaa \
  -aci bbbbbbbb-cccc-dddd-eeee-ffffffffffff \
  -acs 'SuperSecretValueHere' \
  -ct tpl-azure-prod \
  -dto 10
```

### `autoprov/azure/03-show-config.sh`

```bash
autoprov_cfg show controllers
autoprov_cfg show templates
autoprov_cfg show all
```

### `autoprov/azure/notes.md`

- `-sb` is the Azure subscription ID.
- `-en` selects the Azure cloud environment.
- `-at`, `-aci`, and `-acs` are the tenant, app/client ID, and client secret.
- `-an` and `-v6` are Azure-specific template flags.

## GCP `autoprov_cfg`

### `autoprov/gcp/01-add-template.sh`

```bash
autoprov_cfg add template \
  -tn tpl-gcp-prod \
  -otp 'StrongSICKey123!' \
  -ver R81.20 \
  -po Standard \
  -ia -appi -ips -uf -ab -av -te -vpn -ca -hi -atp \
  -sl "PrimaryLog1" \
  -cg '$FWDIR/conf/gw-script.sh env=prod cloud=gcp' \
  -g 1 \
  -secn "CME Auto Rules" \
  -pn gcpprod
```

### `autoprov/gcp/02-add-controller.sh`

```bash
autoprov_cfg add controller GCP \
  -cn gcp-prod-east \
  -proj my-gcp-prod-project \
  -cr $FWDIR/conf/my-gcp-prod-project-sa.json \
  -ct tpl-gcp-prod \
  -dto 10
```

### `autoprov/gcp/03-show-config.sh`

```bash
autoprov_cfg show controllers
autoprov_cfg show templates
autoprov_cfg show all
```

### `autoprov/gcp/notes.md`

- `-proj` is the GCP project ID.
- `-cr` points to the service account key file.
- `-crd` can be used instead of `-cr` for base64-encoded service account content.

## Management-side bulk script

### `mgmt/bulk_cloudguard_update.sh`

```bash
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
```

## Rollback

### `docs/rollback.md`

1. Run `autoprov_cfg show all` and save the output before changes.
2. Add new controllers/templates with `add`; avoid `init` on a live environment.
3. Roll back by deleting only the new controller/template you added.
4. If you changed an existing template, re-apply the previous values with `autoprov_cfg set template ...`.
5. For management changes, restore the prior values with `mgmt_cli`, publish, and reinstall policy.
6. For bootstrap, revert the CloudFormation parameter or point the S3 loader back to the prior versioned script.

## Troubleshooting

### `docs/troubleshooting.md`

### Bootstrap
- Confirm the deployment template actually populated the bootstrap field.
- Keep the bootstrap field semicolon-separated and small.
- Use a marker file first if you just need to prove execution.
- Check `/var/log/bootstrap-*.log` and marker files.
- Avoid risky early-boot network changes.

### CME / `autoprov_cfg`
- Back up current config with `autoprov_cfg show all` before edits.
- Use `autoprov_cfg add controller -h` and `autoprov_cfg add template -h` on-box for version-specific syntax.
- If credentials are wrong, fix the controller first.
- If gateways are discovered but wrong, check template linkage (`-ct`) and name prefix behavior (`-pn`).
- If gateway-side scripting is needed after policy install, validate the repository/custom script path and permissions.

### `mgmt_cli`
- Test with harmless object comment changes before real config.
- Confirm object names match exactly.
- Publish before install-policy.
- Run on one gateway first.

## Suggested rollout order

1. Test one AWS deployment with `bootstrap-string-marker.txt`.
2. Move to `bootstrap-string-minimal.txt`.
3. Move to the S3 loader once the first two work.
4. Add one CME template.
5. Add one controller.
6. Validate `autoprov_cfg show all`.
7. Test `mgmt_cli` on one non-production gateway.
8. Expand in small waves.
```

