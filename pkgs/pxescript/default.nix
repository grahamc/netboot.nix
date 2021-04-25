{ stdenv, runCommand }:
{ config
, initrds ? {}
, pkgs
,
}:
let
  cmdlineinitrds = builtins.concatStringsSep " " (builtins.map (name: "initrd=${name}") (builtins.attrNames initrds));
in
runCommand "netboot" {
  pxe = ''
    #!ipxe
    kernel ${pkgs.stdenv.hostPlatform.linux-kernel.target} init=${config.system.build.toplevel}/init ${cmdlineinitrds} ${toString config.boot.kernelParams}
    ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: path: "initrd ${name}") initrds))}
    initrd initrd
    boot
  '';
  preferLocalBuild = true;
} ''
  mkdir stage
  cd stage
  ln -s "${config.system.build.kernel}/${pkgs.stdenv.hostPlatform.linux-kernel.target}" ./

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
