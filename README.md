# My kakoune config as a flake for home-manager

This flake offers two outputs:

1. `overlay`: an overlay for `nixpkgs` that adds an attribute set `extraKakounePlugins` of derivations ready to use as kakoune plugins.
2. `hm-kakoune`: my kakoune config. This attribute can be placed in an `imports` list.

