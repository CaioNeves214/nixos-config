{
  description = "Primeira Config NixOs Caio";

  inputs = {

    nixpkgs.url =
      "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url =
        "github:nix-community/home-manager/release-25.05";

      inputs.nixpkgs.follows =
        "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
  {
    nixosConfigurations.macbookpro2012 =
      nixpkgs.lib.nixosSystem {

        system = "x86_64-linux";

        modules = [

          ./hosts/macbookpro2012/configuration.nix

          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.caio =
              import ./home/caio.nix;
          }
        ];
      };
  };
}
