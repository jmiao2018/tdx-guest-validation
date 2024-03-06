#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Authors: Pengfei Xu <pengfei.xu@intel.com>
# @Desc show thunderbolt/USB4 CLx values

CARGO_PATH="/root/.cargo/bin:~/.cargo/bin"
DOMAIN="domain"
export PATH=${PATH}:$CARGO_PATH:./

readonly TBDUMP="tbdump"
readonly CLX_OFFSET="0x0037"
readonly TBT_PATH="/sys/bus/thunderbolt/devices"
readonly TBT_DBG_PATH="/sys/kernel/debug/thunderbolt"
readonly CLX_OUTPUT="/tmp/clx_output.txt"

CLx_FILE="CLx.info"
CLx_FILE_PATH=$(which "$CLx_FILE")

DOMAINS=""
HAS_TBTOOLS="0"

check_tb_tools() {
  local check_tbdump=""

  check_tbdump=$(which "$TBDUMP" 2>/dev/null)
  [[ -z "$check_tbdump" ]] && {
    echo "[WARN] No $TBDUMP tool in PATH." | tee "$CLX_OUTPUT"
    echo "Will use /sys/kernel/debug/thunderbolt/x-0/portx/regs | grep ^0x0037 to check CLx:" | tee -a "$CLX_OUTPUT"
    HAS_TBTOOLS="0"
    return 0
  }
  echo "Find $TBDUMP: $check_tbdump" | tee "$CLX_OUTPUT"
  HAS_TBTOOLS="1"
}

list_domains() {
  if [[ -e "$TBT_PATH" ]]; then
    DOMAINS=$(ls "$TBT_PATH"  | grep "$DOMAIN" | awk -F "$DOMAIN" '{print $NF}')
  else
    echo "No TBT/USB4 sysfs path:$TBT_PATH, exit" | tee -a "$CLX_OUTPUT"
    exit 1
  fi
}

show_specific_clx() {
  local domain_n=$1
  local port_n=$2
  local clx_value=""
  local clx_dec=""
  local clx_binary=""
  local clx_info=""

  if [[ "$HAS_TBTOOLS" -eq 1 ]]; then
    clx_value=$(tbdump -r 0 -d $domain_n -a $port_n -C 1 -N 1 1)
  else
    clx_value=$(grep ^$CLX_OFFSET ${TBT_DBG_PATH}/${domain_n}-0/port${port_n}/regs \
                | awk -F " " '{print $NF}')
  fi
  if [[ -z "$clx_value" ]]; then
    printf "Domain $domain_n Port %-2s CLx: %-10s binary:%-5s info: NULL\n" "$port_n" "NULL" "NULL" | tee -a "$CLX_OUTPUT"
  else
    let "clx_dec=$clx_value>>26 & 0xf"
    clx_binary=$(echo "obase=2;${clx_dec}" | bc)
    clx_info=$(grep ^"$clx_binary": "$CLx_FILE_PATH" | awk -F ":" '{print $NF}')
    [[ -z "$clx_info" ]] && clx_info="NULL"
    #echo "Domain $domain_n Port $port_n CLx: $clx_value binary: 0b$clx_binary, info:$clx_info"
    printf "Domain $domain_n Port %-2s CLx: $clx_value binary:0b%-3s info: $clx_info\n" "$port_n" "$clx_binary" | tee -a "$CLX_OUTPUT"
  fi
}

show_domain_clx_status() {
  local domain_n=$1
  local ports=""
  local port=""

  ports=$(ls ${TBT_DBG_PATH}/${domain_n}-0/port* \
          | grep ":"$ \
          | awk -F "port" '{print $NF}' \
          | cut -d ":" -f 1 \
          | sort -n)
  for port in $ports; do
    show_specific_clx "$domain_n" "$port"
  done
}

show_tbt_clx_status() {
  local domain_n=""
  local ports=""

  check_tb_tools
  list_domains
  echo "Register LANE_ADP_CS_1 4bytes CLx(bit 29:26):" | tee -a "$CLX_OUTPUT"

  for domain_n in $DOMAINS; do
    show_domain_clx_status "$domain_n"
  done

  echo | tee -a "$CLX_OUTPUT"
  echo "Thunderbolt/USB4 topo:" | tee -a "$CLX_OUTPUT"
  verify-sysfs.sh -s | tee -a "$CLX_OUTPUT"
}

show_tbt_clx_status
