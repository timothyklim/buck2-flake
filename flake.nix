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
            overlays = [ fenix.overlays.default ];
          };
          patched_src = with pkgs; stdenv.mkDerivation {
            inherit src;
            name = "src";
            patches = [ ./cargo-lock.patch ];
            installPhase = "cp -r . $out";
          };
          rust_toolchain = pkgs.fenix.toolchainOf {
            channel = "nightly";
            date = "2023-01-24";
            # sha256 = pkgs.lib.fakeSha256;
            sha256 = "sha256-I+5ZBqZ2tp/zm13naiIpkrEX6TvXVOlZmjjCVdABEIY";
          };
          naersk = pkgs.callPackage naersk-src { inherit (rust_toolchain) cargo rustc; };
          buck2 = with pkgs; naersk.buildPackage {
            name = "buck2";
            src = patched_src;
            stdenv = pkgs.llvmPackages_15.stdenv;
            cargoBuildOptions = opts: opts ++ [ "--manifest-path=app/buck2/Cargo.toml" ];
            singleStep = true;
            gitSubmodules = true;
            gitAllRefs = true;

            nativeBuildInputs = [ protobuf pkg-config ] ++ lib.optionals stdenv.isDarwin [ fixDarwinDylibNames ];
            buildInputs = [ openssl sqlite ];

            BUCK2_BUILD_PROTOC = "${protobuf}/bin/protoc";
            BUCK2_BUILD_PROTOC_INCLUDE = "${protobuf}/include";

            doCheck = false;
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
