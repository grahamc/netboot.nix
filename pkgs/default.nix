{ callPackage, nixUnstable }:
{
  # Create a cpio archive comprised of many initrd's appended to
  # each other. Harder to debug, and requires recursive Nix support,
  # but faster for iterating.
  makeCpioRecursive = callPackage ./cpio-recursive {
    # nixUnstable may not be required. Todo: revisit (2020-05-25)
    nix = nixUnstable;
  };

  makePxeScript = callPackage ./pxescript {};

  makeSquashfsManifest = callPackage ./squashfs-recursive {
    # nixUnstable may not be required. Todo: revisit (2020-05-25)
    nix = nixUnstable;
  };
}
