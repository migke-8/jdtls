{
  description = "JDTLS + JBang LS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    jbang-ls-src = {
      url = "github:jbangdev/jbang-eclipse";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, jbang-ls-src }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      jbang-ls-deps = pkgs.stdenv.mkDerivation {
        pname = "jbang-ls-deps";
        version = "0.0.2";
        outputHash = "sha256-dE9mlUPQBa3uDcJfMUzy+gwsy+SuExt02JkE6v4Ww4s=";
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";

        src = jbang-ls-src;

        nativeBuildInputs = with pkgs; [
          maven
          jdk21
          cacert
        ];
        postPatch = ''
          substituteInPlace pom.xml \
            --replace-fail \
              '<generateSourceRef>true</generateSourceRef>' \
              '<generateSourceRef>false</generateSourceRef>'
        '';
        preBuild = ''
          export HOME="$TMPDIR/home"
          export MAVEN_OPTS="-Dmaven.repo.local=$TMPDIR/maven-repo"

          mkdir -p "$HOME"
          mkdir -p "$TMPDIR/maven-repo"
        '';
        buildPhase = ''
            runHook preBuild
            export SOURCE_DATE_EPOCH=315532802
            ./mvnw \
            -T 1C \
            -pl dev.jbang.eclipse.target,dev.jbang.eclipse.core,dev.jbang.eclipse.ls \
            -am \
            -Dmaven.test.skip=true \
            -DgenerateSourceRef=false \
            -P '!code-coverage' \
            package
            runHook postBuild
        '';
        installPhase = ''
          runHook preInstall

          mkdir -p "$out/jars"
          cp dev.jbang.eclipse.core/target/dev.jbang.eclipse.core-*.jar \
            "$out/jars/"
          cp dev.jbang.eclipse.ls/target/dev.jbang.eclipse.ls-*.jar \
            "$out/jars/"

          runHook postInstall
        '';
      };
      jdtls = pkgs.jdt-language-server.overrideAttrs (old: {
        postInstall = ''
          ${old.postInstall or ""}

          mkdir -p "$out/share/jdtls/plugins"

          cp ${jbang-ls-deps}/jars/*.jar "$out/share/jdtls/plugins/"
        '';
      });
    in
    {
      packages.${system} = {
        inherit jbang-ls-deps;
        jdt-language-server = jdtls;
        default = jdtls;
      };
    };
}
