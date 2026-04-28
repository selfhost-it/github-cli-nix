# GitHub CLI (gh) - GitHub on the command line
#
# Built from GitHub source using buildGoModule.
#
# To update:
#   1. Change `version`
#   2. Update `hash` (set to "" and build — nix will tell you the correct hash)
#   3. Update `vendorHash` (set to "" and build — nix will tell you the correct hash)
#   4. Run `nix build`

{ lib
, buildGoModule
, fetchFromGitHub
, installShellFiles
, stdenv
}:

let
  # PINNED to the last 2.87.x release. gh 2.88.0+ bumps go.mod to
  # `go 1.26.1`, which is not available in nixos-25.11 stable (ships
  # Go 1.25.8). With GOTOOLCHAIN=local enforced inside the Nix sandbox,
  # building 2.88.0+ against a stable nixpkgs fails with:
  #   go: go.mod requires go >= 1.26.1 (running go 1.25.8; GOTOOLCHAIN=local)
  # Bump back to "latest" once Go 1.26 lands in nixpkgs stable.
  version = "2.87.3";
in
buildGoModule {
  pname = "gh";
  inherit version;

  src = fetchFromGitHub {
    owner = "cli";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-F4xUwj/krB5vjIfnvmwySlztBrcxJ+k1GvXb2gs7eXY=";
  };

  vendorHash = "sha256-POrm4lHEO2Eti7dbohKBwXW+DTs22EUZX+tMNUCL3lg=";

  nativeBuildInputs = [ installShellFiles ];

  # The upstream Makefile injects version + build date via -ldflags into
  # github.com/cli/cli/v2/internal/build. Without GH_VERSION the binary
  # reports "DEV" and `gh --version` looks broken.
  buildPhase = ''
    runHook preBuild
    make GO_LDFLAGS="-s -w" GH_VERSION=v${version} bin/gh manpages
    runHook postBuild
  '';

  # Disable buildGoModule's default check phase — `make test` pulls in
  # network-dependent integration tests and is not how upstream gates releases.
  doCheck = false;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/gh -t $out/bin
    installManPage share/man/man1/*.1
  ''
  # Cross-compiled binaries can't run on the build host, so completion
  # generation is skipped in that case (matches nixpkgs' approach).
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd gh \
      --bash <($out/bin/gh completion -s bash) \
      --zsh  <($out/bin/gh completion -s zsh) \
      --fish <($out/bin/gh completion -s fish)
  '' + ''
    runHook postInstall
  '';

  meta = with lib; {
    description = "GitHub CLI - GitHub on the command line";
    homepage = "https://github.com/cli/cli";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "gh";
  };
}
