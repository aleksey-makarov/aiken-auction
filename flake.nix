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
        extensions.vscode-marketplace.timonwong.shellcheck
        extensions.vscode-marketplace-release.github.copilot
        extensions.vscode-marketplace-release.github.copilot-chat
      ];
    };

    run-preview-node_sh = pkgs.writeShellScriptBin "run-preview-node.sh" ''
      cd "$STATE_NODE_DIR" || exit 1
      exec cardano-node-preview
    '';

    cardano-packages = [
      cardano-node.packages."${system}"."preview/node"
      cardano-node.packages."${system}".cardano-cli
      aiken.packages.${system}.aiken
      run-preview-node_sh
    ];
  in {
    devShells.${system} = rec {
      aiken-auction = with pkgs;
        mkShell {
          packages = [vscode deno xxd jq shellcheck] ++ cardano-packages;
          shellHook = ''
            export HOME=$(pwd)
            if [ -f ~/.secrets ] ; then
                . ~/.secrets
            fi
            # cardano-cli autocompletion is broken, FIXME
            shopt -u progcomp
          '';
        };
      default = aiken-auction;
    };

    # FIXME:
    # apps.${system} = rec {
    #   cardano-node-preview = {
    #     type = "app";
    #     program = "${run-preview-node_sh}/bin/run-preview-node.sh";
    #   };
    #   default = cardano-node-preview;
    # };
  };
}
