#!/bin/bash
###############################################################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################

# Copyright (C) 2015, Intel - http://www.intel.com
# @Author   Luis Rivas <luis.miguel.rivas.zepeda@intel.com>
# @desc     Common function to parse xml files
# @history  2015-07-16: First Version (Luis Rivas)

source "common.sh"     # include ltp-ddt common functions

############################# Functions #######################################
load_xml() {
  local xml_file=$1

  if [[ -f "$xml_file" ]]; then
    test_print_trc "XML file $xml_file loaded for processing"
    XML_FILE=$xml_file
    return 0
  else
    test_print_trc "XML file $xml_file does not exists"
    return 1
  fi
}

unload_xml() {
  XML_FILE=""
  test_print_trc "XML file unloaded"

  return 0
}

# Get first level childs of root tag, it returns a list of child:line_num
get_xml_childs() {
  local root=$1             # Root element, where to start reading
  local start_line=${2:-0}  # Start location on xml to search for root tag
  local childs=""           # Stores the tag/line of each child
  local in=0                # Indicates if we are reading elements inside root
  local child=""            # Indicates the tag of the current child
  local in_child=0          # Indicates if we are reading the content of a child
  local count=1             # Count line numbers

  while read -r line; do
    if [[ $count -lt "$start_line" ]]; then
      count=$((count + 1))
      continue
    fi
    # Defines if we are reading the content inside the root
    if [[ $line =~ \<${root}[\>|\s.*\>] ]] && [[ $in -eq 0 ]]; then
      in=1
      count=$((count + 1))
      continue
    elif [[ $line =~ \</${root}\> ]] && [[ $in -eq 1 ]]; then
      break
    fi

    # We are inside the root tag, start searching childs
    if [[ $in -eq 1 ]]; then
      # Search first level childs
      if [[ $in_child -eq 0 ]] && [[ $line =~ \<[^!].*\> ]]; then
        in_child=$((in_child + 1))
        child=$(echo "$line" \
                | grep -Eo '\<[a-zA-Z0-9_\.]*' \
                | head -n 1 \
                | tr '<|>|\n' ' ' \
                | xargs)
        childs="$childs $child:$count"
      elif [[ $in_child -gt 0 ]] && [[ $line =~ \<${child}\> ]]; then
        in_child=$((in_child + 1))  # We found a subchild with the child's tag
      fi

      # Close first level childs
      if [[ $in_child -gt 0 ]] && [[ $line =~ \</${child}\> ]]; then
        in_child=$((in_child - 1))
      fi
    fi
    count=$((count + 1))
  done < $XML_FILE
  echo "$childs"

  return 0
}

# Returns list attribute in format ID=Value"
get_xml_attributes() {
  local line_num=$1     # Tag's line
  local content=""      # Stores tag content
  local line_txt=""

  line_txt=$(sed -n "${line_num}p" < $XML_FILE)
  attt=$(echo "$line_txt" | grep -Eo '[a-zA-Z0-9_-\.]*=[a-zA-Z0-9_-\.]*')
  echo "$attt"

  return 0
}

# Retunrs content of line
get_xml_content(){
  local line_num=$1     # Tag's line
  local content=""      # Stores tag content
  local line_txt=""

  line_txt=$(sed -n "${line_num}p" < $XML_FILE)
  content=$(echo "$line_txt" | grep -Eo '\>.*\<' | tr '<|>|/' ' ' | xargs)
  echo "$content"

  return 0
}

############################ Script Variables ##################################
XML_FILE=""
