#!/bin/bash
set -euo pipefail
sleep 60
clish -c "lock database override"
clish -c "set dns primary 10.10.10.10"
clish -c "set ntp active on"
clish -c "set ntp server primary 169.254.169.123 version 4"
clish -c "save config"
