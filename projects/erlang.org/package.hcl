# erlang.org — Erlang/OTP: the BEAM virtual machine, compiler and the OTP
# libraries. New in go-zpkg/packages#440: rabbitmq.com depends on it
# (`"erlang.org" = "^27"`) and no recipe existed.
#
# ⛔ WRITTEN FROM ERLANG/OTP'S OWN FILES, at 29.1.2, with 28.5.0.8 and 27.3.4.19
# also pinned (the three series the release page offers), because RabbitMQ asks
# for a major that is not always the newest.

summary = "Erlang/OTP: the BEAM virtual machine, compiler and libraries for fault-tolerant concurrent systems"

# LICENSE.txt:2-3 is the Apache License, Version 2.0 text.
license = "Apache-2.0"

versions {
  # Tags are OTP-29.1.2, OTP-28.5.0.8 (four components) and the historic
  # OTP-R16B03 style, which the strip leaves non-numeric.
  github = "erlang/otp"
  strip  = "/^OTP-/"
}

dependencies = {
  # crypto, ssl and ssh need OpenSSL (HOWTO/INSTALL.md:82-88). ncurses is the
  # termcap library of the new shell (:54-57).
  "invisible-island.net/ncurses" = "^6"
  "openssl.org"                  = "^3"
}

distributable {
  # THE STORED RELEASE ASSET, not the generated tag archive: otp_src_<v>.tar.gz
  # is uploaded to each release and is the "pre-built source release" with the
  # bootstrap beam files inside, so no Erlang is needed to build Erlang
  # (HOWTO/INSTALL.md:683-693).
  url              = "https://github.com/erlang/otp/releases/download/OTP-{{version}}/otp_src_{{version}}.tar.gz"
  strip-components = 1

  # Each digest is the one in the release's own SHA256.txt AND the one of an
  # independent download of the asset (shasum -a 256 on the fetched file):
  # 29.1.2 is 106854380 bytes, 28.5.0.8 is 105458074, 27.3.4.19 is 101742958.
  # Every asset also has a .sigstore bundle beside it; the Sigstore bundles
  # were NOT verified (that needs cosign).
  sha256 = {
    "29.1.2"    = "c79966661e35fe4aff8ec003db63682e3b33b10b672220d51bf93c0a9244b049"
    "28.5.0.8"  = "8a696e15bcbe5d57197b1f4c03c92d415f9fd9af70f9222a05911c8a5463cba6"
    "27.3.4.19" = "866307e64e245e86bee15b3807030a998e59873d7480d6fae1e40b432a3d12b7"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "perl.org"     = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ APPLICATIONS TURNED OFF, each by name (HOWTO/INSTALL.md:417-422:
      # `--without-$app`, no automatic dependency handling).
      #   wx       needs wxWidgets (:101-108), no recipe;
      #   odbc     needs an ODBC driver manager, no recipe;
      #   jinterface needs a JDK: `--without-javac` (:372-374);
      #   megaco   the flex scanner needs flex headers (:99-100);
      #   observer, debugger, et  GUI tools that sit on wx.
      "--without-wx",
      "--without-odbc",
      "--without-javac",
      "--without-megaco",
      "--without-observer",
      "--without-debugger",
      "--without-et",

      # OpenSSL from the tree: `--with-ssl=PATH` (:380) is REQUIRED so that a
      # missing OpenSSL is an error and not a silently skipped crypto
      # (:378-379: `--without-ssl` is the only way to omit it). The rpath
      # (:389) lets the installed crypto NIF find it. Dynamic linking is the
      # default (:375-377); named.
      "--enable-dynamic-ssl-lib",

      # The bundled zlib and zstd are the default (:463-468); named so that a
      # system copy on the builder can never be picked up.
      "--enable-builtin-zlib",
      "--enable-builtin-zstd",

      # :441-442, :453-456 defaults kept; :445 year2038 is left ON, which
      # makes configure fail rather than build a clock that stops in 2038.
    ]
  }

  script = [
    {
      run = <<EOT
set -eu
./configure $ARGS \
  "--with-ssl={{deps.openssl.org.prefix}}" \
  "--with-ssl-rpath={{deps.openssl.org.prefix}}/lib" \
  "CPPFLAGS=-I{{deps.invisible-island.net/ncurses.prefix}}/include -I{{deps.invisible-island.net/ncurses.prefix}}/include/ncursesw" \
  "LDFLAGS=-L{{deps.invisible-island.net/ncurses.prefix}}/lib -Wl,-rpath,{{deps.invisible-island.net/ncurses.prefix}}/lib"
EOT
    },
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/erl",
  "bin/erlc",
  "bin/escript",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/erl\"",
    "test -x \"{{prefix}}/bin/erlc\"",
    {
      run = <<EOT
set -eu
rel=$("{{prefix}}/bin/erl" -noshell -eval 'io:put_chars(erlang:system_info(otp_release)), halt().')
case "{{version}}" in
  "$rel"|"$rel".*) ;;
  *) echo "otp_release is $rel, expected the major of {{version}}" >&2; exit 1 ;;
esac
EOT
    },

    # crypto actually loaded OpenSSL: a build without it would still run `erl`.
    "\"{{prefix}}/bin/erl\" -noshell -eval 'true = is_binary(crypto:hash(sha256, <<>>)), halt().'",
    "\"{{prefix}}/bin/erl\" -noshell -eval '{ok, _} = application:ensure_all_started(ssl), halt().'",
  ]
}

provenance {
  read = [
    "HOWTO/INSTALL.md",  # :54-57 termcap; :82-108 OpenSSL, JDK, flex, wx; :354-474 configure options; :417-422 --without-$app; :683-693 the bootstrap beams; :733-749 install
    "LICENSE.txt",       # :2-3 Apache License 2.0
    "OTP_VERSION",       # 29.1.2
    "https://github.com/erlang/otp/releases/download/OTP-29.1.2/SHA256.txt",
    "https://github.com/erlang/otp/releases/expanded_assets/OTP-29.1.2",  # the asset list: otp_src, doc tarballs, SHA256.txt, MD5.txt, .sigstore bundles
  ]

  note = <<EOT
NOT BUILT. NOT RUN. Written from the project's own files; the configure, the
make and the test block have not been run on either platform.

Open points, stated rather than hidden:
  - The Sigstore bundles beside each asset were not verified. The second
    witness is the release's SHA256.txt plus an independent download.
  - The application names given to --without-* (wx, odbc, megaco, observer,
    debugger, et) follow HOWTO/INSTALL.md:417-422's rule, and each exists as
    lib/<app> in the 29.1.2 tree (listed). That configure accepts every one was
    not run.
  - ncurses is wired through CPPFLAGS and LDFLAGS; whether OTP's termcap probe
    prefers libncursesw or libncurses on this recipe's layout is unverified.
  - zlib and zstd are the bundled copies (--enable-builtin-*), a choice, not a
    finding: nothing in the tree builds Erlang against the tree's zlib.
EOT
}
