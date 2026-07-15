{
  description = "Primeira Config NixOs Caio";

  inputs = {

    nixpkgs.url =
      "github:NixOS/nixpkgs/nixos-25.05";

    # Só para pacotes ausentes no 25.05 (ex.: quickshell, que chegou no
    # nixpkgs apenas em 25.11/unstable). Não segue home-manager para não
    # puxar o resto do sistema para unstable.
    nixpkgs-unstable.url =
      "github:NixOS/nixpkgs/nixos-unstable";

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
      nixpkgs-unstable,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
  {
    nixosConfigurations.macbookpro2012 =
      nixpkgs.lib.nixosSystem {

        inherit system;

        modules = [

          ./hosts/macbookpro2012/configuration.nix

          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # Faz backup (em vez de falhar) quando um arquivo não-gerenciado
            # estiver no caminho de um symlink do Home Manager.
            home-manager.backupFileExtension = "backup";

            # Expõe pkgs-unstable (25.11) aos módulos home/*.nix, para
            # pacotes ainda não disponíveis no 25.05 (ex.: quickshell).
            home-manager.extraSpecialArgs = { inherit pkgs-unstable; };

            home-manager.users.caio =
              import ./home/caio.nix;
          }
        ];
      };
  };
}
