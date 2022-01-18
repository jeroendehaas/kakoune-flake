{
  description = "Kakoune for home-manager";
  inputs = {
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    kakoune-mirror = { url ="github:delapouite/kakoune-mirror"; flake = false; };
    kakoune-idris2 = { url = "github:jeroendehaas/idris2.kak"; flake = false; };
    kakoune-kaktree = { url = "github:andreyorst/kaktree"; flake = false; };
    kakounecs-dracula = { url = "github:dracula/kakoune"; flake = false; };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: rec {
    overlay = final: prev:
      let lib = inputs.nixpkgs.lib;
          kakounePluginNames = builtins.filter (lib.hasPrefix "kakoune-") (builtins.attrNames inputs);
          kakouneColorschemeNames = builtins.filter (lib.hasPrefix "kakounecs-") (builtins.attrNames inputs);
          buildKakounePlugin = pname: prev.kakouneUtils.buildKakounePlugin {
            inherit pname;
            version = inputs."${pname}".rev;
            src = inputs."${pname}";
          };
          buildKakouneColorscheme = pname: prev.stdenv.mkDerivation {
            inherit pname;
            version = inputs."${pname}".rev;
            src = inputs."${pname}";
            dontBuild = true;
            dontConfigure = true;
            dontPatch = true;

            installPhase = ''
              mkdir -p $out/
              cp $(find . -type f -name '*.kak') $out/
            '';
          };
      in {
        kakounePlugins = prev.kakounePlugins // (lib.genAttrs kakounePluginNames buildKakounePlugin);
        kakouneColorschemes = (lib.genAttrs kakouneColorschemeNames buildKakouneColorscheme);
      };
    hm-kakoune = { lib, config, pkgs, ... }: {
      imports = [ ./kakoune.nix ];
      nixpkgs.overlays = [ overlay ];
    };
  };
}
