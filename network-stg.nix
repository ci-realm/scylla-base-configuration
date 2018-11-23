{
  scylla =
    { config, lib, pkgs, ... }:
    {
      imports = [
        ./ct.nix
      ];

      # ci/scylla
      deployment.targetHost = "172.17.166.1";
      deployment.targetEnv = "dumb";
    };

  builder00 =
    { config, lib, pkgs, ... }:
    {
      imports = [
        ./ct.nix
      ];

      # devnode1/builder00
      deployment.targetHost = "172.17.66.10";
      deployment.targetEnv = "dumb";
    };
}
