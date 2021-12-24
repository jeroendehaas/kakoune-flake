{
  description = "Kakoune for home-manager";
  inputs = {
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    kakoune-mirror = { url ="github:delapouite/kakoune-mirror"; flake = false; };
    kakoune-dracula = { url = "github:dracula/kakoune"; flake = false; };
    kakoune-one = { url = "github:raiguard/one.kak"; flake = false; };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: rec {
    overlay = final: prev:
      let lib = inputs.nixpkgs.lib;
          kakounePluginNames = builtins.filter (lib.hasPrefix "kakoune-") (builtins.attrNames inputs);
          buildKakounePlugin = pname: prev.kakouneUtils.buildKakounePlugin {
            inherit pname;
            version = inputs."${pname}".rev;
            src = inputs."${pname}";
          };
      in {
        extraKakounePlugins = lib.genAttrs kakounePluginNames buildKakounePlugin;
      };
    hm-kakoune = { lib, config, pkgs, ... }: {
      imports = [ ./kakoune.nix ];
      nixpkgs.overlays = [ overlay ];
    };
  };
}
