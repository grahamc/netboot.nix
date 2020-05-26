# netboot.nix

Alternative expressions for netboot.

In the future, I'd like to structure this as a module, to easily
turn on recursive Nix builds, or target a ZFS filesystem, etc.

Also, the future should include tests in this repo.

## Included Module Expressions

* `./quickly.nix` uses recursive Nix to build the initrd and squashfs
  filesystems more quickly, allowing for faster iteration of images.
  Initial testing reduced build time from 5-10 minutes per image to
  15-30 seconds.

## Setting up recursive nix

Setting up recursive Nix requires support on the build machine:

```nix
{ pkgs, ... }: {
  nix = {
    package = pkgs.nixUnstable;
    systemFeatures = [ "recursive-nix" "kvm" "nixos-test" ];
    extraOptions = ''
      experimental-features = recursive-nix
    '';
  };
}
```
