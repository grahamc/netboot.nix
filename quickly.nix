# This module creates netboot media containing the given NixOS
# configuration.

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption literalExample;
  netbootpkgs = pkgs.callPackage ./pkgs {};
in

{
  config = {
    # Don't build the GRUB menu builder script, since we don't need it
    # here and it causes a cyclic dependency.
    boot.loader.grub.enable = false;

    # make testing faster
    boot.initrd.compressor = "gzip -9n";

    # !!! Hack - attributes expected by other modules.
    environment.systemPackages = [ pkgs.grub2_efi ]
    ++ (
      if pkgs.stdenv.hostPlatform.system == "aarch64-linux"
      then []
      else [ pkgs.grub2 pkgs.syslinux ]
    );

    fileSystems."/" =
      {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

    # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
    # image) to make this a live CD.
    fileSystems."/nix" = {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };

    boot.initrd.postMountCommands = ''
      echo "Mounting initial store"
      (
      set -eux
      mkdir -p /mnt-root/nix/.squash
      mkdir -p /mnt-root/nix/store

      gunzip < /nix-store-squashes/registration.gz > /mnt-root/nix/registration

      # the manifest splits the /nix/store/.... path with a " " to
      # prevent Nix from determining it depends on things.
      for f in $(cat /nix-store-squashes/squashes | sed 's/ //'); do
        prefix=$(basename "$(dirname "$f")")
        suffix=$(basename "$f")
        dest="$prefix$suffix"
        mkdir "/mnt-root/nix/.squash/$dest"
        mount -t squashfs -o loop "$f" "/mnt-root/nix/.squash/$dest"
        (
          cd /mnt-root/nix/store/
          cp -ar "../.squash/$dest/$dest" "./$dest"
        )
        umount "/mnt-root/nix/.squash/$dest"
        rm "$f"
        set +x
      done
      )
    '';

    boot.initrd.availableKernelModules = [ "squashfs" "overlay" ];
    boot.initrd.kernelModules = [ "loop" "overlay" ];


    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = netbootpkgs.makeSquashfsManifest {
      name = "iso-manifest";
      storeContents = config.system.build.toplevel;
    };

    system.build.ipxeBootDir = netbootpkgs.makePxeScript {
      inherit config pkgs;
      initrds = {
        initrd = "${config.system.build.initialRamdisk}/initrd";

        # squashfsStore is just a manifest file, and makeCpioRecursive
        # will bring in all its dependencies automatically.
        # the nix-store initrd is the actual files, and the manifest
        # is intentionally only just the manifest file, located
        # at /nix-store-isos
        nix-store = "${(
          netbootpkgs.makeCpioRecursive {
            name = "better-initrd";
            inherit (config.boot.initrd) compressor;
            root = config.system.build.squashfsStore;
          }
        )}/initrd";
        manifest = "${pkgs.makeInitrd {
          inherit (config.boot.initrd) compressor;
          contents =
            [
              {
                object = config.system.build.squashfsStore.manifest;
                symlink = "/nix-store-squashes";
              }
            ];
        }}/initrd";
      };
    };

    boot.loader.timeout = 10;

    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store
        # in the Nix database in the tmpfs.
        echo "Loading the Nix database"
        ${config.nix.package}/bin/nix-store --load-db < /nix/registration

        # nixos-rebuild also requires a "system" profile and an
        # /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';

  };

}
