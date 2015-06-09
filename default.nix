{ mkDerivation, base, bytestring, case-insensitive, configurator
, containers, directory, filepath, HandsomeSoup, hspec, HTTP
, http-types, hxt, iso8601-time, MissingH, multipart, old-locale
, silently, stdenv, stm, tar, text, time, unix, errors_2_0_0
, unordered-containers, utf8-string, wai, warp, ghc, cabal-install
, temporary, directory
}:
mkDerivation {
  pname = "heyefi";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  buildTools = [ ghc cabal-install ];
  buildDepends = [
    base bytestring case-insensitive configurator HandsomeSoup HTTP
    http-types hxt iso8601-time MissingH multipart old-locale stm tar
    text time unix unordered-containers utf8-string wai warp errors_2_0_0
    temporary directory
  ];
  testDepends = [
    base bytestring case-insensitive configurator containers directory
    filepath HandsomeSoup hspec HTTP http-types hxt iso8601-time
    MissingH multipart old-locale silently stm tar text time unix
    unordered-containers utf8-string wai warp errors_2_0_0
    temporary directory
  ];
  homepage = "https://github.com/ryantm/heyefi";
  description = "A server for Eye-Fi SD cards written in Haskell. This project is not endorsed by Eye-Fi Inc.";
  license = stdenv.lib.licenses.publicDomain;
}
