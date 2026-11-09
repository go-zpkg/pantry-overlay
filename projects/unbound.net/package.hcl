dependencies = {
  "libexpat.github.io" = "^2"
  "openssl.org"        = "^3"
}

build {
  dependencies = {
    "github.com/westes/flex" = "*"
    "gnu.org/bison"          = "^3"
    "libexpat.github.io"     = "*"
  }
  # ⛔⛔ THE VARIABLE WAS $PKGX_DIR, WHICH NOTHING SETS — AND AN EMPTY LEFT-HAND
  # SIDE IS NOT A NO-OP. zbk runs every build script under a CLOSED environment
  # (`build.SanitizedEnv`, build/build.go:745-769: PATH, HOME, ZPKG_DIR,
  # MAKEFLAGS, FORCE_UNSAFE_CONFIGURE, plus the ZPKG_DIST/PANTRY/VERIFY
  # pass-through). `PKGX_DIR` is in neither that list nor anywhere else in zbk
  # or bottle's sources — the store variable has been `ZPKG_DIR` since the
  # rename (build/build.go:749, cmd/zbk/builder.go:626, bottle/pkgx.go:381).
  #
  # So the substitution ran as `s|/|$PKGX_DIR/|g`: not "replace the store
  # path", but "replace EVERY SLASH", which rewrites every absolute path in
  # `unbound-control-setup` and then deletes the .bak that would have shown it.
  # A build does not fail on it — sed exits 0 — so only the installed script is
  # wrong. Both sides renamed; the right-hand side stays escaped, since what it
  # writes is the literal text `$ZPKG_DIR/` for the installed script to expand.
  script = <<EOT
./configure $ARGS
make -j {{ hw.concurrency }} install

cd {{prefix}}/bin
sed -i.bak -e "s|$ZPKG_DIR/|\$ZPKG_DIR/|g" unbound-control-setup
rm unbound-control-setup.bak
EOT

  env {
    ARGS = [
      "--prefix={{ prefix }}",
      "--sbindir={{ prefix }}/bin",
      "--with-ssl={{ deps.openssl.org.prefix }}",
      "--with-libexpat={{ deps.libexpat.github.io.prefix }}",
    ]
    CFLAGS = "-Werror=implicit-function-declaration"
  }
}
