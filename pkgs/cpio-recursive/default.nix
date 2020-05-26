{ runCommand, nix, jq, path }:
let
  map-cpio = ./map-cpio.nix;

  makeCpioRecursive = { name, root, prepend ? [], compressor }:
    runCommand "${name}-initrd" {
      buildInputs = [ nix jq ];
      requiredSystemFeatures = [ "recursive-nix" ];
      exportReferencesGraph = [ "root" root ];
      NIX_PATH = "nixpkgs=${path}";
      inherit prepend compressor;
    } ''

    cat root | grep /nix/store | sort | uniq | jq -R . | jq -s . > paths.json
    nix-build ${map-cpio} --arg pathsJson ./paths.json --argstr compressor "$compressor"

    touch initrd
    for pre in $prepend; do
      cat "$pre" >> initrd
    done

    cat result | xargs cat >> initrd
    mkdir $out
    mv initrd $out/initrd
  '';
in
makeCpioRecursive
