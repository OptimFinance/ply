.PHONY: hoogle build-all test-core format lint requires_nix_shell

build-all:
	nix -L --show-trace build .#build-all.x86_64-linux

hoogle: requires_nix_shell
	hoogle server --local --port=8070 > /dev/null &

ifdef FLAGS
GHC_FLAGS = --ghc-options "$(FLAGS)"
endif

test-core:
	nix -L --show-trace build .#test-core.x86_64-linux

EXTENSIONS := -o -XTypeApplications -o -XPatternSynonyms

# Run fourmolu formatter
format: requires_nix_shell
	env -C ply-core fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C ply-core fd -ehs)
	env -C ply-plutarch fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C ply-plutarch fd -ehs)
	env -C example/offchain fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C example/offchain fd -ehs)
	env -C example/onchain fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C example/onchain fd -ehs)
	nixpkgs-fmt $(NIX_SOURCES)
	cabal-fmt -i $(CABAL_SOURCES)

# Check formatting (without making changes)
format_check:
	env -C ply-core fourmolu --mode check --check-idempotence $(EXTENSIONS) $(shell env -C ply-core fd -ehs)
	env -C ply-plutarch fourmolu --mode check --check-idempotence $(EXTENSIONS) $(shell env -C ply-plutarch fd -ehs)
	env -C example/offchain fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C example/offchain fd -ehs)
	env -C example/onchain fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C example/onchain fd -ehs)
	nixpkgs-fmt --check $(NIX_SOURCES)
	cabal-fmt -c $(CABAL_SOURCES)

# Nix files to format
NIX_SOURCES := $(shell fd -enix)
# Cabal files to format
CABAL_SOURCES := $(shell fd -ecabal)

nixfmt: requires_nix_shell
	nixfmt $(NIX_SOURCES)

nixfmt_check: requires_nix_shell
	nixfmt --check $(NIX_SOURCES)

# Apply hlint suggestions
lint: requires_nix_shell
	find -name '*.hs' -not -path './dist-*/*' -exec hlint --refactor --refactor-options="--inplace" {} \;

# Check hlint suggestions
lint_check: requires_nix_shell
	hlint $(shell fd -ehs)

# Target to use as dependency to fail if not inside nix-shell
requires_nix_shell:
	@ [ "$(IN_NIX_SHELL)" ] || echo "The $(MAKECMDGOALS) target must be run from inside a nix shell"
	@ [ "$(IN_NIX_SHELL)" ] || (echo "    run 'nix develop .#devEnv' first" && false)
