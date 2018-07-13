# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

with { inherit (import /home/user/nix-config) latestNixCfg; };
{
  # Include the results of the hardware scan.
  imports = [
    ./hardware-configuration.nix
    "${latestNixCfg}/nixos/modules/laminar.nix"
    "${latestNixCfg}/nixos/modules/nix-daemon-tunnel.nix"
  ];

  nixpkgs.overlays = import "${latestNixCfg}/overlays.nix";

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
    networkmanager.enable = true;
    extraHosts            = with builtins; ''
      ${builtins.trace "FIXME: https://github.com/NixOS/nixpkgs/issues/24683#issuecomment-314631069"
                       "146.185.144.154	lipa.ms.mff.cuni.cz"}
    '';
  };

  hardware = {
    enableAllFirmware             = true;
    enableRedistributableFirmware = true;
  };
  nixpkgs.config.allowUnfree = true; # Needed for firmware

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "uk";
    defaultLocale = "en_GB.UTF-8";
  };

  time.timeZone = "Europe/London";

  environment.sessionVariables.NIX_REMOTE = "daemon";

  environment.systemPackages = with pkgs; [
    autossh networkmanagerapplet screen sshfsFuse trayer usbutils wirelesstools
    wpa_supplicant xterm
  ];

  # Bump up build users
  nix.nrBuildUsers = 50;

  # Don't collect garbage automatically, since it may interfere with benchmarks
  nix.gc.automatic = false;
  #nix.gc.dates     = "daily";
  #nix.gc.options   = "--max-freed ${toString (1024 * 1024 * 1024 * 5)}";

  # We want some parallelism, but setting this too high can exhaust our memory
  # (since we're building memory-intensive things)
  nix.maxJobs = 6;

  # For SSHFS
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  # Services

  services.openssh.enable = true;
  services.openssh.forwardX11 = true;

  # Provides a socket which nixbld users can connect to in lieu of nix-daemon
  services.nix-daemon-tunnel.enable = true;

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
      with {
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
      # Next we disable 'restricted-eval' mode by patching the source
      lib.overrideDerivation fixed (old: {
        patchPhase = ''
          F='src/hydra-eval-jobs/hydra-eval-jobs.cc'
          echo "Patching '$F' to switch off restricted mode" 1>&2
          [[ -f "$F" ]] || {
            echo "File '$F' not found, aborting" 1>&2
            exit 2
          }

          function patterns {
            echo 'settings.set("restrict-eval", "true");'
            echo 'settings.restrictEval = true;'
          }

          PAT=""
          while read -r CANDIDATE
          do
            if grep -F "$CANDIDATE" < "$F" > /dev/null
            then
              PAT="$CANDIDATE"
            fi
          done < <(patterns)

          [[ -n "$PAT" ]] || {
            echo "Couldn't find where restricted mode is enabled, aborting" 1>&2
            exit 3
          }

          NEW=$(echo "$PAT" | sed -e 's/true/false/g')
          sed -e "s/$PAT/$NEW/g" -i "$F"

          while read -r CANDIDATE
          do
            if grep -F "$CANDIDATE" < "$F" > /dev/null
            then
              echo "String '$CANDIDATE' still in '$F', aborting" 1>&2
              exit 4
            fi
          done < <(patterns)
          echo "Restricted mode disabled" 1>&2
        '';
      });
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

  services.cron =
    with pkgs;
    with {
      updateGitRepos = wrap {
        name   = "updateGitRepos";
        paths  = [ bash git ];
        script = ''
          #!/usr/bin/env bash
          set -e
          cd /home/user
          # Avoid laminar-config, since it gets its own cron job
          for R in desktop-scripts isaplanner-tip nix-config warbo-utilities \
                   writing
          do
            pushd "$R" > /dev/null
              git pull --all
            popd > /dev/null
          done
        '';
      };
      updateLaminarCfg = wrap {
        name   = "updateLaminarCfg";
        paths  = [ bash git nix ];
        vars   = withNix {};
        script = ''
          #!/usr/bin/env bash
          set -e
          cd /home/user/laminar-config
          git fetch --all
          if git status 2>&1 | grep 'branch is behind'
          then
            git pull --all
            ./install
          fi
        '';
      };
    };
    {
      enable         = true;
      systemCronJobs = [
        "*/30 * * * *      user    ${updateGitRepos}"
        "*/30 * * * *      user    ${updateLaminarCfg}"
      ];
    };

  # Laminar continuous integration server
  services.laminar = {
    enable   = true;
    bindHttp = "*:4000";  # Default 8080 clashes with IPFS
    cfg      = "/home/user/LaminarCfg";
  };

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

  systemd.services.tunnel = {
    enable        = true;
    description   = "Set up SSH tunnel";
    wantedBy      = [ "default.target"        ];
    after         = [ "network-online.target" ];
    wants         = [ "network-online.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = "user";
      ExecStart = pkgs.writeScript "tunnel.sh" ''
        #!/bin/sh
        export PATH="$PATH:${pkgs.bash}/bin:${pkgs.openssh}/bin:${pkgs.autossh}/bin"
        cd
        while true
        do
          if /run/wrappers/bin/ping -c 1 google.com
          then
            ./tunnel.sh
          fi
          sleep 20
        done
      '';
    };
  };
  systemd.services.tunnel-restart = {
    enable        = true;
    description   = "Monitor SSH tunnel";
    wantedBy      = [ "default.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = "user";
      ExecStart = pkgs.writeScript "tunnel-restart.sh" ''
        #!/bin/sh
        export PATH="$PATH:${pkgs.bash}/bin:${pkgs.openssh}/bin:${pkgs.autossh}/bin"
        KILL=0
        while true
        do
          if [[ "$KILL" -eq 1 ]]
          then
            killall autossh
            sleep 60
          fi
          KILL=0
          if ! /run/wrappers/bin/ping -c 1 google.com
          then
            echo "Not online" 1>&2
            KILL=1
            continue
          fi
          if ssh -A -t -i ~/.ssh/cw_rsa cw sudo lsof -i -n | grep ssh | grep 22222
          then
            true
          else
            echo "No remote tunnel found" 1>&2
            KILL=1
            continue
          fi
          sleep 30
        done
      '';
    };
  };

  # Try to make USB WiFi work automatically
  systemd.services.wifiDongle = {
    enable        = true;
    description   = "Enable WiFi dongle";
    wantedBy      = [ "network.target"     ];
    after         = [ "network-pre.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = "root";
      ExecStart = pkgs.writeScript "wifi-start.sh" ''
        #!/bin/sh
        echo "Enabling WiFi dongle" 1>&2
        "${pkgs.kmod}/bin/modprobe" rt2800usb
        echo 148F 5370 > /sys/bus/usb/drivers/rt2800usb/new_id
        while true; do sleep 60; done
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
