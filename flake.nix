{
  description = "Ply - A helper library for working with compiled, parameterized Plutus Scripts";

  inputs = rec {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    extra-hackage.url = "github:mlabs-haskell/haskell-nix-extra-hackage?ref=ee50d7eb739819efdb27bda9f444e007c12e9833";
    extra-hackage.inputs.haskell-nix.follows = "haskell-nix";
    extra-hackage.inputs.nixpkgs.follows = "nixpkgs";

    iohk-nix.url = "github:input-output-hk/iohk-nix";
    iohk-nix.flake = false; # Bad Nix code

    #    plutarch = {
    #      url = "github:Plutonomicon/plutarch-plutus?ref=staging";
    #    };
    plutarch.url = "github:OptimFinance/plutarch-plutus/0d4bdb2c3c3772b9ef5e3df8440825f38eaf6342";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    plutus = {
      url =
        "github:input-output-hk/plutus/b39a526e983cb931d0cc49b7d073d6d43abd22b5";
      flake = false;
    };
    cardano-base = {
      url =
        "github:input-output-hk/cardano-base/0f3a867493059e650cda69e20a5cbf1ace289a57";
      flake = false;
    };
    cardano-crypto = {
      url =
        "github:input-output-hk/cardano-crypto/07397f0e50da97eaa0575d93bee7ac4b2b2576ec";
      flake = false;
    };
    cardano-prelude = {
      url =
        "github:input-output-hk/cardano-prelude/bb4ed71ba8e587f672d06edf9d2e376f4b055555";
      flake = false;
    };
    flat = {
      url =
        "github:input-output-hk/flat/ee59880f47ab835dbd73bea0847dab7869fc20d8";
      flake = false;
    };

    protolude = {
      url = "github:protolude/protolude";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, haskell-nix, extra-hackage, iohk-nix, plutarch, pre-commit-hooks, ... }:
    let
      #      # https://github.com/input-output-hk/haskell.nix/issues/1177
      #      nonReinstallablePkgs = [
      #        "array"
      #        "array"
      #        "base"
      #        "binary"
      #        "bytestring"
      #        "Cabal"
      #        "containers"
      #        "deepseq"
      #        "directory"
      #        "exceptions"
      #        "filepath"
      #        "ghc"
      #        "ghc-bignum"
      #        "ghc-boot"
      #        "ghc-boot"
      #        "ghc-boot-th"
      #        "ghc-compact"
      #        "ghc-heap"
      #        # "ghci"
      #        # "haskeline"
      #        "ghcjs-prim"
      #        "ghcjs-th"
      #        "ghc-prim"
      #        "ghc-prim"
      #        "hpc"
      #        "integer-gmp"
      #        "integer-simple"
      #        "mtl"
      #        "parsec"
      #        "pretty"
      #        "process"
      #        "rts"
      #        "stm"
      #        "template-haskell"
      #        "terminfo"
      #        "text"
      #        "time"
      #        "transformers"
      #        "unix"
      #        "Win32"
      #        "xhtml"
      #      ];

      myhackages = system: compiler-nix-name: extra-hackage.mkHackageFor system compiler-nix-name (
        #      myhackages = system: compiler-nix-name: extra-hackage.mkHackagesFor system compiler-nix-name (
        [
          "${inputs.flat}"
          "${inputs.cardano-prelude}/cardano-prelude"
          "${inputs.cardano-crypto}"
          "${inputs.cardano-base}/binary"
          "${inputs.cardano-base}/cardano-crypto-class"
          "${inputs.plutus}/plutus-core"
          "${inputs.plutus}/plutus-ledger-api"
          "${inputs.plutus}/plutus-tx"
          "${inputs.plutus}/prettyprinter-configurable"
          "${inputs.plutus}/word-array"
        ]
      );

      # GENERAL
      supportedSystems = with nixpkgs.lib.systems.supported; tier1 ++ tier2 ++ tier3;
      perSystem = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = system:
        import nixpkgs {
          inherit system;
          overlays = [
            haskell-nix.overlay
            (import "${iohk-nix}/overlays/crypto")
          ];
          inherit (haskell-nix) config;
        };
      nixpkgsFor' = system: import nixpkgs { inherit system; };

      pre-commit-check-for = system: pre-commit-hooks.lib.${system}.run {
        src = ./.;
        settings = {
          ormolu.defaultExtensions = [
            "TypeApplications"
            "PatternSynonyms"
          ];
        };

        hooks = {
          nixpkgs-fmt.enable = true;
          cabal-fmt.enable = true;
          fourmolu.enable = true;
          hlint.enable = true;
        };
      };


      mkDevEnv = system:
        # Generic environment bringing generic utilities. To be used only as a
        # shell. Include as a dependency to other shells to have the same
        # utilities in the shell.
        let
          pkgs = nixpkgsFor system;
          pkgs' = nixpkgsFor' system;
        in
        pkgs.stdenv.mkDerivation {
          name = "Standard-Dev-Environment-with-Utils";
          buildInputs = [
            pkgs'.bashInteractive
            pkgs'.cabal-install
            pkgs'.fd
            pkgs'.git
            pkgs'.gnumake
            pkgs'.haskellPackages.apply-refact
            pkgs'.haskellPackages.cabal-fmt
            pkgs'.haskellPackages.fourmolu
            pkgs'.hlint
            pkgs'.nixpkgs-fmt
          ];
          shellHook = (pre-commit-check-for system).shellHook +
            ''
              echo $name
            '';
        };

      # Ply core
      ply-core = rec {
        ghcVersion = "8107";
        compiler-nix-name = "ghc${ghcVersion}";

        projectFor = system:
          let
            pkgs = nixpkgsFor system;
            pkgs' = nixpkgsFor' system;
            stdDevEnv = mkDevEnv system;
            h = myhackages system compiler-nix-name;
          in
          (nixpkgsFor system).haskell-nix.cabalProject' {
            inherit compiler-nix-name;
            #            inherit (h) extra-hackages extra-hackage-tarballs;
            extra-hackages = [ (import h.extra-hackage) ];
            extra-hackage-tarballs = { myhackage = h.extra-hackage-tarball; };
            src = ./.;
            cabalProjectFileName = "cabal.project.core";
            cabalProjectLocal = ''
              allow-newer: size-based:template-haskell
            '';
            modules = [
              #              ({
              #                  inherit nonReinstallablePkgs;
              #                  reinstallableLibGhc = false;
              #              })
              ({ pkgs, ... }:
                {
                  packages = {
                    cardano-crypto-praos.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
                    cardano-crypto-class.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
                  };
                }
              )
            ]
            #  ++ h.modules;
            ++ [ h.module ];
            shell = {
              withHoogle = true;

              exactDeps = true;

              buildInputs = stdDevEnv.buildInputs;

              tools.haskell-language-server = { };

              shellHook = ''
                export NIX_SHELL_TARGET="core"
                ln -fs cabal.project.core cabal.project
              '' + (pre-commit-check-for system).shellHook;
            };
          };
      };

      # Ply x Plutarch
      ply-plutarch = rec {
        ghcVersion = "923";
        compiler-nix-name = "ghc${ghcVersion}";

        projectFor = system:
          let
            pkgs = import plutarch.inputs.nixpkgs {
              inherit system;
              inherit (plutarch.inputs.haskell-nix) config;
              overlays = [
                plutarch.inputs.haskell-nix.overlay
                (import "${plutarch.inputs.iohk-nix}/overlays/crypto")
              ];
            };
            stdDevEnv = mkDevEnv system; # TODO: parametrize with pkgs rather?
            hls = (plutarch.hlsFor compiler-nix-name system);
            #            myPlutarchHackages = plutarch.inputs.haskell-nix-extra-hackage.mkHackagesFor system compiler-nix-name [
            myPlutarchHackages = plutarch.inputs.haskell-nix-extra-hackage.mkHackageFor system compiler-nix-name [
              "${inputs.plutus}/plutus-tx"
              "${inputs.plutarch}"
              "${inputs.flat}"
              "${inputs.plutus}/plutus-ledger-api"
              "${inputs.plutus}/plutus-core"
              "${inputs.plutus}/word-array"
              "${inputs.plutus}/prettyprinter-configurable"
              "${inputs.cardano-base}/cardano-crypto-class"
              "${inputs.cardano-prelude}/cardano-prelude"
              "${inputs.protolude}"
              "${inputs.cardano-crypto}"
              "${inputs.cardano-base}/binary"
            ];
          in
          pkgs.haskell-nix.cabalProject' (plutarch.applyPlutarchDep pkgs {
            inherit compiler-nix-name;
            src = ./.;
            cabalProjectFileName = "cabal.project.plutarch";
            index-state = "2022-06-01T00:00:00Z";
            #            inherit (myPlutarchHackages) extra-hackages extra-hackage-tarballs modules;
            extra-hackages = [ (import myPlutarchHackages.extra-hackage) ];
            extra-hackage-tarballs = { myhackage = myPlutarchHackages.extra-hackage-tarball; };
            modules = [ myPlutarchHackages.module ];
            shell = {
              withHoogle = true;

              exactDeps = true;

              buildInputs = stdDevEnv.buildInputs ++ [ hls ];

              additional = ps: [
                ps.plutarch
                ps.plutus-ledger-api
              ];

              shellHook = ''
                export NIX_SHELL_TARGET="plutarch"
                ln -fs cabal.project.plutarch cabal.project
                ${(pre-commit-check-for system).shellHook}
              '';
            };
          });
      };

    in
    {
      inherit nixpkgsFor;

      ply-core = {
        project = perSystem ply-core.projectFor;
        flake = perSystem (system: (ply-core.projectFor system).flake { });
      };

      ply-plutarch = {
        project = perSystem ply-plutarch.projectFor;
        flake = perSystem (system: (ply-plutarch.projectFor system).flake { });
      };

      build-all = perSystem (system:
        (nixpkgsFor system).runCommand "build-all"
          (self.ply-core.flake.${system}.packages // self.ply-plutarch.flake.${system}.packages)
          "touch $out");

      test-core = perSystem (system:
        let pkgs = nixpkgsFor system;
        in
        pkgs.runCommand "test-core"
          (pkgs.lib.attrsets.getAttrs
            [ "ply-core:test:ply-core-test" ]
            self.ply-core.flake.${system}.checks) "touch $out");

      test-plutarch = perSystem (system:
        let pkgs = nixpkgsFor system;
        in
        pkgs.runCommand "test-plutarch"
          (pkgs.lib.attrsets.getAttrs
            [ "ply-plutarch:test:ply-plutarch-test" ]
            self.ply-plutarch.flake.${system}.checks) "touch $out");

      packages = perSystem
        (system:
          self.ply-core.flake.${system}.packages //
          self.ply-plutarch.flake.${system}.packages //
          { devEnv = mkDevEnv system; }
        );

      checks = perSystem (system:
        self.ply-core.flake.${system}.checks // self.ply-plutarch.flake.${system}.checks
        // { formatting-checks = pre-commit-check-for system; });

      check = perSystem (system:
        (nixpkgsFor system).runCommand "combined-test"
          {
            checksss = builtins.attrValues self.checks.${system}
              ++ builtins.attrValues self.packages.${system} ++ [
              self.devShells.${system}.ply-core.inputDerivation
            ];
          } ''
          echo $checksss
          touch $out
        '');

      apps = perSystem (system: self.ply-core.flake.${system}.apps // self.ply-plutarch.flake.${system}.apps);

      devShells = perSystem (system: rec {
        default = devEnv;
        core = self.ply-core.flake.${system}.devShell;
        plutarch = self.ply-plutarch.flake.${system}.devShell;
        devEnv = self.packages.${system}.devEnv;
      });
    };
}
