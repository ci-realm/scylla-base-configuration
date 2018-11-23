{ config, pkgs, lib, ... }:
{

  nix = {
    nrBuildUsers = 100;
    buildCores = 0;
    gc = {
      automatic = true;
      dates = "05:15";
      options = ''--max-freed "$((32 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))"'';
    };
  };


  i18n.defaultLocale = "en_US.UTF-8";

  documentation.enable = false;
  services.ntp.enable = false;
  services.openssh.allowSFTP = false;
  services.openssh.passwordAuthentication = false;

  systemd.tmpfiles.rules = [ "d /tmp 1777 root root 7d" ];

  users = {
    mutableUsers = false;
  };

  users.extraUsers.root.openssh.authorizedKeys.keys = lib.singleton ''
    command="nice -n20 nix-store --serve --write" ${pkgs.lib.readFile ../static/id_buildfarm.pub}
  '';

  users.extraGroups = { scylla = { }; };
  users.extraUsers.scylla.uid = 6666;
  users.extraUsers.scylla.group = "scylla";
  users.extraUsers.scylla.openssh.authorizedKeys.keys = lib.singleton ''
    command="nice -n20 nix-store --serve --write" ${pkgs.lib.readFile ../static/id_buildfarm.pub}
  '';
}
