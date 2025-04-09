#!/bin/bash

# Initialize a variable to track the presence of the -s option
s_flag=0

# Loop through the arguments using getopts
while getopts "s" opt; do
  case $opt in
  s)
    s_flag=1 # Set s_flag to 1 if -s is passed
    ;;
  \?) ;;
  esac
done

cache_file="/tmp/ssh_config_cache"
hash_file="/tmp/ssh_config_hash"
tw_file="/tmp/xxh_text_width"
homedir=$HOME
# columns=$(/usr/bin/tput cols)
text_width=264

# Function to calculate MD5 hashes of the config files
calculate_hash() {
  md5 ${homedir}/.ssh/config* 2>/dev/null | md5
}

# Calculate current hash
current_hash=$(calculate_hash)

header="Secure Shell Connections"
FMENU=(
  fzf
  --tmux 95%,80%
  --header="$header"
  --layout=reverse
  --border=bold
  --border=rounded
  --margin=5%
  --multi
  --color=dark
  --info=hidden
  --header-first
  --bind change:top
  --prompt
)

# Check if the cache and hash files exist and compare hashes
if [[ -f "$cache_file" ]] &&
  [[ -f "$hash_file" ]] &&
  [[ "$(cat "$hash_file")" == "$current_hash" ]] &&
  [[ "$(cat "$tw_file")" == "$text_width" ]]; then
  # Cache is up to date, load the list from the cache
  list=()
  while IFS= read -r line; do
    list+=("$line")
  done <"$cache_file"
else
  echo "$text_width" >"$tw_file"
  # Cache needs updating
  declare -a list=()

  for file in ${homedir}/.ssh/config*; do
    if [[ -f "$file" ]]; then
      while IFS='#' read -r host desc; do
        if [[ -n $desc ]]; then
          host="${host#Host }"
          desc=$(echo "$desc" | sed -E 's/_[A-Z]+_//g')
          hostLength=${#host}
          descLength=${#desc}
          totalLength=$text_width
          spaces=$((totalLength - hostLength - descLength))
          spaces=$((spaces > 0 ? spaces : 0))
          space_string=$(printf '%*s' "$spaces")
          row="${desc}${space_string}${host}"
          list+=("$row")
        fi
      done < <(grep "^Host" "$file" 2>/dev/null)
    fi
  done

  # Save the list to cache
  printf "%s\n" "${list[@]}" >"$cache_file"
  # Save the new hash
  echo "$current_hash" >"$hash_file"
fi

selected_row=$(printf "%s\n" "${list[@]}" | "${FMENU[@]}" "Select session: ")
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
