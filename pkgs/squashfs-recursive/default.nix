{ runCommand, nix, jq, path }:
let
  map-squash = ./map-squash.nix;

  mkSquashfsManifest = { name, storeContents, reverse ? false }:
    runCommand "${name}-squashfs-manifest" {
      buildInputs = [ nix jq ];
      requiredSystemFeatures = [ "recursive-nix" ];
      exportReferencesGraph = [ "root" storeContents ];
      NIX_PATH = "nixpkgs=${path}";
    } ''
      cat root | grep /nix/store | sort | uniq | jq -R . | jq -s . > paths.json
      nix-build ${map-squash} --arg pathsJson ./paths.json --arg reverse ${if reverse then "true" else "false"}

      touch $out
      for f in $(cat result); do
        find "$f" -type f >> $out
      done
    '';
in
mkSquashfsManifest
