{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    forester.url = "github:jonsterling/ocaml-forester";
    forest-server.url = "github:kentookura/forest-server";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    systems,
    forester,
    forest-server,
  }:
    flake-utils.lib.eachSystem (import systems)
    (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      forester-pkg = forester.packages.${system}.default;
      tlDist = pkgs.texliveFull;
    in {
      packages = flake-utils.lib.flattenTree rec {
        forester = forester-pkg;
        tldist = tlDist;
        new = pkgs.writeScriptBin "new"
        ''
          ${forester-pkg}/bin/forester new bci-forest.toml --dest=trees --prefix=$1
        '';
        build = pkgs.writeScriptBin "build"
        ''
          ${forester-pkg}/bin/forester build bci-forest.toml
        '';
        serve = pkgs.writeScriptBin "serve"
        ''
          ${pkgs.python3}/bin/python3 -m http.server -d output 8080
        '';
        forester-dev = pkgs.writeScriptBin "forester-dev"
        ''
          ${forest-server.packages.${system}.default}/bin/forest watch $@ -- "build bci-forest.toml"
        '';
        forest = pkgs.stdenv.mkDerivation {
          name = "bci-horse-forest";
          src = ./.;
          nativeBuildInputs = [
            tlDist
            forester-pkg
          ];
          dontConfigure = true;
          buildPhase = ''
            forester build bci-forest.toml
          '';
          installPhase = ''
            mkdir -p $out
            cp -r output/* $out/
            echo "/ /index.xml 200" > $out/_redirects
            printf "/index.xml\n  Content-Type: application/xml\n/*.xml\n  Content-Type: application/xml\n" > $out/_headers
          '';
        };
        default = forest;
      };

      devShells.shell-minimal = pkgs.mkShell {
        buildInputs = with self.packages.${system}; [
          forester-pkg new build serve
        ];
      };

      devShells.shell-notex = pkgs.mkShell {
        buildInputs = with self.packages.${system}; [
          forester-pkg new build serve forester-dev
        ];
      };

      devShells.default = pkgs.mkShell {
        buildInputs = with self.packages.${system}; [
          forester-pkg new build serve
          forester-dev
          forest-server.packages.${system}.default
          tlDist
        ];
      };
    });
}
