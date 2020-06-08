# netboot.nix: 15 second netboot iterations

## How to Use

1. set up recursive nix on your builder (see below)
2. add `quickly.nix` to your system's imports, like in
   `./size-test/base.nix`
3. then build your iPXE boot directory:

```
$ nix-build '<nixpkgs/nixos>' -I nixos-config=./size-test/base.nix -A config.system.build.ipxeBootDir
```

4. boot off of `./result/netboot.ipxe`.

The initial build may take a few minutes, but subsequent builds will
only take a few seconds.

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

## How it works
`./quickly.nix` uses recursive Nix to build the initrd and squashfs
filesystems more quickly, allowing for faster iteration of images.
Initial testing reduced build time from 5-10 minutes per image to
15-30 seconds.

The `./size-test/build.sh` test is able to build an incremental
netboot image in just 12 seconds, and the initrd is not rebuilt.
