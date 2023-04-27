#!/usr/bin/env bash
source framework.sh

get_term
setup_term

# Unset values just in case
_core=
_boot=
_root=
_video=
_locale=
_keymap=
_hostname=
_rootpass=
_timezone=
_username=
_userpass=
_usergroups=

main_menu() {
	local running=true
	while $running;
	do
		title1='Select an option to configure'
		list1=('Core' 'Video' 'Disk' 'System' 'User' 'Keymap' 'Finalise' 'Exit')
		list2=(
			'Coreutil set (GNU or 9)'
			'Video drivers'
			'Partition layout / disks, bootloader, filesystems'
			'Hostname, locale, timezone, rootpassword'
			'User setup: name, password, groups etc'
			'Set keyboard layout'
			'Review and Finalise script'
			'Close without installing'
			)
		dual_select_box
		case "$reply" in
			'Core') core_menu ;;
			'Video') video_menu ;;
			'Disk') disk_menu ;;
			'System') system_menu ;;
			'User') user_menu ;;
			'Keymap') keymap_menu ;;
			'Finalise') final_menu ;;
			'Exit') running=false ;;
		esac
	done
}

core_menu() {
	title1='Select a coreutil set'
	list1=('GNU coreutils' 'plan9port coreutils')
	list2=(
		'Standard GNU coreutils, including non-posix extras such as gawk, bash egrep etc'
		'Plan9 coreutils, including non-posix extras such as rc shell, but missing bash, gawk etc. Not recommended for regular users. NOT CURRENTLY FUNCTIONAL'
	)
	dual_select_box
	case "$reply" in
		'GNU'*) _core="gnu" ;;
		'plan9'*) _core="9" ;;
	esac
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
	_video="$reply"
}

disk_menu() {
	local running=true
	while $running;
	do
		title1='Select an option'
		list1=('Cfdisk' 'Select partitons' 'Return')
		list2=(
			'Partition disks using cfdisk'
			'Select the partitions to be used for GRUB and root'
			'Return'
		)
		dual_select_box
		case "$reply" in
			'Cfdisk')
				title1='Select a disk'
				list1=($(lsblk -o NAME | grep -v '^[^[:alnum:]]' | grep -v NAME))
				select_box
				cfdisk "/dev/$reply" ;;
			'Select'*)
				title1='Select a partition for GRUB to be installed'
				list1=($(lsblk -o NAME | grep '^[^[:alnum:]]' | grep -v NAME | sed 's/[^[:alnum:]]//g'))
				select_box
				_boot="$reply"
				title1='Select a root partition'
				select_box
				_root="$reply" ;;
			'Return') running=false ;;
		esac
	done
}

system_menu() {
	#locale, timezone
	title1='Enter a hostname'
	text_enter
	_hostname="$reply"
	title1='Enter a root password'
	cens_enter
	_rootpass="$reply"
	title1='Select a timezone'
	list1=('Africa' 'America' 'Antarctica' 'Arctic' 'Asia' 'Atlantic' 'Australia' 'Europe' 'Indian' 'Pacific')
	select_box
	_timezone="$reply/"
	list1=($(find /usr/share/zoneinfo/$area -type f -printf '%P\n' | sort | grep -F "$_timezone"))
	select_box
	title1='Select a locale'
	list1=($(grep -E '\.UTF-8' /etc/default/libc-locales|awk '{print $1}'|sed -e 's/^#//'))
	selection_box
	_locale="$reply"
}

user_menu() {
	title1='Enter a username'
	text_enter
	_username="$reply"
	title1='Enter a user password'
	cens_enter	
	_userpass="$reply"
	title1='Select groups'
	list1=($(cat /etc/group | cut -d ':' -f 1))
	multi_select_box
	_usergroups="${reply// /,}"
}

keymap_menu() {
	title1='Select a keymap'
	list1=($(find /usr/share/kbd/keymaps/ -type f -iname "*.map.gz" -printf "%f\n" | sed 's|.map.gz||g' | sort))
	select_box
	_keymap="$reply"
}

final_menu() {
	local running
	title1='Review your settings'
	list1=(
		"Core: $_core"
		"Root: $_root"
		"Boot: $_boot"
		"Video driver: $_video"
		"Locale: $_locale"
		"Keymap: $_keymap"
		"Hostname: $_hostname"
		"Timezone: $_timezone"
		"Username: $_username"
		"User groups: $_usergroups"
		"Finish"
		"Go back"
	)
	while $running;
	do
		select_box
		case "$reply" in
			'Finish')
				running=false
				build_script ;;
			'Go back') running=false ;;
		esac
	done
}

build_script() {
	# Host side
	clear
	mkfs.vfat /dev/$_boot
	mkfs.ext4 /dev/$_root
	mount /dev/$_root /mnt/
	mkdir -p /mnt/boot/efi/
	mount /dev/$_boot /mnt/boot/efi/
	REPO=https://repo-default.voidlinux.org/current
	ARCH=x86_64
	mkdir -p /mnt/var/db/xbps/keys
	cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
	XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" base-system
	mount -t proc none /mnt/proc
	mount -t sysfs none /mnt/sys
	mount --rbind /dev /mnt/dev
	mount --rbind /run /mnt/run

	# Chroot
	cat <<-EOF | chroot /mnt
	echo "$_hostname" > /etc/hostname
	sed -e "s/^KEYMAP=.*/KEYMAP=$_keymap/g" -i /etc/rc.conf
	echo "$_locale" >> /etc/default/libc-locales
	echo "$_rootpass" | chpasswd
	uuid=$(ls -l /dev/disk/by-uuid/ | grep $(basename $_boot) |awk '{print $9}')
	echo "UUID=$uuid /boot/efi vfat defaults 0 2" >> /etc/fstab
	uuid=$(ls -l /dev/disk/by-uuid/ | grep $(basename $_root) |awk '{print $9}')
	echo "UUID=$uuid /boot/efi vfat defaults 0 1" >> /etc/fstab
	echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> /etc/fstab
	xbps-install grub-x86_64-efi xtools
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
	xbps-reconfigure -fa
	EOF
	umount -R /mnt
}


main_menu

restore_term
echo "$reply"
 
