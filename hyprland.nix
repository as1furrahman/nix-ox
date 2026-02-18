{ config, pkgs, inputs, lib, ... }:

{
  # ════════════════════════════════════════════════
  # Hyprland — System-Level Setup
  # User-level config (keybinds, settings, autostart)
  # is in home.nix via wayland.windowManager.hyprland
  # ════════════════════════════════════════════════


  # ──── Hyprland ────

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };


  # ──── dconf ────
  # Required for GTK apps to read theme settings without a full DE.
  # The Hyprland NixOS module may enable this, but explicit is safer.

  programs.dconf.enable = true;


  # ──── XDG Portals ────
  # xdg-desktop-portal-hyprland is already added by programs.hyprland.enable
  # We only need to add the GTK portal (for file pickers, etc.)

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };


  # ──── Wayland Session Variables ────
  # These are system-wide and need to be set before
  # the user session starts

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    GTK_THEME = "Adwaita:dark";
  };


  # ──── Ambxst ────
  #
  # After first boot:
  #   nix profile add github:Axenide/Ambxst
  #
  # Ambxst is autostarted via exec-once in home.nix
  # Config: ~/.config/Ambxst/
  #
  # Do NOT run dunst/mako alongside Ambxst —
  # it has its own notification daemon.
}
