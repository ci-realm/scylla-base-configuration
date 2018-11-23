{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.scylla;
  scyllaPath = "/home/rmarko/git/scylla";
  scyllaCI = (import "${scyllaPath}/ci.nix" {});
  scyllaPackage = scyllaCI.scylla;
  scyllaDB = scyllaCI.scyllaDB;
  scyllaNixpkgs = (import "${scyllaPath}/nix/nixpkgs.nix");

  builderPrivKey = "/etc/scylla/id_buildfarm";
in {
  options.services.scylla = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Whether to enable the Scylla server.";
    };

    package = mkOption {
      type = package;
      default = scyllaPackage;
      defaultText = "pkgs.scylla";
      description = "Which Scylla derivation to use.";
    };

    stateDir = mkOption {
      type = path;
      default = "/var/lib/scylla";
      description = "Used to clone and store build results.";
    };

    buildDir = mkOption {
      type = path;
      default = "/var/cache/scylla";
      description = "Temporary directory for clones";
    };

    secretFile = mkOption {
      type = str;
      default = "/var/lib/scylla/secrets.env";
      description = ''
        This is the path to a shell script to source before running the server.
        Use this to export the GITHUB_USER and GITHUB_TOKEN environment variables.
      '';
    };

    builders = mkOption {
      type = attrsOf (listOf str);
      default = {};
      example = { x86_64 = [ "host" ]; };
      apply = x: concatStringsSep " ; " (
        flatten (
          mapAttrsToList (arch: hosts: map (host: "ssh://${host} ${arch}") hosts) x
          #mapAttrsToList (arch: hosts: map (host: "ssh://${host} ${arch} ${builderPrivKey}") hosts) x
        )
      );
    };

    user = mkOption {
      type = str;
      default = "scylla";
      description = "User account under which Scylla runs.";
    };

    dbUser = mkOption {
      type = str;
      default = "scylla";
      description = "Database user account for Scylla.";
    };

    dbPassword = mkOption {
      type = str;
      description = "Database user password for scylla.";
    };

    dbURL = mkOption {
      type = str;
      default = "postgresql://${cfg.dbUser}:${cfg.dbPassword}@localhost/scylla"; # POSSIBLY - ?sslmode=disable
      description = "Database connection URL.";
    };

    bind = mkOption {
      type = nullOr str;
      default = null; # All interfaces
      description = "The IP interface to bind to.";
      example = "127.0.0.1";
    };

    port = mkOption {
      type = int;
      default = 7788;
    };

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether to open ports in the firewall for the server.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    users.users."${cfg.user}" = {
      name = cfg.user;
      home = cfg.buildDir; # nix-instantiate needs to be able to create $HOME/.cache
      description = "Scylla CI user";
    };

    users.groups.scylla = {};

    nix = {
      maxJobs = 0;
      trustedUsers = [ "root" cfg.user ];
      distributedBuilds = true;
      extraOptions = ''
        builders-use-substitutes = true
      '';
    };

    environment.etc = pkgs.lib.singleton {
      target = "scylla/id_buildfarm";
      source = ../static/id_buildfarm;
      user = "scylla";
      group = "scylla";
      mode = "0440";
    };

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql100;
      authentication = ''
        local all scylla md5
      '';
    };

    systemd.services.scylla_init = {
      description = "Scylla server initialization";
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      wantedBy = [ "scylla.service" ];
      before = [ "scylla.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ utillinux scyllaNixpkgs.dbmate ];
      script = ''
        install -d -m0700 -o ${cfg.user} ${cfg.stateDir}
        chown -R ${cfg.user} ${cfg.stateDir}

        if ! [ -e ${cfg.stateDir}/.db-created ]; then
          runuser -u ${config.services.postgresql.superUser} -- ${config.services.postgresql.package}/bin/createuser ${cfg.dbUser}
          runuser -u ${config.services.postgresql.superUser} -- ${config.services.postgresql.package}/bin/createdb ${cfg.dbUser}
          runuser -u ${config.services.postgresql.superUser} -- ${config.services.postgresql.package}/bin/psql -c "ALTER ROLE ${cfg.dbUser} WITH LOGIN PASSWORD '${cfg.dbPassword}';"

          #XXX: sslmode
          DATABASE_URL="${cfg.dbURL}?sslmode=disable" dbmate --migrations-dir ${scyllaDB}/migrations/ --schema-file ${scyllaDB}/schema.sql up
          touch ${cfg.stateDir}/.db-created
        fi
      '';
    };

    systemd.services.scylla = rec {
      description = "Scylla Continuous Integration Service";

      path = with pkgs; [ cfg.package
        openssh nix findutils pixz
        gzip bzip2 lzma gnutar unzip git # gitAndTools.topGit mercurial darcs gnused bazaar
      ];

      environment = {
        PORT = builtins.toString cfg.port;
        HOST = cfg.bind;

        STATE_DIR = cfg.stateDir;
        BUILD_DIR = cfg.buildDir;

        GITHUB_USER = "${builtins.toString cfg.stateDir}/github_user";
        GITHUB_TOKEN = "${builtins.toString cfg.stateDir}/github_token";
        GITHUB_URL = "https://api.github.com";
        DATABASE_URL = cfg.dbURL;
        BUILDERS = "'${cfg.builders}'";
        PRIVATE_SSH_KEY = "test";
      };

      preStart = ''
        source "${cfg.secretFile}"
        echo -n "$GITHUB_USER" > ${environment.GITHUB_USER}
        echo -n "$GITHUB_TOKEN" > ${environment.GITHUB_TOKEN}
      '';

      serviceConfig = {
        Restart = "always";
        RestartSec = 10;
        User = cfg.user;
        ExecStart = "${cfg.package}/bin/scylla";
        WorkingDirectory = "${cfg.package}";
      };

      wantedBy = [ "multi-user.target" ];
      requires = [ "scylla_init.service" ];
      after = [ "scylla_init.service" "network.target" ];
    };

  systemd.tmpfiles.rules = [ "d ${cfg.buildDir} 0755 scylla scylla 10d -" ];
  };
}
