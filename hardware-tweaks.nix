{ config, pkgs, lib, ... }:

{
  # ════════════════════════════════════════════════
  # Asus Zenbook S 13 OLED (UM5302TA) — Hardware
  # ════════════════════════════════════════════════


  # ──── AMD GPU (Radeon 680M / RDNA 2) ────

  hardware.graphics = {
    enable = true;
    enable32Bit = true;                  # needed for Steam / Wine / 32-bit GL
    extraPackages = with pkgs; [
      amdvlk                             # AMD's open-source Vulkan driver
    ];
  };

  # Set GPU driver at system level
  # (works even with services.xserver.enable = false)
  services.xserver.videoDrivers = [ "amdgpu" ];


  # ──── AMD CPU ────

  hardware.cpu.amd.updateMicrocode = true;

  # amd_pstate=active is set in boot.kernelParams in configuration.nix
  # TLP manages the governor dynamically (performance on AC, powersave on BAT),
  # so we intentionally do NOT set cpuFreqGovernor here to avoid conflicts.
  powerManagement.enable = true;


  # ──── Firmware ────

  # Pull all non-free firmware blobs — critical for the
  # MediaTek MT7922 Wi-Fi/Bluetooth chip and AMD GPU
  hardware.enableAllFirmware = true;


  # ──── Samsung 990 Pro NVMe ────

  # The firmware sleep bug fix is in boot.kernelParams (configuration.nix):
  #   nvme_core.default_ps_max_latency_us=5500
  # TRIM is handled by:
  #   Btrfs mount: discard=async (realtime)
  #   services.fstrim: weekly periodic (belt-and-suspenders)


  # ──── Wi-Fi (MediaTek MT7922 / RZ616) ────

  # mt7921e driver is in-kernel since 5.16 — works out of the box
  # Uncomment if you experience connectivity drops:
  # boot.kernelParams = lib.mkAfter [ "mt7921e.disable_aspm=Y" ];


  # ──── Bluetooth ────

  # Configured in configuration.nix
  # The MT7922 combo chip handles both Wi-Fi and BT


  # ──── Sensors ────

  hardware.sensor.iio.enable = true;     # accelerometer / ambient light sensor


  # ──── Power Management — TLP ────

  services.tlp = {
    enable = true;
    settings = {
      # CPU
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Platform profile (AMD-specific)
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # NVMe — limit aggressive power saving on battery
      # (the kernel param already prevents the worst of the 990 Pro bug,
      # but this provides an additional layer)
      DISK_APM_LEVEL_ON_AC = "254";
      DISK_APM_LEVEL_ON_BAT = "128";

      # Wi-Fi power saving
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # USB autosuspend
      USB_AUTOSUSPEND = 1;

      # Battery charge thresholds (if supported by ASUS firmware)
      # Uncomment and adjust if your Zenbook exposes these via ACPI:
      # START_CHARGE_THRESH_BAT0 = 20;
      # STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Ensure power-profiles-daemon is off (conflicts with TLP)
  services.power-profiles-daemon.enable = false;


  # ──── Lid / Suspend ────

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "suspend";
    extraConfig = ''
      HandlePowerKey=suspend
      IdleAction=suspend
      IdleActionSec=600
    '';
  };


  # ──── Backlight ────

  # brightnessctl is used in keybinds (home.nix) and hypridle.
  # It works via systemd-logind API — no NixOS option needed.
  # Just having the package installed (in home.packages) is sufficient.
}
