# This module creates netboot media containing the given NixOS
# configuration.

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption literalExample;
  netbootpkgs = pkgs.callPackage ./pkgs {};
in

{
  options = {

    netboot.storeContents = mkOption {
      example = literalExample "[ pkgs.stdenv ]";
      description = ''
        This option lists additional derivations to be included in the
        Nix store in the generated netboot image.
      '';
    };

  };

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
    fileSystems."/nix" =
      {
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

      for f in $(rev /nix-store-isos); do
        dest=$(basename "$f" | rev)
        mkdir "/mnt-root/nix/.squash/$dest"
        mount -t squashfs -o loop "$f" "/mnt-root/nix/.squash/$dest"
        (
          cd /mnt-root/nix/store/
          ln -s "../.squash/$dest/$dest" "./$dest"
        )
        set +x
      done
      ls -la /mnt-root/nix/store | grep system-nixos
      ls -la /mnt-root/nix/store/*-nixos-system*/
      ls -la /mnt-root/nix/store/*-nixos-system*/*
      )
    '';

    boot.initrd.availableKernelModules = [ "squashfs" "overlay" ];
    boot.initrd.kernelModules = [ "loop" "overlay" ];

    # Closures to be copied to the Nix store, namely the init
    # script and the top-level system configuration directory.
    netboot.storeContents =
      [ config.system.build.toplevel ];

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = netbootpkgs.makeSquashfsManifest {
      name = "iso-manifeiist";
      storeContents = config.netboot.storeContents;
    };

    # Create the initrd
    system.build.netbootRamdisk = pkgs.makeInitrd {
      inherit (config.boot.initrd) compressor;
      prepend = [
        "${config.system.build.initialRamdisk}/initrd"
        "${(
          netbootpkgs.makeCpioRecursive {
            name = "better-initrd";
            inherit (config.boot.initrd) compressor;
            root = config.system.build.squashfsStore;
          }
        )}/initrd"
      ];

      contents =
        [
          {
            object = pkgs.runCommand "nix-store-isos-reversed" {} ''
              ${pkgs.utillinux}/bin/rev ${config.system.build.squashfsStore} > $out
            '';
            symlink = "/nix-store-isos";
          }
        ];
    };

    system.build.netbootIpxeScript = pkgs.writeTextDir "netboot.ipxe" ''
      #!ipxe
      kernel ${pkgs.stdenv.hostPlatform.platform.kernelTarget} init=${config.system.build.toplevel}/init initrd=initrd ${toString config.boot.kernelParams}
      initrd initrd
      boot
    '';

    system.build.ipxeBootDir = pkgs.symlinkJoin {
      name = "ipxeBootDir";
      paths = [
        config.system.build.netbootRamdisk
        config.system.build.kernel
        config.system.build.netbootIpxeScript
      ];
    };

    boot.loader.timeout = 10;

    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store
        # in the Nix database in the tmpfs.
        ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration

        # nixos-rebuild also requires a "system" profile and an
        # /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';

  };

}
