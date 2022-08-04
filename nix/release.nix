let
  pkgs = import ./packages.nix {};
in
  { astrochart = pkgs.haskellPackages.astrochart; }
