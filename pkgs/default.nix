{ callPackage }:
{
  makeCpioRecursive = callPackage ./cpio-recursive {};
  makeSquashfsManifest = callPackage ./squashfs-recursive {};
}
