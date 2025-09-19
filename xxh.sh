#!/usr/local/bin/bash

s_flag=0

while getopts "s" opt; do
  case $opt in
  s)
    s_flag=1
    ;;
  \?) ;;
  esac
done

cache_file="/tmp/ssh_config_cache"
hash_file="/tmp/ssh_config_hash"
tw_file="/tmp/ssh_config_tw"

homedir=$HOME
client_width=$(tmux display-message -p '#{client_width}')
text_width=$((($client_width * 40) / 100))

# Function to calculate hash of .ssh directory
calculate_hash() {
  md5 ${homedir}/.ssh/config* 2>/dev/null | md5
}

# Build hosts list from .ssh directory
list_hosts() {
  local line=$2
  local host
  local desc

  if [[ $line =~ ^Host.*#.* ]]; then
    IFS=# read -r host desc <<<${line:5}
    desc="${desc/_[A-Z]*_/}"
    spaces=$(($text_width - ${#host} - ${#desc}))
    space_string=$(printf '%*s' "$spaces")
    row="${desc}${space_string}${host}"
    list+=("$row")
  fi

  # Save the list to cache
  printf "%s\n" "${list[@]}" >"$cache_file"

  # Save the new hash
  echo "$current_hash" >"$hash_file"
}

# Calculate current hash
current_hash=$(calculate_hash)

border_label="Secure Shell Connections"

# Check if the cachefile exists and compare hashes
if [[ -f "$cache_file" ]] && [[ "$text_width" == "$(cat "$tw_file")" ]] &&
  [[ "$(cat "$hash_file")" == "$current_hash" ]]; then

  # Cache is up to date, load the list from the cache
  list=()
  mapfile -t list <$cache_file
else
  # Cache is missing or hash doesn't match, rebuild list
  declare -a list=()
  border_label="Secure Shell Connections NEW"
  echo "$text_width" >"$tw_file"

  for file in ${homedir}/.ssh/config*; do
    mapfile -t -C list_hosts -c 1 hosts <$file
  done
fi

fzf_width=$(($text_width + 10))
fzf_height=$((${#list[@]} + 6))
client_height=$(($(tmux display-message -p '#{client_height}') - 6))

((fzf_height > client_height)) && fzf_height=$client_height

FMENU=(
  fzf
  --tmux $(echo $fzf_width),$(echo $fzf_height)
  --layout=reverse
  --border=bold
  --border=rounded
  --border-label="${border_label}"
  --border-label-pos=center
  --margin=2%
  --multi
  --color 'fg:7'
  --color 'bg:233'
  --color 'current-fg:13'
  --color 'current-bg:233'
  --color 'pointer:13'
  --color 'hl:13'
  --color 'border:6'
  --color 'label:13'
  --color 'header:7'
  --color 'prompt:7'
  --info=hidden
  --header-first
  --bind change:top
  --prompt
)

selected_row=$(printf "%s\n" "${list[@]}" | "${FMENU[@]}" "Select host: ")
if [[ -n "$selected_row" ]]; then

  selection_array=()
  while IFS= read -r line; do
    selection_array+=("$line")
  done <<<"$selected_row"

  for i in "${selection_array[@]}"; do
    hostname=$(awk '{print $NF}' <<<"$i")
    tmux new-window -n "${hostname}" ssh $hostname
  done
fi
