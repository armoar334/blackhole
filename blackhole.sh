#!/usr/bin/env bash
source framework.sh

get_term
setup_term

# Unset values just in case
_core=
_arch=
_disk=
_video=
_locale=
_keymap=
_hostname=
_rootpass=
_timezone=
_username=
_userpass=

main_menu() {
	local running=true
	while $running;
	do
		title1='Select an option to configure'
		list1=('Core' 'Arch' 'Video' 'Disk' 'System' 'User' 'Keymap' 'Exit')
		list2=(
			'Coreutil set (GNU or 9)'
			'Architechture'
			'Video drivers'
			'Partition layout / disks, bootloader, filesystems'
			'Hostname, locale, timezone, rootpassword'
			'User setup: name, password, groups etc'
			'Set keyboard layout'
			'Close without installing'
			)
		dual_select_box
		case "$reply" in
			'Core') core_menu ;;
			'Arch') arch_menu ;;
			'Video') video_menu ;;
			'Disk') true ;;
			'System') system_menu ;;
			'User') true ;;
			'Keymap') true ;;
			'Exit') running=false ;;
		esac
	done
}

core_menu() {
	title1='Select a coreutil set'
	list1=('GNU coreutils' 'plan9port coreutils')
	list2=(
		'Standard GNU coreutils, including non-posix extras such as gawk, bash egrep etc'
		'Plan9 coreutils, including non-posix extras such as rc shell, but missing bash, gawk etc. Not recommended for regular users'
	)
	dual_select_box
	case "$reply" in
		'GNU'*) _core="gnu" ;;
		'plan9'*) _core="9" ;;
	esac
}

arch_menu() {
	title1='Select an architechture'
	list1=('x86_64' 'x86_64-musl' 'i686')
	list2=(
		'64-bit x86: GNU libc'
		'64-bit x86: musl libc'
		'32-bit x86: GNU libc'
	)
	dual_select_box
}

video_menu() {
	title1='Select a graphics driver'
	list1=('Intel' 'AMD' 'noveau' 'Nvidia')
	list2=(
		'Intel graphics drivers'
		'AMD graphics drivers'
		'noveau (open source Nvidia) drivers'
		'Closed source Nvidia drivers'
	)
	dual_select_box
}

system_menu() {
	#locale, timezone
	title1='Enter a hostname'
	text_enter
	title1='Enter a root password'
	cens_enter
}

main_menu

restore_term
echo "$reply"
