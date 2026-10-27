{
  description = "direnv-az - direnv extension for Azure Key Vault and subscription selection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # The helpers are sourced by direnv, so the package only ships the scripts
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "direnv-az";
          version = pkgs.lib.removeSuffix "\n" (builtins.readFile ./version.txt);
          src = pkgs.lib.cleanSource ./.;
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -Dm644 -t $out/share/direnv-az lib/*.sh
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "direnv extension for Azure Key Vault and subscription selection";
            homepage = "https://github.com/direnv-contrib/direnv-az";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        devShells.default = pkgs.mkShell {
          name = "direnv-az";
          packages = with pkgs; [
            bash
            bats
            direnv
            jq
            shellcheck
          ];
        };
      }
    )
    // {
      # Home Manager module: enabling it sources the helpers from direnv's standard library
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          options.programs.direnv-az.enable = lib.mkEnableOption "the direnv-az helpers";

          config = lib.mkIf config.programs.direnv-az.enable {
            assertions = [
              {
                assertion = config.programs.direnv.enable;
                message = "programs.direnv-az.enable requires programs.direnv.enable = true";
              }
            ];

            programs.direnv.stdlib = ''
              for lib in ${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/direnv-az/*.sh; do
                source "$lib"
              done
            '';
          };
        };
    };
}
