#!/bin/bash

device_name="$1"
device_file="$2"
firmware_version="$3"
kernel_version="$4"
bot_token="$5"
post_channel="@nanopi_r2s"
released_date="$(env TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M' | sed 's/ /%20/g')%20%2b0800"

cd "/home/runner"
ls openwrt-* >/dev/null 2>&1 || exit 0

function get_firmware_hash(){
	grep "openwrt-${device_file}-$1-sysupgrade.img.gz" "openwrt-${firmware_version}-sha256sums" | awk -F ' ' '{print $1}' 2>"/dev/null"
}

function transfer_upload(){
	file_name="openwrt-${firmware_version}-${device_file}-$2-sysupgrade.img.gz"
	if [ "$1" == "cow" ]; then
		./transfer "cow" --block "2621440" -s -p "64" -t "180" "${file_name}"
	elif [ "$1" == "wet" ]; then
		./transfer "wet" -s -p "16" -t "180" "${file_name}"
	fi
}

function resolve_download_link(){
	if [ "$1" == "get" ]; then
		grep "Download Link" "$2" | awk -F ': ' '{print $2}' 2>"/dev/null"
	elif [ "$1" == "length" ]; then
		echo -e "$2" | sed "/^\\s*$/d" | wc -l 2>"/dev/null"
	elif [ "$1" == "format" ]; then
		echo -e "$2" | sed "/^\\s*$/d" | sed ':a;N;$!ba;s/\n/%0a/g' 2>"/dev/null"
	fi
}

ext4_image_hash="$(get_firmware_hash "ext4")"
squashfs_image_hash="$(get_firmware_hash "squashfs")"
firmware_sha256sum="EXT4%20Firmware:%0a\`${ext4_image_hash}\`%0aSquashFS%20Firmware:%0a\`${squashfs_image_hash}\`"

curl -sL "https://git.io/file-transfer" | sh
[ ! -f "./transfer" ] && exit 0

transfer_upload "cow" "ext4" > "ext4-transfer_log"
transfer_upload "wet" "ext4" >> "ext4-transfer_log"

transfer_upload "cow" "squashfs" > "squashfs-transfer_log"
transfer_upload "wet" "squashfs" >> "squashfs-transfer_log"

ext4_download_link="$(resolve_download_link "get" "ext4-transfer_log")"
if [ "x$(resolve_download_link "length" "${ext4_download_link}")" == "x0" ]; then
	ext4_download_link=""
else
	ext4_download_link="$(resolve_download_link "format" "${ext4_download_link}")"
fi

squashfs_download_link="$(resolve_download_link "get" "squashfs-transfer_log")"
if [ "x$(resolve_download_link "length" "${squashfs_download_link}")" == "x0" ]; then
	squashfs_download_link=""
else
	squashfs_download_link="$(resolve_download_link "format" "${squashfs_download_link}")"
fi

if [ -z "${ext4_download_link}" ] && [ -z "${wet_download_link}" ]; then
	openwrt_downlink="Failed%20to%20Upload."
elif [ -z "${ext4_download_link}" ]; then
	openwrt_downlink="EXT4 Firmware:%0a${squashfs_download_link}"
elif [ -z "${squashfs_download_link}" ]; then
	openwrt_downlink="SquashFS Firmware:%0a${ext4_download_link}"
else
	openwrt_downlink="EXT4 Firmware:%0a${ext4_download_link}%0aSquashFS Firmware:%0a${squashfs_download_link}"
fi

send_message="*Released%20Date:%20${released_date}*%0a*Device:%20${device_name/ /%20}*%0a*Version:%20${firmware_version}*%0a*Kernel:%20${kernel_version}*%0a%0aSHA256SUM%20Hash%0a${firmware_sha256sum}%0a%0aDownload%20Link%0a${openwrt_downlink}"
curl -s "https://api.telegram.org/bot${bot_token}/sendMessage?chat_id=${post_channel}&text=${send_message}&disable_web_page_preview=true&parse_mode=Markdown" > "/dev/null" 2>&1
