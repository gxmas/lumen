.PHONY: test test-verbose test-full build clean

# Run tests (100 iterations)
test:
	cabal test

# Run tests with verbose output
test-verbose:
	cabal test --test-show-details=streaming

# Run tests with 10,000 iterations (CI-level)
test-full:
	cabal test --test-options="--hedgehog-tests 10000"

# Build everything
build:
	cabal build all

# Clean build artifacts
clean:
	cabal clean
