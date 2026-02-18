{
  description = "NixOS — Asus Zenbook S 13 OLED (UM5302TA)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";   # keep in sync with system nixpkgs
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.zenbook = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        ./hardware-tweaks.nix
        ./hyprland.nix

        # ── Home Manager as NixOS module ──
        # Deploys automatically with `sudo nixos-rebuild switch`
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;       # use system's nixpkgs instance
          home-manager.useUserPackages = true;      # install to /etc/profiles/per-user
          home-manager.backupFileExtension = "backup"; # avoid activation crash on conflict
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.asif = import ./home.nix;
        }
      ];
    };
  };
}
