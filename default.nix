{ mkDerivation, base, pure-bloom, pure-time, pure-txt, containers, stdenv }:
mkDerivation {
  pname = "pure-bloom-limiter";
  version = "0.8.0.0";
  src = ./.;
  libraryHaskellDepends = [ base pure-bloom pure-time pure-txt containers ];
  homepage = "github.com/grumply/pure-bloom-limiter";
  license = stdenv.lib.licenses.bsd3;
}
