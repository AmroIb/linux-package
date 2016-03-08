#!/bin/sh

set -e

DEVICE="/dev/mmcblk0"
URL="https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz"
PUBKEY="https://www.stdin.xyz/downloads/people/longsleep/longsleep.asc"
CURRENTFILE="/var/lib/misc/pine64_update_uboot.status"

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

if [ ! -b "$DEVICE" ]; then
	echo "Block device ${DEVICE} not found."
	exit 2
fi

TEMP=$(mktemp -d)

cleanup() {
	if [ -d "$TEMP" ]; then
		rm -rf "$TEMP"
	fi
}
trap cleanup EXIT

CURRENT=""
if [ -e "${CURRENTFILE}" ]; then
	CURRENT=$(cat $CURRENTFILE)
fi

echo "Checking for update ..."
ETAG=$(curl -I -H 'If-None-Match: "${CURRENT}' -s "${URL}"|grep ETag|awk -F'"' '{print $2}')

if [ "$ETAG" = "$CURRENT" ]; then
	echo "You are already on the latest version - no update required."
	exit 0
fi

FILENAME=$TEMP/$(basename ${URL})

downloadAndApply() {
	echo "Downloading U-Boot image ..."
	curl "${URL}" --progress-bar --output "${FILENAME}"
	echo "Downloading signature ..."
	curl "${URL}.asc" --progress-bar --output "${FILENAME}.asc"
	echo "Downloading public key ..."
	curl "${PUBKEY}" --progress-bar --output "${TEMP}/pub.asc"

	echo "Verifying signature ..."
	gpg --homedir "${TEMP}" --yes -o "${TEMP}/pub.gpg" --dearmor "${TEMP}/pub.asc"
	gpg --homedir "${TEMP}" --status-fd 1 --no-default-keyring --keyring "${TEMP}/pub.gpg" --trust-model always --verify "${FILENAME}.asc" 2>/dev/null

	local boot0_position=8     # KiB
	local boot0_size=64        # KiB
	local uboot_position=19096 # KiB
	local uboot_size=1384      # KiB
	echo "Processing ..."
	xz -d -c "${FILENAME}" >"${TEMP}/simpleimage.img"
	dd if="${TEMP}/simpleimage.img" status=none bs=1k skip=$boot0_position count=$boot0_size of="${TEMP}/boot0.img"
	dd if="${TEMP}/simpleimage.img" status=none bs=1k skip=$uboot_position count=$uboot_size of="${TEMP}/uboot.img"
	echo "Flashing boot0 ..."
	dd if="${TEMP}/boot0.img" conv=notrunc bs=1k seek=$boot0_position oflag=sync of="${DEVICE}"
	echo "Flashing U-Boot ..."
	dd if="${TEMP}/uboot.img" conv=notrunc bs=1k seek=$uboot_position oflag=sync of="${DEVICE}"
}

if [ "$1" != "--mark-only" ]; then
	downloadAndApply
	echo "Done - you should reboot now."
fi
echo $ETAG > "$CURRENTFILE"