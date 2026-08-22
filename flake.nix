{
  description = "JDTLS + JBang LS";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/nixos-unstable";

    jbang-ls-src = {
      url = "github:jbangdev/jbang-eclipse";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    jbang-ls-src,
  }:

  let

    system = "x86_64-linux";

    pkgs =
      import nixpkgs {
        inherit system;
      };

    jbang-ls-deps =
      pkgs.stdenv.mkDerivation {

        pname = "jbang-ls-deps";
        version = "git";

        src = jbang-ls-src;

        nativeBuildInputs = with pkgs; [
          maven
          cacert
        ];

        outputHashMode = "recursive";
        outputHash = pkgs.lib.fakeSha256;

        buildPhase = ''
          ./mvnw clean package
        '';

        installPhase = ''
          mkdir -p "$out/jars"

          find . \
            -type f \
            -name '*.jar' \
            \( \
              -path '*/dev.jbang.eclipse.ls/*' \
              -o \
              -path '*/dev.jbang.eclipse.core/*' \
            \) \
            -exec cp {} "$out/jars/" \;
        '';
      };

    jdtls =
      pkgs.jdt-language-server.overrideAttrs
        (old: {

          postInstall = ''
            ${old.postInstall or ""}

            mkdir -p "$out/share/jdtls/bundles"

            cp ${jbang-ls-deps}/jars/*.jar \
              "$out/share/jdtls/bundles/"
          '';
        });

  in {

    packages.${system} = {
      inherit jbang-ls-deps;
      jdt-language-server = jdtls;
      default = jdtls;
    };
  };
}
