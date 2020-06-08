{ pkgs ? import <nixpkgs> {}
, system ? "x86_64-linux"
}:
let
  inherit (pkgs.lib) concatStringsSep mapAttrsToList;
  testlib = import "${pkgs.path}/nixos/lib/testing-python.nix" { inherit system pkgs; };

  pythonDict = params: "\n    {\n        ${concatStringsSep ",\n        " (mapAttrsToList (name: param: "\"${name}\": \"${param}\"") params)},\n    }\n";

  makeNetbootTest = name: extraConfig:
    let
      config = (
        import "${pkgs.path}/nixos/lib/eval-config.nix" {
          inherit system;
          modules = [
            ./quickly.nix
            "${pkgs.path}/nixos/modules/testing/test-instrumentation.nix"
            { key = "serial"; }
          ];
        }
      ).config;

      machineConfig = pythonDict (
        {
          qemuFlags = "-boot order=n -m 4000";
          netBackendArgs = "tftp=${config.system.build.ipxeBootDir},bootfile=netboot.ipxe";
        } // extraConfig
      );
    in
      testlib.makeTest {
        name = "boot-netboot-" + name;
        nodes = {};
        testScript = ''
          machine = create_machine(${machineConfig})
          machine.start()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("nix-collect-garbage")
          machine.succeed("nix-channel --list")
          machine.shutdown()
        '';
      };
in
{
  biosNetboot = makeNetbootTest "bios" {};

  uefiNetboot = makeNetbootTest "uefi" {
    bios = "${pkgs.OVMF.fd}/FV/OVMF.fd";
    # Custom ROM is needed for EFI PXE boot. I failed to understand exactly why, because QEMU should still use iPXE for EFI.
    netFrontendArgs = "romfile=${pkgs.ipxe}/ipxe.efirom";
  };
}
