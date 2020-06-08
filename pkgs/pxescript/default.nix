{ stdenv, runCommand }:
{ config
, initrds ? {}
, pkgs
,
}:
runCommand "netboot" {
  pxe = ''
    #!ipxe
    kernel ${pkgs.stdenv.hostPlatform.platform.kernelTarget} init=${config.system.build.toplevel}/init initrd=initrd ${toString config.boot.kernelParams}
    ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: path: "initrd ${name}") initrds))}
    initrd initrd
    boot
  '';
} ''
  mkdir stage
  cd stage
  ln -s "${config.system.build.kernel}/${pkgs.stdenv.hostPlatform.platform.kernelTarget}" ./

  set -x
  ${builtins.concatStringsSep "\n"
  (
    builtins.attrValues
      (
        builtins.mapAttrs
          (
            name: path: ''
              test -f "$(realpath "${path}")"
              ln -s ${path} ./${name}
            ''
          ) initrds
      )
  )}
  set +x
  echo "$pxe" > netboot.ipxe

  cd ..
  mv stage $out
''
