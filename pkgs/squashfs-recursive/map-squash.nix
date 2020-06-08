{ pathsJson, pkgs ? import <nixpkgs> {} }:
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
    dirname=$(echo "$(basename ${strPath})" | head -c8)
    filename=$(echo "$(basename ${strPath})" | tail -c+9)

    mksquashfs \
      "${builtins.storePath strPath}" \
      ./result \
      -comp gzip -Xcompression-level 9 \
      -keep-as-directory \
      -all-root

    mkdir -p "$out/$dirname"
    mv result "$out/$dirname/$filename"
  '';
in
pkgs.writeText "squashes" (pkgs.lib.concatMapStringsSep "\n" mksquash paths)
