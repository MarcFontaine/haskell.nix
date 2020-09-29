{ stdenv, haskell-nix, recurseIntoAttrs, testSrc, compiler-nix-name, runCommand, buildPackages }:

with stdenv.lib;

let
  src = testSrc "githash";
  project = haskell-nix.cabalProject' {
    inherit src;
    # When haskell.nix has come from the store (e.g. on hydra) we need to provide
    # a suitable mock of the cleaned source with a .git dir.
    modules = optional (!(src ? origSrc && __pathExists (src.origSrc + "/.git"))) {
      packages.githash-test.src =
        rec {
          origSrc = runCommand "githash-test-src" { buildInputs = [ buildPackages.buildPackages.gitReallyMinimal ]; } ''
            mkdir -p $out/test/githash
            cd $out
            git init
            cp -r ${src}/* test/githash
            git add test/githash
            git -c "user.name=unknown" -c "user.email=unknown" commit -m 'Initial Commit'
          '';
          origSubDir = "/test/githash";
          origSrcSubDir = origSrc + origSubDir;
          outPath = origSrcSubDir;
        };
    };
    inherit compiler-nix-name;
  };

  packages = project.hsPkgs;
  githash-test =
    packages.githash-test.components.exes.githash-test;

in recurseIntoAttrs {
  ifdInputs = {
    inherit (project) plan-nix;
  };

  run = stdenv.mkDerivation {
    name = "run-githash-test";

    buildCommand = ''
      exe="${githash-test}/bin/githash-test${stdenv.hostPlatform.extensions.executable}"
      echo Checking that the error message is generated and that it came from the right place:
      (${toString githash-test.config.testWrapper} $exe || true) 2>&1 \
        | grep "error, called at src/Main.hs:5:13 in main:Main"
      touch $out
    '';

    meta.platforms = platforms.all;

    passthru = {
      # Used for debugging with nix repl
      inherit project packages;
    };
  };
}
