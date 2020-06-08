{ runCommand, nix, jq, path }:
let
  map-squash = ./map-squash.nix;

  mkSquashfsManifest = { name, storeContents }:
    runCommand "${name}-squashfs-manifests" {
      buildInputs = [ nix jq ];
      requiredSystemFeatures = [ "recursive-nix" ];
      exportReferencesGraph = [ "root" storeContents ];
      NIX_PATH = "nixpkgs=${path}";
      outputs = [ "out" "manifest" ];
    } ''
      cat root | grep /nix/store | sort | uniq | jq -R . | jq -s . > paths.json
      nix-build ${map-squash} --arg pathsJson ./paths.json

      touch $out
      for f in $(cat result); do
        find "$f" -type f >> $out
      done

      touch $manifest
      for f in $(cat "$out"); do
        prefix=$(echo "$f" | head -c20)
        suffix=$(echo "$f" | tail -c+21)
        echo "$prefix $suffix" >> $manifest
      done
    '';
in
mkSquashfsManifest
