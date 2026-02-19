{ config, pkgs, lib, inputs, ... }:

{
  home = {
    username = "asif";
    homeDirectory = "/home/asif";
    stateVersion = "24.11";
  };

  # Allow unfree packages in user-level nix commands (nix shell, nix profile, etc.)
  # System-level allowUnfree is in configuration.nix — this covers the user side.
  nixpkgs.config.allowUnfree = true;

  # Env var for ad-hoc nix CLI commands (nix shell, nix run, nix profile add)
  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  programs.home-manager.enable = true;

  # ──────────────────────────────────────────────
  # User Packages
  # ──────────────────────────────────────────────

  home.packages = with pkgs; [
    # CLI tools
    ripgrep
    fd
    eza
    bat
    tree
    jq
    unzip
    zip
    file
    htop
    btop
    fish

    # Media
    ffmpeg
    mpv

    # Screenshots / screen recording
    grim
    slurp
    swappy
    wf-recorder

    # Wayland utilities
    wl-clipboard
    wl-clip-persist
    cliphist
    brightnessctl
    pamixer
    playerctl
    libnotify

    # Ambxst feature dependencies
    tesseract
    zbar
    hyprpicker

    # Hyprland ecosystem
    hyprpaper
    hyprlock

    # Audio
    pavucontrol
    easyeffects

    # File manager
    thunar
    thunar-volman                    # auto-mount removable drives
    thunar-archive-plugin            # right-click extract/compress
    tumbler                          # thumbnail previews (images, videos, PDFs)

    # Networking GUI
    networkmanagerapplet

    # Theming
    nwg-look
    bibata-cursors
    adwaita-icon-theme
    adwaita-icon-theme-legacy        # FDO-compliant icons for non-GNOME apps (Thunar, etc.)

    # Development
    gcc
    gnumake

    # Qt runtime (Ambxst / Quickshell)
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland

    # Polkit agent (fallback — Ambxst has built-in)
    polkit_gnome
  ];

  # ──────────────────────────────────────────────
  # Git
  # ──────────────────────────────────────────────

  programs.git = {
    enable = true;
    settings = {
      user.name = "Asif";            # adjust
      user.email = "asif@email.com"; # adjust
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "vim";
    };
  };

  # ──────────────────────────────────────────────
  # Shell — Bash
  # ──────────────────────────────────────────────

  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ls = "eza --icons";
      ll = "eza -la --icons";
      lt = "eza --tree --icons --level=2";
      cat = "bat";
      grep = "rg";
      find = "fd";
      ".." = "cd ..";
      "..." = "cd ../..";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#zenbook";
      rebuild-test = "sudo nixos-rebuild test --flake ~/nixos-config#zenbook";
      update = "cd ~/nixos-config && sudo nix flake update && sudo nixos-rebuild switch --flake .#zenbook";
      gc = "sudo nix-collect-garbage -d";
    };
  };

  # ──────────────────────────────────────────────
  # Terminal — Ghostty
  # ──────────────────────────────────────────────

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 12
    theme = dark:catppuccin-mocha,light:catppuccin-latte

    window-decoration = false
    window-padding-x = 8
    window-padding-y = 8

    gtk-titlebar = false
    confirm-close-surface = false

    copy-on-select = clipboard
    cursor-style = block
    cursor-style-blink = true

    window-inherit-working-directory = true
  '';

  # ──────────────────────────────────────────────
  # Cursor & GTK Theme
  # ──────────────────────────────────────────────

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  # libadwaita (GTK4) apps read dark mode from dconf, not GTK settings files
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # ──────────────────────────────────────────────
  # XDG Directories
  # ──────────────────────────────────────────────

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };
    mimeApps.enable = true;
  };

  # ══════════════════════════════════════════════
  #
  #   HYPRLAND — Axenide-style, OLED-optimized
  #
  # ══════════════════════════════════════════════

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;

    # Use the Hyprland package from the NixOS module (programs.hyprland)
    # to avoid version mismatch between system and user installs.
    # See: https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/
    package = null;
    portalPackage = null;

    settings = {

      # ────────────────────────────────────────
      # Monitor
      # ────────────────────────────────────────
      # 2880×1800 OLED, scale 1.333 for larger UI
      monitor = [ "eDP-1, 2880x1800@60, 0x0, 1.333333" ];


      # ────────────────────────────────────────
      # Environment
      # ────────────────────────────────────────
      env = [
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Bibata-Modern-Ice"
      ];


      # ────────────────────────────────────────
      # Autostart
      # ────────────────────────────────────────
      # Ambxst is the sole shell — handles launcher, notifications,
      # clipboard, power menu, media controls, Wi-Fi/BT, and more.
      exec-once = [
        "ambxst"
        "wl-paste --type text  --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "wl-clip-persist --clipboard regular"
      ];


      # ────────────────────────────────────────
      # Input
      # ────────────────────────────────────────
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        accel_profile = "adaptive";

        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          drag_lock = true;
          disable_while_typing = true;
          scroll_factor = "0.3";
        };
      };

      gestures = {
        # ── New gesture system (Hyprland ≥0.51) ──
        # Replaces the removed workspace_swipe / workspace_swipe_fingers options.
        gesture = [
          "3, horizontal, workspace"   # 3-finger horizontal swipe → switch workspace
        ];

        workspace_swipe_distance = 300;
        workspace_swipe_cancel_ratio = "0.2";
        workspace_swipe_min_speed_to_force = 5;
        workspace_swipe_direction_lock = true;
        workspace_swipe_direction_lock_threshold = 10;
        workspace_swipe_create_new = false;
      };


      # ────────────────────────────────────────
      # General
      # ────────────────────────────────────────
      general = {
        gaps_in = 6;
        gaps_out = 14;
        border_size = 3;

        # Warm neutral baseline — Ambxst overrides via IPC on launch.
        # Two-color gradient rotates via borderangle animation (see animations block).
        "col.active_border" = "rgba(d4a556ee) rgba(c78a6ecc) 45deg";
        "col.inactive_border" = "rgba(2a2a2a40)";

        layout = "dwindle";          # default; switchable to master via keybind
        allow_tearing = false;
      };


      # ────────────────────────────────────────
      # Decoration — all effects enabled
      # ────────────────────────────────────────
      decoration = {
        rounding = 14;

        # Blur — frosted glass for Ambxst popups and transparent windows
        blur = {
          enabled = true;
          size = 8;
          passes = 4;
          new_optimizations = true;
          xray = false;
          noise = "0.015";
          contrast = "0.9";
          brightness = "0.75";
          vibrancy = "0.2";
          vibrancy_darkness = "0.1";
          popups = true;
          popups_ignorealpha = "0.5";
        };

        # Shadows — wide & soft for OLED depth (true-black swallows hard shadows)
        shadow = {
          enabled = true;
          range = 22;
          render_power = 2;
          color = "rgba(00000088)";
          color_inactive = "rgba(00000044)";
          offset = "0 4";
          scale = "0.98";
        };

        # Dim inactive windows
        dim_inactive = true;
        dim_strength = "0.15";
      };


      # ────────────────────────────────────────
      # Animations — Polished & responsive
      # Snappy workspace switches, fluid window transitions,
      # smooth fades. Designed to complement Ambxst's own animations.
      # ────────────────────────────────────────
      animations = {
        enabled = true;

        bezier = [
          # Snappy — quick attack, firm landing (workspaces, layout switches)
          "snappy, 0.25, 1.0, 0.5, 1.0"

          # Fluid — gentle overshoot for organic feel (window open/move)
          "fluid, 0.05, 0.9, 0.1, 1.05"

          # Soft spring — subtle bounce (window in, special workspace)
          "spring, 0.1, 0.8, 0.2, 1.08"

          # Clean ease-out — no overshoot (fades, borders, dim)
          "ease, 0.25, 0.1, 0.25, 1.0"

          # Exit — quick pull-back (window close, fade out)
          "exit, 0.36, 0, 0.66, -0.56"
        ];

        animation = [
          # Windows — fluid open, spring-in, quick exit
          "windows, 1, 4, fluid, slide"
          "windowsIn, 1, 4, spring, slide"
          "windowsOut, 1, 3, exit, popin 80%"
          "windowsMove, 1, 3, snappy"

          # Fades — clean and quick
          "fade, 1, 3, ease"
          "fadeIn, 1, 3, ease"
          "fadeOut, 1, 2, ease"
          "fadeSwitch, 1, 3, ease"
          "fadeShadow, 1, 4, ease"
          "fadeDim, 1, 3, ease"

          # Borders — smooth gradient rotation
          "border, 1, 8, ease"
          "borderangle, 1, 40, ease, loop"

          # Workspaces — snappy, responsive slide
          "workspaces, 1, 4, snappy, slide"
          "specialWorkspace, 1, 4, spring, slidevert"
        ];
      };


      # ────────────────────────────────────────
      # Layouts — Dwindle (default) + Master
      # ────────────────────────────────────────
      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2;
        smart_split = false;
        smart_resizing = true;
        no_gaps_when_only = 0;       # keep gaps even with one window
      };

      master = {
        new_status = "slave";
        mfact = "0.55";
        orientation = "left";
        smart_resizing = true;
        no_gaps_when_only = 0;
      };


      # ────────────────────────────────────────
      # Misc — OLED-critical
      # ────────────────────────────────────────
      misc = {
        vfr = true;                  # variable frame rate — reduces static pixel time on OLED
        vrr = 0;                     # VRR off (60 Hz fixed panel)
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        new_window_takes_over_fullscreen = 2;
        focus_on_activate = true;
      };


      # ────────────────────────────────────────
      # Cursor
      # ────────────────────────────────────────
      cursor = {
        no_hardware_cursors = true;  # AMD iGPU fix
      };


      # ────────────────────────────────────────
      # Window Rules
      # ────────────────────────────────────────
      windowrulev2 = [
        # Float utility windows
        "float, class:^(pavucontrol)$"
        "float, class:^(blueman-manager)$"
        "float, class:^(nm-connection-editor)$"
        "float, class:^(easyeffects)$"
        "float, class:^(nwg-look)$"
        "float, class:^(polkit-gnome-authentication-agent-1)$"
        "float, title:^(Picture-in-Picture)$"
        "float, class:^(thunar)$,title:^(File Operation Progress)$"

        # Center floating utility windows
        "center, class:^(pavucontrol)$"
        "center, class:^(blueman-manager)$"
        "center, class:^(nm-connection-editor)$"
        "center, class:^(easyeffects)$"
        "center, class:^(polkit-gnome-authentication-agent-1)$"

        # Size constraints for utility windows
        "size 800 550, class:^(pavucontrol)$"
        "size 700 500, class:^(blueman-manager)$"

        # Opacity rules
        "opacity 0.95 0.88, class:^(ghostty)$"
        "opacity 0.95 0.88, class:^(thunar)$"
        "opacity 0.95 0.90, class:^(firefox)$"

        # Force opaque for media / GPU-heavy apps
        "opaque, class:^(mpv)$"
        "opaque, class:^(.*exe.*)$"
        "opaque, class:^(.*wine.*)$"
        "opaque, title:^(.*YouTube.*)$"

        # No blur on fullscreen (performance)
        "noblur, fullscreen:1"

        # Pin PiP
        "pin, title:^(Picture-in-Picture)$"
        "size 480 270, title:^(Picture-in-Picture)$"
        "move 100%-490 100%-280, title:^(Picture-in-Picture)$"

        # Suppress maximize events (apps like Firefox send these)
        "suppressevent maximize, class:.*"

        # File dialogs — float and center
        "float, title:^(Open File)(.*)$"
        "float, title:^(Select a File)(.*)$"
        "float, title:^(Choose wallpaper)(.*)$"
        "float, title:^(Open Folder)(.*)$"
        "float, title:^(Save As)(.*)$"
        "float, title:^(Library)(.*)$"
        "float, title:^(File Upload)(.*)$"
        "center, title:^(Open File)(.*)$"
        "center, title:^(Select a File)(.*)$"
        "center, title:^(Open Folder)(.*)$"
        "center, title:^(Save As)(.*)$"
        "center, title:^(File Upload)(.*)$"
      ];

      # Layer rules for Ambxst (Quickshell-based)
      # v1.0+ namespace: ambxst (bar, popups, notifications, OSD)
      layerrule = [
        # ── Ambxst shell components (v1.0+ namespace) ──
        "blur, ambxst"
        "blur, ambxst:*"
        "ignorealpha 0.4, ambxst"
        "ignorealpha 0.4, ambxst:*"
        "animation slide, ambxst:*"

        # ── Legacy / fallback namespace ──
        "blur, shell:*"
        "ignorealpha 0.4, shell:*"

        # ── GTK layer shell (file pickers, polkit dialogs) ──
        "blur, gtk-layer-shell"
        "ignorezero, gtk-layer-shell"

        # ── Hyprland lock screen ──
        "blur, hyprlock"
        "ignorealpha 0.4, hyprlock"
      ];


      # ────────────────────────────────────────
      # Variables
      # ────────────────────────────────────────
      "$mod" = "SUPER";
      "$terminal" = "ghostty";
      "$filemanager" = "thunar";
      "$browser" = "firefox";


      # ────────────────────────────────────────
      # Keybindings — Axenide-style
      # ────────────────────────────────────────
      bind = [

        # ── Window Management ──
        "$mod, C, killactive"                          # close window
        "$mod SHIFT, Escape, exit"                     # exit Hyprland
        "$mod, Space, togglefloating"                  # toggle float
        "$mod, P, pseudo"                              # pseudo-tile
        "$mod SHIFT, D, togglesplit"                   # toggle dwindle split
        "$mod, F, fullscreen, 0"                       # fullscreen (covers bar)
        "$mod SHIFT, F, fullscreen, 1"                 # maximize (keeps bar/gaps)
        "$mod CTRL, F, fullscreen, 2"                  # internal fullscreen
        "$mod, Y, pin"                                 # pin floating window
        "$mod, G, centerwindow"                        # center floating window

        # ── Layout Switch (Dwindle ↔ Master) ──
        "$mod, Tab, exec, hyprctl keyword general:layout dwindle"
        "$mod SHIFT, Tab, exec, hyprctl keyword general:layout master"

        # ── Focus — HJKL + Arrows ──
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        "$mod, left,  movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up,    movefocus, u"
        "$mod, down,  movefocus, d"

        # ── Move Tiled Windows — SHIFT + HJKL / Arrows ──
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"
        "$mod SHIFT, left,  movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up,    movewindow, u"
        "$mod SHIFT, down,  movewindow, d"

        # ── Workspaces 1–10 (0 = workspace 10) ──
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # ── Move Window to Workspace ──
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # ── Workspace Navigation ──
        "$mod, Z, workspace, previous"                 # previous workspace
        "$mod, X, workspace, e+1"                      # next active
        "$mod SHIFT, Z, workspace, m-1"                # prev active
        "$mod SHIFT, X, workspace, m+1"                # next active
        "$mod, mouse_down, workspace, e+1"             # scroll → next
        "$mod, mouse_up, workspace, e-1"               # scroll → prev

        # ── Programs ──
        "$mod, Return, exec, $terminal"
        "$mod SHIFT, Return, exec, [float; size 55% 55%; center] $terminal"
        "$mod, E, exec, $filemanager"
        "$mod SHIFT, E, exec, [float; size 60% 60%; center] $filemanager"
        "$mod, W, exec, $browser"
        "$mod SHIFT, W, exec, $browser --private-window"

        # ── Ambxst Shell Controls ──
        "$mod, D, exec, ambxst toggle-dashboard"       # dashboard / app launcher
        "$mod, A, exec, ambxst toggle-ai"              # AI assistant
        "$mod, comma, exec, ambxst toggle-wallpaper"   # wallpaper selector
        "$mod SHIFT, B, exec, ambxst reload-css"       # reload shell CSS
        "$mod ALT, B, exec, ambxst restart"            # restart shell
        "$mod CTRL, B, exec, ambxst toggle-bar"        # toggle bar visibility

        # ── Screenshots (manual fallback — Ambxst handles these too) ──
        ", Print, exec, mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" - | tee ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png | wl-copy"
        "SHIFT, Print, exec, mkdir -p ~/Pictures/Screenshots && grim - | tee ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png | wl-copy"
        "$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy"

        # ── Lock ──
        "$mod CTRL, Escape, exec, hyprlock"
      ];

      # ── Resize — CTRL + HJKL / Arrows (repeatable) ──
      # ── Move Floating — ALT + HJKL / Arrows (repeatable) ──
      binde = [
        "$mod CTRL, H, resizeactive, -30 0"
        "$mod CTRL, L, resizeactive, 30 0"
        "$mod CTRL, K, resizeactive, 0 -30"
        "$mod CTRL, J, resizeactive, 0 30"
        "$mod CTRL, left,  resizeactive, -30 0"
        "$mod CTRL, right, resizeactive, 30 0"
        "$mod CTRL, up,    resizeactive, 0 -30"
        "$mod CTRL, down,  resizeactive, 0 30"

        "$mod ALT, H, moveactive, -30 0"
        "$mod ALT, L, moveactive, 30 0"
        "$mod ALT, K, moveactive, 0 -30"
        "$mod ALT, J, moveactive, 0 30"
        "$mod ALT, left,  moveactive, -30 0"
        "$mod ALT, right, moveactive, 30 0"
        "$mod ALT, up,    moveactive, 0 -30"
        "$mod ALT, down,  moveactive, 0 30"
      ];

      # ── Media / Brightness (locked — work on lock screen) ──
      bindel = [
        ", XF86AudioRaiseVolume,  exec, pamixer -i 5"
        ", XF86AudioLowerVolume,  exec, pamixer -d 5"
        ", XF86MonBrightnessUp,   exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindl = [
        ", XF86AudioMute,    exec, pamixer -t"
        ", XF86AudioMicMute, exec, pamixer --default-source -t"
        ", XF86AudioPlay,    exec, playerctl play-pause"
        ", XF86AudioNext,    exec, playerctl next"
        ", XF86AudioPrev,    exec, playerctl previous"
      ];

      # ── Mouse Binds ──
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };


  # ──────────────────────────────────────────────
  # hypridle — OLED-optimized idle chain
  # ──────────────────────────────────────────────

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 180;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 480;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 900;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };


  # ──────────────────────────────────────────────
  # Firefox
  # ──────────────────────────────────────────────

  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "media.ffmpeg.vaapi.enabled" = true;
        "gfx.webrender.all" = true;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.searches" = false;
      };
    };
  };


  # ──────────────────────────────────────────────
  # Polkit Agent — systemd autostart
  # ──────────────────────────────────────────────
  # Ambxst has a built-in polkit agent, but polkit-gnome
  # ensures coverage before Ambxst loads or if it crashes.

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "polkit-gnome-authentication-agent-1";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };


  # ──────────────────────────────────────────────
  # fzf + direnv
  # ──────────────────────────────────────────────

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
