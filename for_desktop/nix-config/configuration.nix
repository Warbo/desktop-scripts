# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  # Include the results of the hardware scan.
  imports = [ ./hardware-configuration.nix ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub = {
    enable  = true;
    version = 2;

    # Install Grub on HD
    device = "/dev/sda";

    # Chainload Ubuntu
    extraEntries = ''
      menuentry 'Ubuntu' {
        configfile (hd0,1)/grub/grub.cfg
      }
    '';
  };

  # Newer kernel than that of 16.03 seems to be needed for ralink USB WiFi
  #boot.kernelPackages = newPkgs.linuxPackages;

  networking = {
    hostName              = "nixos";
    enableRalinkFirmware  = true;
    networkmanager.enable = true;
    extraHosts            = builtins.trace "FIXME: https://github.com/NixOS/nixpkgs/issues/24683#issuecomment-314631069" ''
      146.185.144.154	lipa.ms.mff.cuni.cz
    '';
  };

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true; # Needed for firmware

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "uk";
    defaultLocale = "en_GB.UTF-8";
  };

  time.timeZone = "Europe/London";

  environment.systemPackages = with pkgs; [
    autossh networkmanagerapplet screen sshfsFuse trayer usbutils wirelesstools wpa_supplicant xterm
  ];

  # Bump up build users
  nix.nrBuildUsers = 50;

  # Routinely collect garbage to prevent disk full
  nix.gc.automatic = true;
  nix.gc.dates     = "daily";
  nix.gc.options   = "--max-freed ${toString (1024 * 1024 * 1024 * 5)}";

  # We want some parallelism, but setting this too high can exhaust our memory (since we're building
  # memory-intensive things)
  nix.maxJobs = 6;

  # For SSHFS
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  # Services

  services.openssh.enable = true;
  services.openssh.forwardX11 = true;

  services.hydra = {
    # Server options; changing port from 3000 doesn't seem to have an effect
    enable     = true;
    listenHost = "localhost";
    port       = 3000;

    # Makes things much faster
    useSubstitutes = true;

    # Not really used
    hydraURL           = "http://hydra.example.org";
    notificationSender = "hydra@example.org";
    extraConfig = "binary_cache_secret_key_file = /etc/nix/hydra.example.org-1/secret";

    # See https://github.com/NixOS/hydra/issues/433#issuecomment-321212080
    buildMachinesFiles = [];

    # Hydra uses Nix's "restricted mode" when evaluating. This prevents certain
    # actions from being taken during evaluation, notably:
    #
    # - Use of the 'fetchTarball' and 'fetchurl' functions from 'builtins'.
    #   These aren't "fixed-output" derivations, so their results aren't checked
    #   against a given hash. We can do without these, as unchecked downloads
    #   are a bad idea anyway.
    # - Access to file paths which aren't in one of the inputs given in a
    #   project's configuration. This is a very severe limitation, since it
    #   means we can't 'import' Nix files that we've fetched or generated
    #   during the evaluation phase. In particular, if some (fixed, checked
    #   version of a) dependency provides Nix code for us to use, we're not
    #   allowed to import it.
    #
    # Whilst these limitations are arguably useful on public-facing servers, or
    # when potentially malicious actors are sending jobs to be built, they're
    # less useful on our local-only instance which we only use to build our own
    # projects.
    #
    # Hence, we patch Hydra to disable restricted mode.
    package =
      with pkgs;
      with rec {
        # Firstly we must fix ParamsValidate, which fails to build on i686
        # https://github.com/NixOS/nixpkgs/pull/32001
        fixed = hydra.override {
          perlPackages = perlPackages.override {
            overrides = {
              ParamsValidate = perlPackages.ParamsValidate.overrideAttrs (old: {
                perlPreHook = "export LD=$CC";
              });
            };
          };
        };
      };
      fixed;
  };

  # Hydra uses postresql
  services.postgresql = {
    package = pkgs.postgresql94;
    dataDir = "/var/db/postgresql-${config.services.postgresql.package.psqlSchema}";
  };

  # Creates Hydra user, DB, etc. if they don't already exist
  #systemd.services.hydra-manual-setup = {
  #  description = "Create Admin User for Hydra";
  #  serviceConfig.Type = "oneshot";
  #  serviceConfig.RemainAfterExit = true;
  #  wantedBy = [ "multi-user.target" ];
  #  requires = [ "hydra-init.service" ];
  #  after = [ "hydra-init.service" ];
  #  environment = config.systemd.services.hydra-init.environment;
  #  script = ''
  #    if [ ! -e ~hydra/.setup-is-complete ]; then
  #      # create admin user
  #      /run/current-system/sw/bin/hydra-create-user alice --full-name 'Alice Q. User' --email-address 'alice@example.org' --password foobar --role admin
  #      # create signing keys
  #      /run/current-system/sw/bin/install -d -m 551 /etc/nix/hydra.example.org-1
  #      /run/current-system/sw/bin/nix-store --generate-binary-cache-key hydra.example.org-1 /etc/nix/hydra.example.org-1/secret /etc/nix/hydra.example.org-1/public
  #      /run/current-system/sw/bin/chown -R hydra:hydra /etc/nix/hydra.example.org-1
  #      /run/current-system/sw/bin/chmod 440 /etc/nix/hydra.example.org-1/secret
  #      /run/current-system/sw/bin/chmod 444 /etc/nix/hydra.example.org-1/public
  #      # done
  #      touch ~hydra/.setup-is-complete
  #    fi
  #  '';
  #};

  # Hydra builds can take down the whole system if we're not careful; mark it for killing
  systemd.services.hydra-queue-runner.serviceConfig.OOMScoreAdjust = "1000";
  systemd.services.hydra-queue-runner.serviceConfig.MemoryMax      = "3G";
  systemd.services.hydra-queue-runner.serviceConfig.MemoryHigh     = "1G";
  systemd.services.hydra-evaluator.serviceConfig.OOMScoreAdjust = "1000";
  systemd.services.hydra-evaluator.serviceConfig.MemoryMax      = "3G";
  systemd.services.hydra-evaluator.serviceConfig.MemoryHigh     = "1G";

  # Also mark nix-daemon for killing, since it manages builds
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = "1000";
  systemd.services.nix-daemon.serviceConfig.MemoryMax      = "3G";
  systemd.services.nix-daemon.serviceConfig.MemoryHigh     = "1G";

  services.xserver = {
    enable = true;
    layout = "gb";
    xkbOptions = "ctrl:nocaps";
    windowManager = {
      default = "xmonad";
      xmonad  = {
        enable  = true;
        enableContribAndExtras = true;
        extraPackages = self: [ self.xmonad-contrib ];
      };
    };

    desktopManager.default = "none";

    displayManager = {
      auto = {
        enable = true;
        user   = "user";
      };
    };
  };

  # Try to make USB WiFi work automatically
  systemd.services.wifiDongle = {
    wantedBy      = [ "network.target"     ];
    after         = [ "network-pre.target" ];
    serviceConfig = {
      Type      = "oneshot";
      User      = "root";
      ExecStart = ''
        modprobe rt2800usb
        echo 148F 5370 > /sys/bus/usb/drivers/rt2800usb/new_id
      '';
    };
  };

  # Define user accounts. Don't forget to set a password with ‘passwd’.
  users.extraUsers = {
    user = {
      isNormalUser = true;
      uid          = 1000;
      home         = "/home/user";
      createHome   = true;
      extraGroups  = [ "wheel" "voice" "networkmanager" "fuse" "dialout" "atd" "docker" ];
      shell        = "/run/current-system/sw/bin/bash";
    };
    soc = {
      isNormalUser = true;
      uid = 1001;
      extraGroups = [ "wheel" ];
    };
  };

  # Hydra-specific users
  #users.users.hydra-www.uid          = config.ids.uids.hydra-www;
  #users.users.hydra-queue-runner.uid = config.ids.uids.hydra-queue-runner;
  #users.users.hydra.uid              = config.ids.uids.hydra;
  #users.groups.hydra.gid             = config.ids.gids.hydra;

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.03";
}
