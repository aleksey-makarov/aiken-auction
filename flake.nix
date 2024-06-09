{
  description = "aiken-auction";

  nixConfig.bash-prompt = "aiken-auction";
  nixConfig.bash-prompt-prefix = "[\\033[1;33m";
  nixConfig.bash-prompt-suffix = "\\033[0m \\w]$ ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aiken = {
      url = "github:aiken-lang/aiken";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cardano-node = {
      url = "github:IntersectMBO/cardano-node/8.9.2";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix-vscode-extensions,
    aiken,
    cardano-node,
  }: let
    system = "x86_64-linux";

    pkgs = nixpkgs.legacyPackages.${system};

    extensions = nix-vscode-extensions.extensions.${system};

    vscode = pkgs.vscode-with-extensions.override {
      vscode = pkgs.vscodium;
      vscodeExtensions = [
        extensions.vscode-marketplace.bbenoist.nix
        extensions.vscode-marketplace.txpipe.aiken
        extensions.vscode-marketplace.denoland.vscode-deno
        extensions.vscode-marketplace.laurencebahiirwa.deno-std-lib-snippets
      ];
    };

    cardano-packages = [
      cardano-node.packages."${system}"."preview/node"
      cardano-node.packages."${system}".cardano-cli
      aiken.packages.${system}.aiken
    ];
  in {
    devShells.${system} = rec {
      aiken-auction = with pkgs;
        mkShell {
          packages = [vscode pkgs.deno xxd jq] ++ cardano-packages;
          shellHook = ''
            export HOME=$(pwd)
            if [ -f ~/.secrets.txt ] ; then
                . ~/.secrets.txt
            fi
            # cardano-cli autocompletion is broken, FIXME
            shopt -u progcomp
          '';
        };
      default = aiken-auction;
    };
  };
}
