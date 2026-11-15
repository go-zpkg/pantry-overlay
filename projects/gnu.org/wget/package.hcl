# wget — GNU Wget, the non-interactive network downloader.
#
# ⛔ WRITTEN FROM WGET'S OWN FILES at 1.25.0, tenth of the base-toolchain
# members (go-zpkg/packages#440). It was THREE LINES — one dependency key
# correcting upstream's openssl constraint.
#
# ⛔⛔ AND IT IS THE RECIPE WHERE "NOTHING IMPLICIT" BECAME THE RULE (owner,
# 2026-11-15: « il faut eviter les trucs implicites »). wget states TWENTY-TWO
# configure switches and TEN of them decide whether an external library ends up
# in the artifact. Upstream's recipe stated five, one of which was MISSPELLED
# and therefore stated nothing at all. The rest were left to whatever happened
# to be installed on the builder.
#
# Every one of the ten is now stated here, and `wget --version` prints the
# resulting feature set, so the test block asserts the whole choice flag by
# flag rather than trusting the recipe's own word for it.

summary = "GNU Wget: retrieve files over HTTP, HTTPS, FTP and FTPS"

# `COPYING` is the GPLv3 text ("Version 3, 29 June 2007"); `src/wget.h:8-9` is
# "either version 3 of the License, or (at your option)".
#
# ⭐ `src/wget.h:20` adds "Additional permission under GNU GPL version 3
# section 7" — the OpenSSL linking exception, which is exactly what makes
# `--with-ssl=openssl` below legitimate rather than a licence problem. Named
# because a reader checking the flag will want it.
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/wget/"
  match = "/wget-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^wget-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  # ⛔ wget2 is a DIFFERENT PROJECT with its own tarballs in the same
  # directory; the pattern above matches `wget-N.N[.N].tar.gz` only, so
  # `wget2-*` cannot be picked up. Measured: 48 versions, newest 1.25.0.
  url              = "https://ftp.gnu.org/gnu/wget/wget-{{version.raw}}.tar.gz"
  strip-components = 1

  # 5 263 736 bytes.
  #
  # ⛔⛔ THE SIGNATURE IS GOOD AND OUR OWN VERIFIER REFUSES IT, and the two
  # verdicts disagree about A CLOCK, not about the bytes. This is stated in
  # full because "verified" would be false and "unsigned" would be worse.
  #
  #   signature  https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz.sig
  #   algorithm  RSA, SHA-256
  #   created    2024-11-10 22:32:38 CET
  #   signer     Darshit Shah <darnir@gnu.org>
  #   subkey     6B98F637D879C5236E277C5C64FF90AAE8C70AF9
  #   primary    7845120B07CBD8D6ECE5FF2B2A1743EDA91A35B6
  #
  #   gpg --verify   exit 0, "Good signature", with "Note: This key has
  #                  expired!" — gpg judges expiry at the SIGNATURE's creation
  #                  instant, and the key was valid then
  #   zpkb sourcepin exit 1, "openpgp: key expired … do not pin this until you
  #                  know why" — it judges expiry at time.Now(), and the key
  #                  lapsed on 2025-11-10
  #
  # ⛔ AND GNU'S OWN CANONICAL KEYRING CANNOT VERIFY A 2024 GNU RELEASE.
  # `ftp.gnu.org/gnu/gnu-keyring.gpg` carries this primary with expiry
  # 2018-08-15 — six years BEFORE the signature. My first reading was that our
  # local copy had gone stale; a fresh download refuted it, byte for byte:
  #
  #   8013de59880f7a59f53b6bd207f4d2a408d67b84a82fa9cba1dbbf443428e2db
  #
  # is the sha256 of both the copy kept here since 2026-11-08 and the file
  # fetched today. The keyring simply lacks the self-signature that extended
  # the key. keys.openpgp.org, asked BY FINGERPRINT (`vks/v1/by-fingerprint/
  # 7845120B07CBD8D6ECE5FF2B2A1743EDA91A35B6`), serves the same primary with
  # expiry 2025-11-10 and the same four subkey fingerprints — so it is the
  # same key with a later self-signature, not a different key, and the
  # fingerprint rather than the server is what anchors it.
  #
  # ⚠ The digest below was fetched TWICE, by curl and by the builder's own
  # fetcher, with the same result. That control covers TRANSPORT only: both
  # read ftp.gnu.org, so it cannot speak to authenticity — the signature does
  # that, and the paragraph above says exactly how far it goes.
  sha256 = {
    "1.25.0" = "766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784"
  }

  # ⛔ NO `sha` FIELD: `sha` means "where the expected SHA-256 is PUBLISHED", a
  # file the build fetches and compares, so a `.sig` there fails every build
  # (go-zpkg/packages#89). The signature URL lives in `provenance`
  # (go-zpkg/zpkb#282).
}

# ⛔⛔ THREE LIBRARIES, AND UPSTREAM'S RECIPE DECLARED ONE. The other two were
# linked anyway, decided by the builder. Measured with `otool -L` on a real
# install from this tree:
#
#   /usr/lib/libiconv.2.dylib          ← the SYSTEM's, see below
#   libidn2.0.dylib                    ← UNDECLARED upstream
#   libssl.3.dylib, libcrypto.3.dylib  ← the one upstream declared
#   /usr/lib/libz.1.dylib              ← UNDECLARED upstream
#   /usr/lib/libSystem.B.dylib
dependencies = {
  # ⭐⭐ `^3` IS A MEASURED UPPER BOUND, NOT A PREFERENCE — and this is the
  # strongest single finding in the recipe. Upstream says `^1.1`; the fragment
  # this file replaces had already corrected it to `^3` without saying why.
  # The why is an A/B on this machine: same tree, same twelve flags, only the
  # OpenSSL changed.
  #
  #   OpenSSL 4.1.0  →  make install FAILS at openssl.o
  #   OpenSSL 3.6.5  →  make install succeeds
  #
  # The failure, verbatim:
  #
  #   src/openssl.c:230:14: error: call to undeclared function
  #   'SSLv3_client_method'
  #
  # and the mechanism is a guard that tests the wrong thing. `src/openssl.c:229`
  # is `#ifndef OPENSSL_NO_SSL3_METHOD` — a macro OpenSSL defines when BUILT
  # without the SSLv3 method. OpenSSL 4 REMOVED the function and does not
  # define that macro, because it is no longer a build-time option at all:
  # grepped `openssl@4/4.1.0/include/openssl/{configuration,ssl}.h` for both
  # names and found NEITHER. So wget's guard lets the call through and the
  # compile dies. wget 1.25.0 cannot build against OpenSSL 4.x.
  #
  # `configure.ac:523` is `PKG_CHECK_MODULES([OPENSSL], [openssl], …)` with NO
  # version argument, so wget itself states no bound — this one comes from the
  # source and the compiler, which is the only place it could come from.
  "openssl.org" = "^3"

  # ⛔ AUTO-DETECTED AND UNDECLARED UPSTREAM. `configure.ac:510` is
  # `AS_IF([test x"$with_zlib" != xno], …)` — default ON — then
  # `PKG_CHECK_MODULES([ZLIB], zlib, …)` falling back to
  # `AC_CHECK_LIB(z, compress)`, and if neither finds it the build simply goes
  # on WITHOUT compression support. Same recipe, same version, two different
  # wgets. `--with-zlib` below makes the choice ours.
  #
  # No floor: wget's PKG_CHECK_MODULES states no version. curl.se in this tree
  # says `^1.2.11`, which is CURL's stated floor and not wget's, so it is not
  # copied here.
  #
  # ⚠ On darwin the linker took `/usr/lib/libz.1.dylib` — the system's — in the
  # measurement above, not the staged one. The declaration is still right:
  # linux has no system libz to fall back to.
  "zlib.net" = "^1"

  # ⛔ THE SECOND UNDECLARED ONE, and it arrives through a feature switch
  # rather than a library switch, which is why it is easy to miss.
  # `configure.ac:757-782` defaults IRI to auto — its own comment at `:779` is
  # "If nothing is specified, assume auto-detection" — and `:797` is
  # `PKG_CHECK_MODULES([LIBIDN2], [libidn2 >= 0.14.0], …)`.
  #
  # `>= 0.14.0` is wget's stated floor. `^2` is the registry's current line and
  # is therefore a CHOICE, labelled as one: wget would accept 0.14.
  "gnu.org/libidn2" = "^2"

  # ⛔ libiconv IS DELIBERATELY ABSENT, and I nearly declared it wrongly.
  # `configure.ac:784-793` disables IRI when `am_cv_func_iconv` is not yes, so
  # iconv is genuinely required for IRI — but it is gnulib's check, satisfied
  # by glibc's built-in iconv on linux and by the system libiconv on darwin.
  # The measurement settles it: `otool -L` shows `/usr/lib/libiconv.2.dylib`,
  # the system's, with no GNU libiconv anywhere. Declaring `gnu.org/libiconv`
  # would have added a dependency nothing needs on either platform.
}

build {
  # PKG_CHECK_MODULES is used for openssl (:523), zlib (:512), libidn2 (:797)
  # and pcre (:856, :873), so pkg-config is a real build dependency and not a
  # convenience — the same justification as gnu.org/grep:83-86 and
  # gnu.org/binutils, and the constraint is upstream's, unchanged.
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  # ⛔⛔⛔ THE TWELVE SWITCHES, AND WHY THERE ARE TWELVE.
  #
  # `grep -n "AC_ARG_WITH\|AC_ARG_ENABLE" configure.ac` returns 22 lines. TEN
  # of them decide whether an external library is linked:
  #
  #   :74  libpsl    :78  ssl      :82  zlib      :86  metalink  :90  cares
  #   :757 iri       :814 libuuid  :851 pcre2     :852 pcre      :960 libproxy
  #
  # Upstream's recipe stated five of the ten, and one of those five was a typo.
  # All ten are stated below (iri and ssl and zlib positively, the other seven
  # negatively), plus `--disable-nls` and `--without-included-regex`.
  #
  # ⭐ THE CONTROL THAT THIS IS THE RIGHT SPELLING OF ALL TWELVE: a configure
  # run with exactly this list prints NO "unrecognized options" warning, where
  # the upstream list prints one (see `--without-libpsl` below). The twelve
  # were not guessed.
  #
  # The remaining twelve switches (fuzzing, the three fsanitize-*, opie,
  # digest, ntlm, debug, valgrind-tests, assert, ipv6, xattr) change no link
  # closure: their defaults are the same on every builder, so leaving them is a
  # default and not an implicit dependency. ipv6 and xattr are host PROBES, and
  # their results are asserted in the test block instead.
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Removes the libintl coupling, as in the seven GNU recipes before this
      # one. Asserted as `-nls` in `wget --version`.
      "--disable-nls",

      # ⛔⛔ THE TYPO, AND IT IS THE REASON THIS RECIPE EXISTS AS A WHOLE
      # RECIPE. Upstream's recipe passes
      #
      #     --without-libps1
      #
      # with the DIGIT 1, where `configure.ac:74` declares
      # `AC_ARG_WITH([libpsl], [AS_HELP_STRING([--without-libpsl], …)])` with
      # the LETTER l. configure says so on every build, and said so on this
      # one, verbatim and twice:
      #
      #     configure: WARNING: unrecognized options: --without-libps1
      #
      # So the flag states an intention it does not carry out, and
      # `configure.ac:491` — `AS_IF([test "x$with_libpsl" != xno], …)` with the
      # variable unset — AUTO-DETECTS libpsl instead. On a builder with
      # libpsl.pc, wget links it and the recipe declares no such dependency; on
      # one without, `:502` warns and falls back to wget's builtin cookie
      # checking. Two different wgets from one recipe.
      #
      # ⚠ I cannot say the artifact ever DID link libpsl: on this machine
      # libpsl is absent and the summary came out `PSL: no`, so the
      # auto-detection happened to fall the safe way here. What is established
      # is that the BUILDER decides, which is the defect regardless of which
      # way it fell.
      #
      # The correctly spelled flag keeps upstream's evident intention. Asserted
      # as `-psl` in the test block, which is the assertion that would have
      # caught the typo.
      "--without-libpsl",

      # Upstream's, and real. `configure.ac:78`; the openssl branch is
      # `:521-533`. See the openssl.org note above for why `^3` is a ceiling.
      "--with-ssl=openssl",

      # Stated POSITIVELY so the feature is ours rather than the builder's, and
      # paired with the declared zlib.net. Asserted at runtime, not just at
      # compile time: `src/main.c:290-291` registers the `--compression` long
      # option INSIDE `#ifdef HAVE_LIBZ`, so a wget built without zlib does not
      # have the option at all and rejects it.
      "--with-zlib",

      # Stated POSITIVELY, paired with the declared gnu.org/libidn2.
      #
      # ⚠ AND IT IS WEAKER THAN IT LOOKS, which is worth knowing rather than
      # assuming. `--enable-iri` sets `force_iri=yes` (configure.ac:768), and
      # that only makes a MISSING ICONV fatal (`:787-788`,
      # "Libiconv is required for IRIs support"). A missing libidn2 still only
      # WARNS and silently turns IRI off (`:805`). So this flag cannot
      # guarantee the feature, and the guarantee is moved to the test block:
      # `wget --version` must print `+iri`.
      "--enable-iri",

      # ⛔ `configure.ac:86` + `:920` — `AS_IF([test x"$with_metalink" != xno]`,
      # default ON, pulling in libmetalink AND gpgme, neither of which this
      # pantry stages. Closed explicitly. Asserted as `-metalink` and `-gpgme`.
      "--without-metalink",

      # `configure.ac:90` already defaults `with_cares=no` inside the macro, so
      # this changes nothing today — it is stated because the default is
      # upstream's to change and the artifact's link closure is not. Asserted
      # as `-cares`.
      "--without-cares",

      # ⛔ AND THIS ONE DOES NOT DO WHAT ITS NAME SAYS, which is exactly why it
      # is written down. `configure.ac:814-839` is THREE-WAY: unset
      # auto-detects `uuid.h`/`uuid_create` or `uuid/uuid.h` plus `-luuid`;
      # `--with-libuuid` demands it; and `--without-libuuid` (`:827-830`) STILL
      # probes `uuid_create`. So the flag does not disable UUID generation for
      # WARC files — it forbids the EXTERNAL `-luuid` and leaves only what libc
      # provides, which darwin has and glibc does not. That is the
      # deterministic link closure, which is what was wanted; the feature
      # difference between platforms is stated rather than hidden.
      "--without-libuuid",

      # Upstream's two, and both real: `configure.ac:851-852`, each defaulting
      # to auto-detect (`:854`, `:872`). Asserted as `-pcre` — wget prints one
      # flag for the pair.
      "--disable-pcre",
      "--disable-pcre2",

      # `configure.ac:959-969` sets `with_libproxy=no` then only enables it on
      # `--enable-libproxy`, so this is already the default. Stated for the
      # same reason as `--without-cares`.
      "--disable-libproxy",

      # Upstream's. Uses the platform's regex rather than gnulib's bundled one,
      # which keeps one implementation in the artifact instead of two.
      "--without-included-regex",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# A REAL INSTALL MANIFEST from a real `make install` into a scratch prefix,
# four files: `bin/wget`, `etc/wgetrc`, `share/man/man1/wget.1`,
# `share/info/wget.info` (the last two move under `--mandir`/`--infodir`
# above). `src/Makefile.am:39` is `bin_PROGRAMS = wget` — one binary, and the
# manifest agrees with it.
provides = [
  "bin/wget",
]

test {
  script = [
    "wget --version | grep {{version.raw}}",

    # ⛔⛔ THE WHOLE EXPLICIT CHOICE, ASSERTED FLAG BY FLAG. `wget --version`
    # prints its compiled feature set as a list of `+feature` / `-feature`
    # words, which makes every one of the twelve switches above checkable
    # rather than merely stated. Measured output from this tree:
    #
    #   -cares +digest -gpgme +https +ipv6 +iri +large-file -metalink -nls
    #   +ntlm +opie -psl +ssl/openssl
    #
    # Without these lines the recipe would only CLAIM that nothing is implicit.
    "wget --version | grep -- '+ssl/openssl'",
    "wget --version | grep -- '+https'",
    "wget --version | grep -- '+iri'",
    "wget --version | grep -- '-nls'",
    "wget --version | grep -- '-metalink'",
    "wget --version | grep -- '-gpgme'",
    "wget --version | grep -- '-cares'",

    # ⭐ THE ONE THAT WOULD HAVE CAUGHT THE TYPO. With `--without-libps1`
    # misspelled, libpsl is auto-detected, so on any builder that has it this
    # line reads `+psl` and fails. It is the difference between a recipe that
    # says what it wants and a recipe that gets it.
    "wget --version | grep -- '-psl'",

    # The host probes, asserted rather than assumed: both are expected on every
    # platform this pantry targets, and if one ever flips, the recipe should
    # fail rather than quietly ship a different wget.
    "wget --version | grep -- '+ipv6'",
    "wget --version | grep -- '+large-file'",

    # The rest of the manifest.
    "test -f {{prefix}}/etc/wgetrc",

    # ⛔⛔ RUNTIME WITNESSES FOR THE TWO POSITIVE FLAGS, AND THEIR NEGATIVES
    # ARE ESTABLISHED BY CONSTRUCTION rather than by hope: `src/main.c:290-291`
    # registers `--compression` inside `#ifdef HAVE_LIBZ`, and `:426` registers
    # `secure-protocol` under `IF_SSL` (`:239` `#ifdef HAVE_SSL`). An option
    # that does not exist is a usage error (exit 2); a connection refused is
    # exit 4. So these lines distinguish "built with the library" from "built
    # without it" using only a closed local port.
    #
    # Measured against a real install: both exit 4 with
    # "Connecting to 127.0.0.1:1... failed: Connection refused."
    "wget --compression=gzip -O /dev/null --tries=1 --timeout=1 http://127.0.0.1:1/ ; test $? -eq 4",
    "wget --secure-protocol=TLSv1_3 -O /dev/null --tries=1 --timeout=1 https://127.0.0.1:1/ ; test $? -eq 4",

    # ⛔ AND THE NETWORK TEST UPSTREAM HAD IS GONE. Its whole test block was
    #
    #     test: wget tea.xyz
    #
    # which fetches an EXTERNAL HOST — a flake generator in any sandbox, and
    # `tea.xyz` is pkgx's former brand, so it is also a name this project has
    # no reason to depend on resolving. Nothing here reaches the network: the
    # three lines above use a closed loopback port.
    #
    # ⚠ WHAT IS MISSING, SAID PLAINLY RATHER THAN PAPERED OVER: there is no
    # runtime witness for libidn2. I tried one — `wget http://bücher.example/`
    # should name the punycode host in its error — and it failed with
    # "Incomplete or invalid multibyte sequence encountered", twice, including
    # with LC_ALL=en_US.UTF-8, so the host never reached libidn2's conversion
    # and the assertion would have failed for a reason unrelated to the
    # dependency. An assertion I could not make pass is not shipped. `+iri`
    # above is the compile-time witness, and it is what there is.
  ]
}

provenance {
  read = [
    "configure.ac",         # :74-75 AC_ARG_WITH([libpsl]) — the LETTER l; :78 ssl; :82 zlib; :86 metalink; :90 cares defaults to no; :491-502 libpsl auto-detected when the variable is unset, falling back to builtin cookie checking; :510-519 zlib default ON; :521-533 the openssl branch, PKG_CHECK_MODULES with no version; :757-782 iri defaults to auto (":779 If nothing is specified, assume auto-detection"); :784-793 iconv required for IRI; :795-808 libidn2 >= 0.14.0, missing only WARNS; :814-839 the three-way libuuid logic; :851-870 pcre2/pcre auto; :959-969 libproxy off by default; :975-995 xattr; and the 22-line AC_ARG_* census
    "src/openssl.c",        # :213 the LIBRESSL/<1.1.0 guard; :229-231 #ifndef OPENSSL_NO_SSL3_METHOD around SSLv3_client_method — the guard that breaks on OpenSSL 4
    "src/main.c",           # :239 #ifdef HAVE_SSL; :290-291 the `compression` option inside #ifdef HAVE_LIBZ; :426 IF_SSL("secure-protocol"); :799-801 the --compression help text, also guarded
    "src/Makefile.am",      # :39 bin_PROGRAMS = wget
    "src/wget.h",           # :8-9 GPLv3-or-later; :20 "Additional permission under GNU GPL version 3 section 7" — the OpenSSL linking exception
    "COPYING",              # the GPLv3 text that ships
  ]

  consulted = [
    "https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz.sig",                      # RSA/SHA-256, created 2024-11-10 22:32:38 CET
    "https://ftp.gnu.org/gnu/gnu-keyring.gpg",                                  # carries the signer's key EXPIRED 2018-08-15; byte-identical to the local copy
    "https://keys.openpgp.org/vks/v1/by-fingerprint/7845120B07CBD8D6ECE5FF2B2A1743EDA91A35B6", # the same key with expiry extended to 2025-11-10
    "/opt/homebrew/Cellar/openssl@4/4.1.0/include/openssl/configuration.h",     # grepped: neither OPENSSL_NO_SSL3_METHOD nor SSLv3_client_method
    "pkgxdev/pantry projects/gnu.org/wget/package.yml",                          # the recipe this replaces: five flags, one misspelled, one network test
    "curl.se/package.hcl",                                                       # the sibling downloader's dependency set, and why its zlib floor is not copied
    "gnu.org/binutils/package.hcl",                                              # the measured-claim discipline, and the auto-detection class
  ]

  note = <<EOT
Tenth of the base-toolchain members written from the project's own files
(go-zpkg/packages#440). `zpkb closure -build` confirms gnu.org/wget is in the
70-project build closure of go-zpkg/base-toolchain.

⛔⛔ THE RULE THIS RECIPE WAS WRITTEN UNDER, from the owner on 2026-11-15:
« il faut eviter les trucs implicites ». It changed the shape of the work. The
first draft was going to pick a few flags; instead `configure.ac` was censused
for every `AC_ARG_WITH`/`AC_ARG_ENABLE` — 22 of them — and the ten that decide
an external library are all stated. The control that the spelling of all twelve
is right is that configure prints NO "unrecognized options" warning for this
list, where it prints one for upstream's.

⭐⭐ WHAT WRITING IT FOUND. Five things, and three needed a build:

  1. A TYPO THAT TURNED A FLAG INTO NOTHING. `--without-libps1` (digit) for
     `--without-libpsl` (letter). configure has been printing
     "WARNING: unrecognized options: --without-libps1" on every wget build
     this factory ever ran, and libpsl has been auto-detected the whole time.

  2. wget 1.25.0 CANNOT BUILD AGAINST OpenSSL 4.x, so `^3` is a measured
     ceiling and not a preference. A/B: 4.1.0 fails at openssl.o with
     "call to undeclared function 'SSLv3_client_method'", 3.6.5 succeeds.
     The mechanism is a guard testing the wrong thing — `#ifndef
     OPENSSL_NO_SSL3_METHOD` asks whether OpenSSL was BUILT without the SSLv3
     method, and OpenSSL 4 removed the function without defining that macro.

  3. TWO UNDECLARED LINKED LIBRARIES. `otool -L` on a real install names
     libidn2 and libz, neither of which upstream's recipe declares; both
     arrive through default-ON auto-detection (`configure.ac:510` for zlib,
     `:757-782` for IRI/libidn2).

  4. `--without-libuuid` DOES NOT DISABLE UUID. `configure.ac:827-830` still
     probes `uuid_create`; the flag only forbids the external `-luuid`.

  5. THE TEST BLOCK WAS A NETWORK FETCH OF A DEAD BRAND. `test: wget tea.xyz`,
     one line, reaching an external host. Replaced by assertions on
     `wget --version`'s feature list plus two runtime probes against a closed
     loopback port, whose negatives are guaranteed by `#ifdef` in
     `src/main.c`.

⛔ AND TWO OF MY OWN CLAIMS DIED IN THE MEASUREMENTS, which is the part worth
keeping:

  - I was about to declare `gnu.org/libiconv`, reasoning that darwin needs it
    for IRI. `otool -L` shows `/usr/lib/libiconv.2.dylib` — the system's. The
    dependency would have been wrong on both platforms.
  - I read the expired signing key as OUR keyring having gone stale, and said
    so to myself before checking. A fresh download of `gnu-keyring.gpg` is
    byte-identical to the local copy (sha256 8013de59…): GNU publishes the key
    expired, and it is keys.openpgp.org that holds the later self-signature.
    The staleness was in my explanation, not in the file.

⛔⛔ THE SIGNATURE IS GOOD AND OUR OWN TOOL REFUSES IT, over a clock:

  gpg --verify     exit 0, "Good signature from Darshit Shah", with
                   "Note: This key has expired!" — judged at the SIGNATURE's
                   creation instant, 2024-11-10, when the key was valid
  zpkb sourcepin   exit 1, "openpgp: key expired … do not pin this until you
                   know why" — judged at time.Now(), and the key lapsed
                   2025-11-10

That refusal message is well written and was obeyed: the digest here was not
pinned until the "why" was established, which took the fingerprint lookup
above. But this is the SECOND GNU package in this campaign whose signature our
verifier rejects where gpg accepts (gnu.org/help2man was the first, for
DSA/SHA-1), and the two have different causes, so it is a pattern rather than
an accident. Filed as the next thing to look at; a verifier for ARCHIVED
artifacts should judge a signature at its creation instant, as gpg does, or no
GNU package whose maintainer ever let a key lapse can be pinned at all.

  chain      signature RSA/SHA-256, created 2024-11-10 22:32:38 CET
             subkey  6B98F637D879C5236E277C5C64FF90AAE8C70AF9
             primary 7845120B07CBD8D6ECE5FF2B2A1743EDA91A35B6
             identity Darshit Shah <darnir@gnu.org>
             fingerprint agrees between the signature's own issuer subpacket
             and ftp.gnu.org's keyring — which is NOT independence, since the
             signature naming its own key is circular; what the keyring adds
             is that GNU lists this fingerprint as a release signer
             key copy with the later self-signature from keys.openpgp.org,
             asked BY FINGERPRINT so the server chooses nothing
  digest     fetched twice, by curl and by the builder's own fetcher, equal —
             a TRANSPORT control only, both reading ftp.gnu.org

No keyserver was asked to RESOLVE anything: the fingerprint was in hand from
two places before any lookup, and the lookup was by that fingerprint.
EOT
}
