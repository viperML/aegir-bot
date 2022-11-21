{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-filter.url = "github:numtide/nix-filter";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    nix-filter,
    fenix,
    nix2container,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem = {
        pkgs,
        config,
        system,
        inputs',
        ...
      }: {
        packages = let
          src = nix-filter.lib {
            root = ./.;
            exclude = [
              (nix-filter.lib.matchExt "nix")
              "flake.lock"
              (nix-filter.lib.matchExt "yaml")
              (nix-filter.lib.matchExt "sh")
            ];
          };
          fenixpkgs = fenix.packages.${system};
          variant = "beta";
          cargo-toml = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
          targetMusl = "${pkgs.stdenv.targetPlatform.uname.processor}-unknown-linux-musl";
        in {
          _toolchain_dev = fenixpkgs.combine [
            (fenixpkgs.${variant}.withComponents [
              "cargo"
              "rustc"
              "rust-src"
              "rustfmt"
              "rust-analyzer"
              "clippy"
            ])
            fenixpkgs.targets.${targetMusl}.${variant}.rust-std
          ];

          _toolchain_prod = fenixpkgs.combine [
            (fenixpkgs.${variant}.withComponents [
              "cargo"
              "rustc"
            ])
            fenixpkgs.targets.${targetMusl}.${variant}.rust-std
          ];

          # dev =
          #   (pkgs.makeRustPlatform {
          #     cargo = config.packages._toolchain_dev;
          #     rustc = config.packages._toolchain_dev;
          #   })
          #   .buildRustPackage {
          #     pname = cargo-toml.package.name;
          #     version = cargo-toml.package.version;
          #     inherit src;
          #     cargoLock.lockFile = src + "/Cargo.lock";
          #     RUST_SRC_PATH = "${config.packages._toolchain_dev}/lib/rustlib/src/rust/library";
          #   };

          default =
            (pkgs.makeRustPlatform {
              cargo = config.packages._toolchain_prod;
              rustc = config.packages._toolchain_prod;
              stdenv = pkgs.pkgsStatic.stdenv;
            })
            .buildRustPackage {
              pname = cargo-toml.package.name;
              version = cargo-toml.package.version;
              inherit src;
              cargoLock.lockFile = src + "/Cargo.lock";
              target = targetMusl;
              # CARGO_BUILD_TARGET = targetMusl;
              # CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
            };

          debug = pkgs.writeShellApplication {
            name = "aegir-bot";
            runtimeInputs = [
              config.packages.default
              pkgs.coreutils
            ];
            text = ''
              printenv AEGIR_ENV
              cat "$AEGIR_ENV"
              # shellcheck disable=SC2068
              aegir-bot $@
            '';
          };

          image-stream = let
            drv = config.packages.default;
          in
            pkgs.dockerTools.streamLayeredImage {
              inherit (drv) name;
              contents = [drv];
              config = {
                Cmd = [
                  "${pkgs.lib.getExe drv}"
                  "${src}/environments/priv.toml"
                ];
              };
            };
        };

        devShells.extra = with pkgs;
          mkShell {
            name = "extra";
            packages = [
              config.packages._toolchain_dev
            ];
          };

        legacyPackages = pkgs;
      };
    };
}
