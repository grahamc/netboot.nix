{ callPackage }:
{
  # Create a cpio archive comprised of many initrd's appended to
  # each other. Harder to debug, and requires recursive Nix support,
  # but faster for iterating.
  makeCpioRecursive = callPackage ./cpio-recursive {};

  makeSquashfsManifest = callPackage ./squashfs-recursive {};
}
