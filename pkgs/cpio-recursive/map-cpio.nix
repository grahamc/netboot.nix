{ pathsJson, compressor, pkgs ? import <nixpkgs> {} }:
let
  namePart = strPath:
    let
      last = list: builtins.elemAt list ((builtins.length list) - 1);
      stripPathPrefix = path: last (builtins.split "[/]" path);
    in
      stripPathPrefix "${strPath}";

  paths = builtins.fromJSON (builtins.readFile pathsJson);
  mkcpio = strPath: pkgs.runCommand "${namePart strPath}-cpio" {
    buildInputs = [ pkgs.cpio ];
  } ''
    mkdir root
    cd root
    cp -prd --parents ${builtins.storePath strPath} .
    find . -print0 | xargs -0r touch -h -d '@1'
    find . -print0 \
        | sort -z \
        | cpio -o -H newc -R +0:+1 --reproducible --null \
        | ${compressor} \
      > $out
  '';
in
pkgs.writeText "cpios" (pkgs.lib.concatMapStringsSep "\n" mkcpio paths)
