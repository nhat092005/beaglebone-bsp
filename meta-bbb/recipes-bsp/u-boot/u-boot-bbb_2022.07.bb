# U-Boot recipe for BeagleBone Black Custom BSP
#
# Builds U-Boot v2022.07 with am335x_boneblack_custom_defconfig and three
# BSP patches: USB gadget DM_ETH fix + TFTP boot environment + eFuse USB MAC.
#
# Requires OE-Core u-boot include files from poky/meta.

require recipes-bsp/u-boot/u-boot-common.inc
require recipes-bsp/u-boot/u-boot.inc

SUMMARY = "U-Boot for BeagleBone Black Custom BSP"

DEPENDS += "bc-native dtc-native python3-setuptools-native"

FILESEXTRAPATHS:prepend := "${THISDIR}/../../../u-boot/configs:${THISDIR}/files:"

# --- Source ---
# Pin to v2022.07 tag (SHA resolved in Phase 2.1)
SRC_URI = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master"
SRCREV = "e092e3250270a1016c877da7bdd9384f14b1321e"

SRC_URI += " \
    file://am335x_boneblack_custom_defconfig \
    file://0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch \
    file://0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch \
    file://0003-am335x-board-set-usbnet-devaddr-from-efuse.patch \
    file://uEnv.txt \
"

# --- License ---
LIC_FILES_CHKSUM = "file://Licenses/README;md5=2ca5f2c35c8cc335f0a19756634782f1"

# --- Build config ---
UBOOT_MACHINE = "am335x_boneblack_custom_defconfig"

do_configure:prepend() {
	install -d ${S}/configs
	install -m 0644 ${WORKDIR}/am335x_boneblack_custom_defconfig ${S}/configs/
}

do_deploy:append() {
	install -m 0644 ${WORKDIR}/uEnv.txt ${DEPLOYDIR}/uEnv.txt
}
