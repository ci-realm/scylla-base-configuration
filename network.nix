{
  network.description = "scylla base infrastructure";

  scylla =
    { config, lib, pkgs, ... }:
    {
      imports = [
        ./env.nix
        ./machines/scylla.nix
      ];
    };

  builder00 =
    { config, lib, pkgs, ... }:
    {
      imports = [
        ./env.nix
        ./modules/scylla-builder.nix
      ];
    };
}
