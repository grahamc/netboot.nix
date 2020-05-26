{ reverse ? false, pathsJson, pkgs ? import <nixpkgs> {} }:
let
  namePart = strPath:
    let
      nameParts = builtins.tail (builtins.tail (builtins.split "[-]" strPath));
      namePartsWithDashes = (builtins.map (x: if x == [] then "-" else x) nameParts);
    in
      builtins.foldl' (collect: part: "${collect}${part}") "" namePartsWithDashes;

  paths = builtins.fromJSON (builtins.readFile pathsJson);
  mksquash = strPath: pkgs.runCommand "${namePart strPath}-squash" {
    buildInputs = [ pkgs.squashfsTools pkgs.utillinux ];
  } ''
    mkdir $out
    revout=$(echo "$(basename ${strPath})" | rev)
    mksquashfs \
      "${builtins.storePath strPath}" \
      ./result \
      -comp gzip -Xcompression-level 9 \
      -keep-as-directory \
      -all-root

    if ${if reverse then "true" else "false"}; then
      tac result > result.rev
      mv result.rev result
    fi
    mv result "$out/$revout"
  '';
in
pkgs.writeText "squashes" (pkgs.lib.concatMapStringsSep "\n" mksquash paths)
