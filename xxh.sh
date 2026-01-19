#!/opt/homebrew/bin/bash

s_flag=0

while getopts "s" opt; do
  case $opt in
  s)
    s_flag=1
    ;;
  \?) ;;
  esac
done

client_width=$(tmux display-message -p '#{client_width}')
fzf_width=$(($client_width * 65 / 100))
text_width=$(($fzf_width - 8))

FMENU=(
  fzf
  --tmux 65%,80%
  --layout=reverse
  --border=bold
  --border=rounded
  --border-label="Secure Shell Connections"
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

dir="$HOME/.ssh"
raw=()
list=()

for file in $dir/config*; do
  [[ -f $file ]] || continue
  while IFS= read -r line; do
    if [[ $line =~ ^Host.*#.* ]]; then
      raw+=("$line")
    fi
  done <"$file"
done

for record in "${raw[@]}"; do
  host=${record:5}
  host="${host%% #*}"
  desc="${record##* #}"
  desc="${desc/ _[A-Z]*_/}"
  hostlength=${#host}
  desclength=${#desc}
  spaces=$((text_width - hostlength - desclength - 7))
  space_string=$(printf '%*s' "$spaces")
  list+=("$host$space_string$desc")
done

selected_row=$(printf "%s\n" "${list[@]}" | "${FMENU[@]}" "Select host: ")
if [[ -n "$selected_row" ]]; then

  selection_array=()
  while IFS= read -r line; do
    selection_array+=("$line")
  done <<<"$selected_row"

  if [[ s_flag -eq 1 ]]; then
    list_length=${#selection_array[@]}
    panes=4
    windows=$((($list_length + panes - 1) / panes)) # Ceiling: 3 subsets (4+4+1)
    window_idx=0
    pos=0

    ssh_new_window() {
      target=$(tmux new-window -n "$1" -P -F '#{session_name}:#{window_index}' ssh $1)
      sleep .5
    }
    ssh_new_pane() {
      tmux split-window -t "$target" -h ssh $1
      sleep .5
    }

    while [[ $window_idx -lt $windows ]]; do
      for ((pos = 0; pos < panes && (window_idx * panes + pos) < list_length; pos++)); do
        idx=$(((window_idx * panes + pos) % list_length)) # Modulo for cycling
        item="${selection_array[$idx]}"
        hostname="${item%% *}"
        if [[ $pos -eq 0 ]]; then
          ssh_new_window $hostname
          continue
        else
          ssh_new_pane $hostname
        fi
      done
      if [[ $list_length == 2 ]]; then
        tmux select-layout -t "$target" even-horizontal
      else
        tmux select-layout -t "$target" tiled
      fi
      ((++window_idx))
    done

  else
    for i in "${selection_array[@]}"; do
      hostname="${i%% *}"
      tmux new-window -n "${hostname}" ssh $hostname
    done
  fi
fi
