{ config, pkgs, inputs, lib, ... }:

{
  # ──────────────────────────────────────────────
  # System
  # ──────────────────────────────────────────────

  system.stateVersion = "24.11";
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # ──────────────────────────────────────────────
  # Boot — GRUB + latest kernel
  # ──────────────────────────────────────────────

  boot = {
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = false;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      "amd_pstate=active"
      "nvme_core.default_ps_max_latency_us=5500"
      "nowatchdog"
      "resume=/dev/nvme0n1p2"         # hibernate resume from swap partition
    ];

    # Hibernate resume
    resumeDevice = "/dev/nvme0n1p2";

    initrd.kernelModules = [ "amdgpu" ];
  };

  # ──────────────────────────────────────────────
  # Networking
  # ──────────────────────────────────────────────

  networking = {
    hostName = "zenbook";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  # ──────────────────────────────────────────────
  # Locale & Time
  # ──────────────────────────────────────────────

  time.timeZone = "Asia/Dhaka";
  i18n.defaultLocale = "en_US.UTF-8";

  # ──────────────────────────────────────────────
  # Display Manager — greetd + tuigreet
  # ──────────────────────────────────────────────
  # Minimal TUI greeter — no X11 dependency, native Wayland.
  # initial_session auto-logs in on first boot (skips password);
  # default_session (tuigreet) appears on subsequent logins / logout.

  services.xserver.enable = false;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "Hyprland";
        user = "asif";
      };
      default_session = {
        command = ''
          ${pkgs.greetd.tuigreet}/bin/tuigreet \
            --time \
            --asterisks \
            --remember \
            --remember-session \
            --cmd Hyprland
        '';
        user = "greeter";
      };
    };
  };

  # Suppress greetd's own TTY output from cluttering the login screen
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # ──────────────────────────────────────────────
  # User
  # ──────────────────────────────────────────────

  users.users.asif = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "bluetooth"
      "input"
    ];
    initialPassword = "changeme";
  };

  # ──────────────────────────────────────────────
  # Audio — PipeWire
  # ──────────────────────────────────────────────

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ──────────────────────────────────────────────
  # Bluetooth
  # ──────────────────────────────────────────────

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;

  # ──────────────────────────────────────────────
  # Essential Services
  # ──────────────────────────────────────────────

  services.dbus.enable = true;
  security.polkit.enable = true;
  services.fwupd.enable = true;
  services.upower.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.fstrim.enable = true;

  # ──────────────────────────────────────────────
  # zram — Compressed RAM swap
  # ──────────────────────────────────────────────

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;            # 50% of 16 GB = 8 GB compressed swap in RAM
  };

  # ──────────────────────────────────────────────
  # Btrfs Maintenance
  # ──────────────────────────────────────────────

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };

  # ──────────────────────────────────────────────
  # Snapper — Btrfs Snapshots
  # ──────────────────────────────────────────────

  services.snapper = {
    snapshotRootOnBoot = true;
    configs = {
      root = {
        SUBVOLUME = "/";
        ALLOW_USERS = [ "asif" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "10";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY = "0";
      };
      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ "asif" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "10";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY = "0";
      };
    };
  };

  # ──────────────────────────────────────────────
  # Fonts
  # ──────────────────────────────────────────────

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      font-awesome
      material-design-icons
      inter
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.meslo-lg
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Inter" ];
      serif = [ "Noto Serif" ];
    };
  };

  # ──────────────────────────────────────────────
  # System Packages (system-level only)
  # User packages are managed in home.nix
  # ──────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    vim
    nano
    wget
    curl
    git

    # Filesystem & hardware (need root or system-level access)
    btrfs-progs
    compsize
    snapper
    smartmontools
    pciutils
    usbutils
    lm_sensors

    # Terminal (system-wide fallback)
    ghostty
  ];

  # ──────────────────────────────────────────────
  # Programs
  # ──────────────────────────────────────────────

  programs.gnupg.agent.enable = true;
}
