#!/bin/bash

set -x

# cd to its configfs node
cd /sys/kernel/config/usb_gadget
echo > g1/UDC
rm g1/configs/c.1/ecm.0
rmdir g1/configs/*
rmdir g1/functions/*
rmdir g1/strings/*
rmdir g1

