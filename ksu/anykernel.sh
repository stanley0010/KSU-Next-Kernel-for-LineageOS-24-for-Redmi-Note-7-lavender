### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=SouthWest-NG 0.18.0 + KernelSU-Next (manual hooks) for lavender
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=lavender
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=11-17
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=auto;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
split_boot;
if [ -f $split_img/ramdisk.cpio ]; then
  unpack_ramdisk;
fi;

if [ -f $split_img/ramdisk.cpio ]; then
  repack_ramdisk;
fi;
flash_boot;
# osm0sis AnyKernel3 has no flash_dtbo helper; dtbo is not in this zip.
if type flash_dtbo >/dev/null 2>&1; then
  flash_dtbo;
fi
## end boot install
