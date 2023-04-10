{
  description = "Buck2 flake";

  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk-src = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    src = {
      url = "github:facebook/buck2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, naersk-src, src }:
    with flake-utils.lib; eachSystem [
      system.aarch64-darwin
      system.aarch64-linux
      system.x86_64-darwin
      system.x86_64-linux
    ]
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              fenix.overlays.default
            ] ++ [
              (self: super: rec {
                naersk = pkgs.callPackage naersk-src { inherit (pkgs.fenix.default) cargo rustc; };
              })
            ];
          };
          buck2 = with pkgs; naersk.buildPackage {
            src = stdenv.mkDerivation {
              inherit src;
              name = "src";
              patches = [ ./cargo-lock.patch ];
              installPhase = ''
                cp -r . $out
              '';
            };
            name = "buck2";
            cargoBuildOptions = opts: opts ++ [ "-p=app/buck2" ];
          };
          buck2-app = flake-utils.lib.mkApp { drv = buck2; };
          derivation = { inherit buck2; };
        in
        with pkgs; rec {
          packages = derivation // { default = buck2; };
          apps.buck2 = buck2-app;
          defaultApp = buck2-app;
          legacyPackages = extend overlay;
          devShell = mkShell {
            name = "buck2-env";
            buildInputs = [ buck2 ];
          };
          nixosModules.default = {
            nixpkgs.overlays = [ overlay ];
          };
          overlay = final: prev: derivation;
          formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
        });
}
