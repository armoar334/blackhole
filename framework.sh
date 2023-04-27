#!/usr/bin/env bash

# Setup / etc
get_term() {
	read -r lines columns _ < <(stty size)
}

setup_term() {
	old_state=$(stty -g)
	printf '\e[?25l'
	printf '\e[?1049h'
}

restore_term() {
	printf '\e[?1049l'
	printf '\e[?25h'
	stty "$old_state"
}

# Universal functions
draw_box() {
	local topl=$1
	local topc=$2
	local botl=$3
	local botc=$4
	
	printf '\e[%s;%sH' "$topl" "$topc"
	printf '+%*s+' "$(( botc - topc - 1 ))" | tr ' ' '-'
	for i_line in $(seq "$(( topl + 1 ))" "$(( botl - 1 ))");
	do
		printf '\e[%s;%sH|%*s|' "$i_line" "$topc" "$(( botc - topc - 1 ))"
	done
	printf '\e[%s;%sH' "$botl" "$topc"
	printf '+%*s+' "$(( botc - topc - 1 ))" | tr ' ' '-'
}

draw_select_list() {
	local topl=$1
	local topc=$2
	local botl=$3
	local botc=$4
	local current=$5

	local topop=$(( $current - ( botl - topl ) ))
	[[ $topop -le 0 ]] && topop=0
	
	local botop=$(( ( botl - topl ) + topop ))
	[[ $botop -ge ${#list1[@]} ]] && botop=${#list1[@]}

	for i in $( seq $topop $botop )
	do
		printf '\e[%s;%sH' "$(( ( topl + i ) - topop ))" "$topc"
		printf '%s%-*s' "${list1[$i]}" "$(( ( botc - topc ) - ${#list1[$i]}))"
	done

	printf '\e[%s;%sH' "$(( ( topl + current ) - topop ))" "$topc"
	printf '\e[7m%s%-*s\e[0m' "${list1[$current]}" "$(( ( botc - topc ) - ${#list1[$current]}))"
}

draw_multi_list() {
	local topl=$1
	local topc=$2
	local botl=$3
	local botc=$4
	local current=$5

	local topop=$(( $current - ( botl - topl ) ))
	[[ $topop -le 0 ]] && topop=0
	
	local botop=$(( ( botl - topl ) + topop ))
	[[ $botop -ge ${#list1[@]} ]] && botop=${#list1[@]}

	printf '\e[H %s ' $topop
	
	for i in $( seq $topop $botop )
	do
		printf '\e[%s;%sH' "$(( ( topl + i ) - topop ))" "$topc"
		case "${multi_list[$i]}" in
			'true') printf '[x]%s%-*s' "${list1[$i]}" "$(( ( botc - topc ) - ${#list1[$i]} - 3 ))" ;;
			'false') printf '[ ]%s%-*s' "${list1[$i]}" "$(( ( botc - topc ) - ${#list1[$i]} - 3 ))" ;;
		esac
	done
	printf '\e[%s;%sH' "$(( ( topl + current ) - topop ))" "$topc"
	case "${multi_list[$current]}" in
		'true') printf '\e[7m[x]%s%-*s\e[0m' "${list1[$current]}" "$(( ( botc - topc ) - ${#list1[$current]} - 3 ))" ;;
		'false') printf '\e[7m[ ]%s%-*s\e[0m' "${list1[$current]}" "$(( ( botc - topc ) - ${#list1[$current]} - 3 ))" ;;
	esac
}

draw_describe_pane() {
	local topl=$1
	local topc=$2
	local botl=$3
	local botc=$4
	local current=$5
	local line
	
	printf '\e[%s;%sH' "$topl" 1
	while IFS= read -r line; do
		printf '\e[%sC%s\n' "$(( topc - 1 ))" "$line"
	done <<<"$( echo ${list2[$current]} | fold -s -w $(( botc - topc )) )"
}

draw_message() {
	local c_midway=$(( columns / 2 ))
	local l_midway=$(( lines / 2 ))

	draw_box $(( l_midway - 3 )) $(( c_midway - 15 )) $(( l_midway + 3 )) $(( c_midway + 15 ))
	printf '\e[%s;%sH%s\n' $(( l_midway - 3 )) $(( c_midway - 14 )) "$title1"
	while IFS= read -r line; do
		printf '\e[%sC%s\n' "$(( c_midway - 15 ))" "$line"
	done <<<"$( echo ${list1[@]} | fold -s -w 28 )"		
	read -rsn1 _
}

# Single pane selections
select_box() {
	local running=true
	local char
	local current=0
	
	draw_box 1 1 $lines $columns
	printf '\e[1;2H%s' "$title1"

	while $running;
	do
		printf '%s' "$(draw_select_list 2 2 $(( lines - 1 )) $columns $current)"
		IFS= read -rsn1 char
		case "$char" in
			$'\e')
				read -rsn2 char
				case "$char" in
					'[A') (( current -= 1 )) ;;
					'[B') (( current += 1 )) ;;
					'[5') current=0 ;;
					'[6') current="${#list1[@]}" ;;
				esac ;;
			'')
				running=false
				reply="${list1[$current]}" ;;
		esac
 		[[ "$current" -le 0 ]] && current=0
		[[ "$current" -ge "$(( ${#list1[@]} - 1 ))" ]] && current="$(( ${#list1[@]} - 1 ))"
	done
}

multi_select_box() {
	local running=true
	local char
	local current=0

	multi_list=()
	for i in ${list1[@]}
	do
		multi_list+=('false')
	done

	draw_box 1 1 $lines $columns
	printf '\e[1;2H%s' "$title1"

	while $running;
	do
		printf '%s' "$(draw_multi_list 2 2 $(( lines - 1 )) $columns $current)"
		IFS= read -rsn1 char
		case "$char" in
			$'\e')
				read -rsn2 char
				case "$char" in
					'[A') (( current -= 1 )) ;;
					'[B') (( current += 1 )) ;;
					'[5') current=0 ;;
					'[6') current="${#list1[@]}" ;;
				esac ;;
			' ')
				case "${multi_list[$current]}" in
					'true') multi_list[$current]='false' ;;
					'false') multi_list[$current]='true' ;;
				esac ;;
			'')
				running=false
				reply=''
				for i in $(seq 0 $(( ${#list1[@]} - 1 )))
				do
					case "${multi_list[$i]}" in
						'true') reply+="${list1[$i]} " ;;
					esac
				done ;;
		esac
 		[[ "$current" -le 0 ]] && current=0
		[[ "$current" -ge "$(( ${#list1[@]} - 1 ))" ]] && current="$(( ${#list1[@]} - 1 ))"
	done
}

# Dual pane selections

dual_select_box() {
	local running=true
	local char
	local current=0
	local midway=$((columns / 2))

	multi_list=()
	for i in ${list1[@]}
	do
		multi_list+=('false')
	done
	
	draw_box 1 1 $lines $midway
	draw_box 1 $midway $lines $columns
	printf '\e[1;2H%s' "$title1"

	while $running;
	do
		printf '%s' "$(
			draw_select_list 2 2 $(( lines - 1 )) $midway $current
			draw_box 1 $midway $lines $columns
			printf '\e[1;%sH%s' $(( midway + 1 )) $title2
			draw_describe_pane 2 $(( midway + 1 )) $lines $columns $current
		)"
		IFS= read -rsn1 char
		case "$char" in
			$'\e')
				read -rsn2 char
				case "$char" in
					'[A') (( current -= 1 )) ;;
					'[B') (( current += 1 )) ;;
					'[5') current=0 ;;
					'[6') current="${#list1[@]}" ;;
				esac ;;
			'')
				running=false
				reply="${list1[$current]}" ;;
		esac
		[[ "$current" -le 0 ]] && current=0
		[[ "$current" -ge "$(( ${#list1[@]} - 1 ))" ]] && current="$(( ${#list1[@]} - 1 ))"
	done
}

dual_multi_select_box() {
	local running=true
	local char
	local current=0
	local midway=$((columns / 2))
	
	draw_box 1 1 $lines $midway
	draw_box 1 $midway $lines $columns
	printf '\e[1;2H%s' "$title1"

	while $running;
	do
		printf '%s' "$(
			draw_multi_list 2 2 $(( lines - 1 )) $midway $current
			draw_box 1 $midway $lines $columns
			printf '\e[1;%sH%s' $(( midway + 1 )) $title2
			draw_describe_pane 2 $(( midway + 1 )) $lines $columns $current
		)"
		IFS= read -rsn1 char
		case "$char" in
			$'\e')
				read -rsn2 char
				case "$char" in
					'[A') (( current -= 1 )) ;;
					'[B') (( current += 1 )) ;;
					'[5') current=0 ;;
					'[6') current="${#list1[@]}" ;;
				esac ;;
			' ')
				case "${multi_list[$current]}" in
					'true') multi_list[$current]='false' ;;
					'false') multi_list[$current]='true' ;;
				esac ;;
			'')
				running=false
				reply=''
				for i in $(seq 0 $(( ${#list1[@]} - 1 )))
				do
					case "${multi_list[$i]}" in
						'true') reply+="${list1[$i]} " ;;
					esac
				done ;;
		esac
 		[[ "$current" -le 0 ]] && current=0
		[[ "$current" -ge "$(( ${#list1[@]} - 1 ))" ]] && current="$(( ${#list1[@]} - 1 ))"
	done

}

# Text entry
text_enter() {
	local running=true
	local string
	local char
	local c_midway=$(( columns / 2 ))
	local l_midway=$(( lines / 2 ))

	draw_box $(( l_midway - 3 )) $(( c_midway - 15 )) $(( l_midway + 3 )) $(( c_midway + 15 ))
	printf '\e[%s;%sH%s' $(( l_midway - 3 )) $(( c_midway - 14 )) "$title1"
	draw_box $(( l_midway - 1 )) $(( c_midway - 13 )) $(( l_midway + 1 )) $(( c_midway + 13))
	printf '\e[%s;%sH' $l_midway $(( c_midway - 12 ))
	
	printf '\e7'
	while $running;
	do
		IFS= read -rsn1 char
		case "$char" in
			$'\ch'|$'\c?') [[ "${#string}" -gt 0 ]] && string=${string:0:-1} ;;
			'') running=false
				reply="$string" ;;
			*) string="$string$char" ;;
		esac
		printf '\e8%s' "$string "
	done
}

cens_enter() {
	local running=true
	local string
	local char
	local curpos
	local c_midway=$(( columns / 2 ))
	local l_midway=$(( lines / 2 ))

	draw_box $(( l_midway - 3 )) $(( c_midway - 15 )) $(( l_midway + 3 )) $(( c_midway + 15 ))
	printf '\e[%s;%sH%s' $(( l_midway - 3 )) $(( c_midway - 14 )) "$title1"
	draw_box $(( l_midway - 1 )) $(( c_midway - 13 )) $(( l_midway + 1 )) $(( c_midway + 13))
	printf '\e[%s;%sH' $l_midway $(( c_midway - 12 ))
	
	printf '\e7'
	while $running;
	do
		IFS= read -rsn1 char
		case "$char" in
			$'\ch'|$'\c?') [[ "${#string}" -gt 0 ]] && string=${string:0:-1} ;;
			'') running=false
				reply="$string" ;;
			*) string="$string$char" ;;
		esac
		printf '\e8%*s' "${#string}" | tr ' ' '*'
		printf ' '
	done
}

# Variables for lists / textboxes
title1=''
title2=''
list1=()
list2=()

