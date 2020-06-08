#!/bin/sh

set -eux

cd "$(dirname "$0")"

nix-build '<nixpkgs/nixos>' \
          -I nixos-config=./base.nix \
          -A config.system.build.ipxeBootDir \
          --out-link ./netboot-base

nix-instantiate '<nixpkgs/nixos>' \
          -I nixos-config=./incremental.nix \
          -A config.system.build.ipxeBootDir \
          --add-root ./netboot-incremental.drv --indirect

time nix-build ./netboot-incremental.drv \
     --out-link ./netboot-incremental

ensureSame() (
    test "$(realpath "./netboot-base/$1")" =  "$(realpath "./netboot-incremental/$1")"
)

ensureSame bzImage
ensureSame initrd

echo "ok!"
