{ config, lib, pkgs, ... }:
{
  imports = [
    ../modules/scylla.nix
  ];

  services.scylla = {
    enable = true;
    openFirewall = true;
    dbPassword = "muchSecret";
    builders = {
      x86_64 = [
        "builder00"
      ];
    };
  };

  nix.buildMachines =  [
    { hostName = "builder00";
     maxJobs = 2;
     speedFactor = 1;
     sshKey = "/etc/scylla/id_buildfarm";
     sshUser = "root";
     system = "x86_64-linux";
     supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
    }
      /*
          { hostName = "panzer1";
            maxJobs = 2;
            speedFactor = 1;
            sshKey = "/etc/nix/id_buildfarm";
            sshUser = "root";
            system = "x86_64-linux";
            supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
          }
          { hostName = "panzer2";
            maxJobs = 2;
            speedFactor = 1;
            sshKey = "/etc/nix/id_buildfarm";
            sshUser = "root";
            system = "x86_64-linux";
            supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
          }
          { hostName = "nvn";
            maxJobs = 1;
            speedFactor = 1;
            sshKey = "/etc/nix/id_buildfarm";
            sshUser = "root";
            system = "armv7l-linux";
            supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
          }
        */
  ];


  programs.ssh.extraConfig = lib.mkAfter
    ''
      ServerAliveInterval 120
      TCPKeepAlive yes
      Compression yes

      Host *
        User root
        IdentityFile /etc/scylla/id_buildfarm

      Host builder00
        Hostname 172.17.66.10

      Host panzer1
        Hostname 172.17.6.241

      Host panzer2
        Hostname 172.17.6.242

      # arm
      Host nvn
        Hostname 172.17.1.250
    '';
  services.openssh.knownHosts =
    [
      # virt
      { hostNames = [ "172.17.66.10" ]; publicKey = lib.fileContents ../static/builder00/hostkey.pub; }

      # phys
      { hostNames = [ "172.17.6.241" ]; publicKey = lib.fileContents ../static/panzer1/hostkey.pub; }
      { hostNames = [ "172.17.6.242" ]; publicKey = lib.fileContents ../static/panzer2/hostkey.pub; }
      # phys/arm
      { hostNames = [ "172.17.1.250" ]; publicKey = lib.fileContents ../static/nvn/hostkey.pub; }
    ];


  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ "10.100.0.2/24" ];

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/root/wireguard-keys/private";

      peers = [
        # For a client configuration, one peer entry for the server will suffice.
        {
          # Public key of the server (not a file path).
          publicKey = "jzHK9nCUQ7lNiphj6s9zYisk4b/9TLDLJ0izi17pXT0=";

          # Forward all the traffic via VPN.
          #allowedIPs = [ "0.0.0.0/0" ];
          # Or forward only particular subnets
          allowedIPs = [ "10.100.0.1" ];

          # Set this to the server IP and port.
          endpoint = "ci.48.io:45666";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
