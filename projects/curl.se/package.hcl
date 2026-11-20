# curl.se — now a standalone recipe, written from curl's own files at 8.23.0
# (go-zpkg/packages#431). It was one of the five fragments `zpkb closure -build
# -require-standalone go-zpkg/base-toolchain` (zpkb v0.87.0) still named on
# 2026-11-20: "states no distributable, no build".
#
# ⭐⭐ WHAT COMPLETING IT FOUND, in order of how much it changes the artifact:
#
#   1. THE TRUST STORE WAS THE BUILDER'S. With no --with-ca-* option, configure
#      scans the BUILDER's filesystem for a CA bundle and compiles in the first
#      path that exists — a Debian builder bakes the Debian path, and a
#      consumer on another distribution, or on a FROM scratch image, verifies
#      against a file that is not there. `curl.se/ca-certs` was declared and
#      wired to nothing. See the CA paragraph in `build`.
#   2. libpsl was LINKED AND UNDECLARED, because curl requires it by default.
#      It was first refused (--without-libpsl), as a stated downgrade of cookie
#      scoping. ⭐ REVERSED 2026-11-20 on the owner's decision, « il faut que
#      ça fonctionne »: libpsl is declared and named. The cost that justified
#      the refusal (77 → 93 projects) came from upstream's libpsl recipe, not
#      from libpsl — see `dependencies`.
#   3. Four optional libraries are probed and taken if present: brotli, zstd,
#      libidn2 and LDAP. libidn2 is now DECLARED and named (it arrives with
#      libpsl anyway); the other three are closed below, with the line that
#      makes each miss silent.
#
# The paragraphs that follow predate this completion and are kept: they are
# the versions audit, and it still holds.
#
# ⛔⛔ SECURITY: THIS RECIPE WAS CAPPED AT curl 8.17.0 BY AN `ignore` BLOCK
# WHOSE STATED REASON THIS VERY FRAGMENT ALREADY SATISFIES.
#
# Upstream's versions block reads:
#
#   # 8.18 requires opensslv3
#   # TODO: make another package for curl with openssl3
#   ignore:
#     - /8\.1[8-9]\..*/
#     - /8\.2\d\..*/
#     - /9\.\d+\.\d+/
#
# The reason is correct and was verified in curl's own files, not taken from the
# comment: `m4/curl-openssl.m4:286` tests
#
#   #if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
#
# and `:293` is `AC_MSG_ERROR([OpenSSL 3.0.0 or greater required.])`.
#
# ⭐ But `openssl.org = "^3"` below — which this fragment has carried since it
# corrected upstream's `^1.1` — resolves to the newest 3.x, i.e. ≥ 3.0.0. The
# condition the cap exists for is met. The cap is not.
#
# ⛔⛔ AND THE COST IS NOT STALENESS, IT IS CVEs. curl's newest release is
# **8.23.0** (99 releases read from the GitHub API), so the recipe is SIX
# minors behind on a package whose whole job is to fetch things off the
# network. curl.se/docs/vuln-8.17.0.html lists 61 advisories that affect
# 8.17.0 and are first fixed in 8.18.0 or later.
#
# ⚠ The 61 is a COUNT FROM A LISTING, derived by reading the page's "Last
# affected" column, which is not the same as a stated "fixed in". One was
# verified on its own advisory page instead of trusting the derivation, and it
# is the worst of them:
#
#   CVE-2026-92392  HTTP/2 upload Use-After-Free
#   Severity: High (CWE-416)
#   "Affected versions: curl 8.12.0 to and including 8.22.0"
#   "Not affected versions: curl < 8.12.0 and >= 8.23.0"
#
# So 8.17.0 is inside the affected range and 8.23.0 is where it stops, stated
# by the page in the negative. ⛔ That page's own `Fixed-in:` field is a COMMIT
# URL, not a version — which is why the other 60 are reported here as derived
# rather than as read.

dependencies = {
  "curl.se/ca-certs" = "*"
  "nghttp2.org"      = "*"

  # ⛔ NOT WIDENED TO `^4`, DELIBERATELY. openssl.org resolves to 4.1.0 as its
  # newest, and curl states only a ≥ 3.0.0 floor, so `^4` would satisfy curl's
  # configure. But gnu.org/wget 1.25.0 FAILS to compile against OpenSSL 4.1.0
  # (measured in go-zpkg/recipes#120: `src/openssl.c:230` calls
  # `SSLv3_client_method`, which OpenSSL 4 removed), so "the floor is met" is
  # not evidence that a major works. curl against OpenSSL 4 has not been
  # measured here, and an unmeasured widening in a TLS dependency is the last
  # place to guess. `^3` is what the cap removal needs and all it needs.
  "openssl.org" = "^3"

  "zlib.net" = "^1.2.11"

  # ⭐⭐ libpsl IS DECLARED. It was refused until 2026-11-20 as a measured
  # downgrade, and the owner reversed that: « il faut que ça fonctionne ». The
  # history is kept because the measurement that justified the refusal was
  # right about upstream and wrong about libpsl.
  "rockdaboot.github.io/libpsl" = "*"

  # Named below with --with-libidn2, so curl converts internationalised host
  # names. libpsl already brings libidn2 into curl's closure, so declaring it
  # here costs nothing and says what it is for.
  "gnu.org/libidn2" = "*"

  # curl REQUIRES libpsl unless told otherwise, as a fatal error:
  # configure.ac:2277 defaults OPT_LIBPSL=off ("compiler & linker defaults"),
  # :2324 probes, and :2340-2341 is
  #
  #   if test "$USE_LIBPSL" != "1"; then
  #     AC_MSG_ERROR([libpsl libs and/or directories were not found!])
  #
  # with NO `!= off` guard — unlike brotli (:1624) and zstd (:1714), whose
  # misses are silent. So upstream's curl, which declares no libpsl, builds
  # only because the builder happens to have one, and links it. That is why
  # `rockdaboot.github.io/libpsl` was among the 14 soname providers that
  # `zpkb closure -implicit go-zpkg/base-toolchain` named on 2026-11-19 as "no
  # recipe declares it": curl's auto-detection, leaking.
  #
  # So the edge had to become explicit one way or the other, and the first
  # draft of this recipe DECLARED it. Measured before committing, with zpkb
  # v0.87.0's `closure -build -require-standalone go-zpkg/base-toolchain`:
  #
  #   without libpsl   77 project(s); 52 standalone, 5 fragments, 20 absent
  #   with libpsl      93 project(s); 53 standalone, 8 fragments, 32 absent
  #
  # and libpsl's OWN build closure is 85 projects, 31 of them absent from this
  # tree. The sixteen it adds include haskell.org, haskell.org/cabal,
  # pandoc.org and deno.land. ⚠ The first draft's estimate — "ICU, meson,
  # ninja, pkg-config and python" — was off by most of that; it is why this is
  # measured rather than predicted.
  #
  # ⭐ WHY THAT NUMBER NO LONGER APPLIES: it was UPSTREAM's libpsl recipe — meson,
  # ninja, python and `-Druntime=libicu` — that carried those projects. Our
  # rockdaboot.github.io/libpsl builds the maintainer's tarball with its own
  # autotools `configure` and its pre-generated DAFSA data (no python), with
  # libidn2 as the IDNA runtime (no ICU). Its new dependencies are
  # gnu.org/libunistring and nothing else absent; the measured closure is in
  # the pull request that reversed this.
  #
  # What the refusal cost, kept for the record: without libpsl, curl stops
  # checking cookie domains against the public suffix list, so a site could
  # set a cookie for a public suffix such as `co.uk`. The test below now
  # asserts PSL is PRESENT.
}

# ⚠ CARRIED IN FULL, because an overlay list REPLACES rather than merges
# (recipefile/overridden_test.go: "a list must replace"). `github` and `strip`
# are upstream's, unchanged; only the ignore list differs, and the difference
# is the two patterns that are gone.
versions {
  github = "curl/curl/releases"
  strip  = "/^curl /"

  ignore = [
    # ⛔ `/8\.1[8-9]\..*/` and `/8\.2\d\..*/` ARE REMOVED. They are what capped
    # the recipe at 8.17.0 for an OpenSSL 3 requirement that `openssl.org ^3`
    # above already satisfies. Measured A/B: 91 versions resolving with them,
    # newest 8.17.0; without them, the newest is 8.23.0.
    #
    # ⭐ `/9\.\d+\.\d+/` IS KEPT, and that is a decision rather than an
    # oversight. No curl 9 exists yet — the newest of 99 releases is 8.23.0 —
    # so the pattern guards a major version bump that nobody has read. Removing
    # it would let a future curl 9.0.0 resolve the day it ships, into a recipe
    # whose flags and dependencies were written for 8.x. A major deserves its
    # own reading; the 8.x line needed only its reason checked.
    #
    # ⛔ And upstream's "TODO: make another package for curl with openssl3" is
    # now moot rather than pending: the second package it proposes is what this
    # fragment already is.
    "/9\\.\\d+\\.\\d+/",
  ]
}

distributable {
  # The project's own download area, where each archive has an `.asc` beside
  # it (curl.se/download.html lines 149-161 link one per format).
  url              = "https://curl.se/download/curl-{{version.raw}}.tar.xz"
  strip-components = 1

  # 2990916 bytes. Recorded with `zpkb sourcepin --sig auto` and confirmed by a
  # second, independent fetch-and-hash (`curl --fail` + `shasum -a 256`). The
  # signature chain is in provenance.note.
  sha256 = {
    "8.23.0" = "8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # ⛔ NOT OPTIONAL, AND ITS ABSENCE WOULD FAIL FOR THE WRONG REASON.
    # `--with-nghttp2=PATH` below locates nghttp2 through its pkg-config FILE
    # (configure.ac:3127 sets want_nghttp2_pkg_config_path=$OPT_H2/lib/pkgconfig)
    # and :3162 is fatal when none is read — so without the pkg-config PROGRAM
    # every build would die on "could not find libnghttp2 pkg-config file"
    # while libnghttp2 sat right there.
    "freedesktop.org/pkg-config" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # TLS. curl selects no backend by default — configure.ac:245-301 sets
      # every OPT_<backend>=no — so one must be named, and the floor is the
      # one this fragment already verified: m4/curl-openssl.m4:286 and :293.
      "--with-openssl={{deps.openssl.org.prefix}}",

      # ⭐ Loud when given a path: :3125 sets want_nghttp2="yes", and :3162 is
      # an AC_MSG_ERROR on a miss.
      "--with-nghttp2={{deps.nghttp2.org.prefix}}",

      # ⛔⛔ ZLIB CANNOT BE MADE LOUD BY ANY FLAG, so the test is the guard.
      # configure.ac:1437-1545 has no AC_MSG_ERROR at all: a miss with a path
      # given ends in `AC_MSG_WARN([configure found only the libz …])` (:1518,
      # :1525) and continues. Without a path it is worse — :1479 falls back to
      # probing /usr/local. Naming the prefix removes that fallback; it cannot
      # make a miss fail. The `curl -V` assertion below can.
      "--with-zlib={{deps.zlib.net.prefix}}",

      # Required by default and fatal on a miss (:2340-2341). With a PATH,
      # :2306-2310 takes -L/-I from it instead of from pkg-config, so the libpsl
      # linked is the declared one.
      "--with-libpsl={{deps.rockdaboot.github.io/libpsl.prefix}}",

      # ⛔ libidn2 WITH A PATH, AND A MISS IS STILL ONLY A WARNING: :2995-2999
      # takes the path, but :3088 answers a failed link with
      # AC_MSG_WARN([Cannot find libidn2]) and :3093 turns IDN off. No flag makes
      # that fatal, so the `curl -V` test below asserts IDN is present.
      "--with-libidn2={{deps.gnu.org/libidn2.prefix}}",

      # ⛔ THE FOUR SILENT PROBES, each of which links a library this recipe
      # does not declare if the builder happens to have it, and skips it in
      # silence if not — so the artifact would vary by builder:
      #
      #   brotli   :1558 OPT_BROTLI=off; :1595 "no --with-brotli option given,
      #            check default places"; :1624 errors only `!= xoff`
      #   zstd     :1656 OPT_ZSTD=off; :1714 errors only `!= xoff`
      #   libidn2  :2965 OPT_IDN="default"; :2983-2987 `want_idn="yes"` and
      #            "(assumed) yes"; a miss sets want_idn="no" (:3093)
      #   LDAP     :2615 OPT_LDAP=off; a miss quietly defines
      #            CURL_DISABLE_LDAP (:2695, :2713)
      #
      # ⚠ `off` READS LIKE "disabled" AND MEANS "PROBE". The comment above
      # brotli says so — "Default to compiler & linker defaults" — and the
      # case arm at :1594-1595 confirms it. Every one of these was read off its
      # block rather than inferred from the word.
      #
      # libidn2 is now declared and named above. The other three are closed
      # rather than declared: adding them to a base-toolchain member is a
      # decision for its own pull request.
      "--without-brotli",
      "--without-zstd",
      "--disable-ldap",

      # ⛔⛔ THE TRUST STORE. acinclude.m4:1081-1114, with no --with-ca-*
      # option and not cross-compiling:
      #
      #   for a in /etc/ssl/certs/ca-certificates.crt \
      #            /etc/pki/tls/certs/ca-bundle.crt \
      #            /usr/share/ssl/certs/ca-bundle.crt \
      #            /usr/local/share/certs/ca-root-nss.crt \
      #            /etc/ssl/cert.pem …; do
      #     if test -f "$a"; then ca="$a"; break; fi
      #
      # — the BUILDER's filesystem — and :1145-1147 compiles the winner in as
      # CURL_CA_BUNDLE. A Debian builder bakes the Debian path; a consumer on
      # Fedora, macOS or a FROM scratch image verifies against a file that is
      # not there. And `curl.se/ca-certs`, declared above, was wired to none
      # of it.
      #
      # ⛔ AND ONE FLAG IS NOT ENOUGH. With only --without-ca-bundle,
      # want_capath stays `unset`, :1113 sets check_capath=/etc/ssl/certs, and
      # :1131 bakes that DIRECTORY as CURL_CA_PATH whenever the builder has
      # hashed certificates there — which Debian and Ubuntu do. Both flags are
      # needed to reach the branch (:1080-1114) that bakes nothing at all.
      "--without-ca-bundle",
      "--without-ca-path",

      # ⭐ AND THE STORE COMES FROM THE RUNTIME ENVIRONMENT INSTEAD. ca-certs
      # is consumed through `SSL_CERT_FILE: ${{prefix}}/ssl/cert.pem`, set when
      # a program RUNS (read from the pantry's curl.se/ca-certs, consulted).
      # Two readers honour it:
      #
      #   - the curl TOOL reads CURL_CA_BUNDLE, SSL_CERT_DIR and SSL_CERT_FILE
      #     itself: src/tool_operate.c:2273-2289;
      #   - LIBCURL reads only a compiled-in bundle (lib/vtls/vtls_config.c:297),
      #     so with none compiled in it needs this flag: CURL_CA_FALLBACK makes
      #     an empty store call X509_STORE_set_default_paths
      #     (lib/vtls/openssl.c:3081-3088), which is OpenSSL's documented
      #     reader of SSL_CERT_FILE. ⚠ That last step is OpenSSL's behaviour as
      #     documented, not read from OpenSSL's source in this change.
      #
      # ⚠ NOT --with-ca-embed, though acinclude.m4:1184 offers it and it would
      # embed the bundle's bytes rather than a path. It covers the curl TOOL
      # only, not libcurl; it needs ca-certs staged at BUILD time, which
      # deepens the ca-certs ⇄ curl.se cycle; and :1208 makes a missing perl
      # a WARNING that skips the embed in silence.
      "--with-ca-fallback",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ ONLY bin/curl. curl installs three entry points — src/Makefile.am:49
# `bin_PROGRAMS = curl`, Makefile.am:78 `bin_SCRIPTS = curl-config`, and
# scripts/Makefile.am:33 `dist_bin_SCRIPTS = wcurl` — and the last two are
# shell scripts. go-zpkg/zpkb#500 is open on exactly that: a `provides` naming
# an interpreter script is a promise the artifact cannot keep, and on a FROM
# scratch image there is no sh. Both are installed; neither is promised.
provides = [
  "bin/curl",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/curl\"",
    "test -f \"{{prefix}}/include/curl/curl.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/libcurl.pc\"",

    # ⛔⛔ THE REGRESSION TEST FOR EVERY CHOICE ABOVE, read from the binary's
    # own report of what it was built with. `curl -V` prints the libraries on
    # its first line and the features on another, so one invocation answers
    # all of them — including zlib, which configure cannot be made to fail
    # on, and which this is therefore the ONLY check for.
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/curl" -V > v.txt
cat v.txt
head -n 1 v.txt > libs.txt
grep '^Features:' v.txt > feat.txt
grep '^Protocols:' v.txt > prot.txt
for want in OpenSSL/ zlib/ nghttp2/; do
  grep -q "$want" libs.txt || { echo "curl was not built with $want" >&2; exit 1; }
done
# PSL and IDN are now PRESENCES: PSL cannot be missing without configure
# failing, but IDN can (:3088 only warns), so this is libidn2's only guard.
for want in HTTP2 libz SSL PSL IDN; do
  grep -qw "$want" feat.txt || { echo "curl lacks the $want feature" >&2; exit 1; }
done
grep -q "libpsl/" libs.txt || { echo "curl -V does not name libpsl" >&2; exit 1; }
grep -q "libidn2/" libs.txt || { echo "curl -V does not name libidn2" >&2; exit 1; }
# The closed probes, asserted as ABSENCES: a builder that has the library
# would otherwise link it.
for gone in brotli zstd; do
  if grep -qw "$gone" feat.txt; then echo "curl links $gone, which this recipe closed" >&2; exit 1; fi
done
if grep -qw ldap prot.txt; then echo "curl speaks LDAP, which this recipe closed" >&2; exit 1; fi
EOT
    },

    # ⛔⛔ AND THE TRUST STORE IS NOT THE BUILDER'S. `curl-config --ca` prints
    # the compiled-in CA bundle, which must be EMPTY: the store comes from the
    # runtime environment. A non-empty answer is a builder's filesystem path
    # inside the artifact — the defect the two --without-ca-* flags remove.
    {
      run = <<EOT
set -eu
ca=$("{{prefix}}/bin/curl-config" --ca)
if [ -n "$ca" ]; then
  echo "curl has a CA bundle path compiled in: $ca" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                 # :245-301 TLS backends default off; :1437-1545 zlib, no fatal miss, the /usr/local fallback; :1558-1627 brotli and the meaning of `off`; :1656-1716 zstd; :2277-2341 libpsl and its unconditional error; :2615-2716 LDAP; :2930-3093 AppleIDN (opt-in) and libidn2 (probed); :3101-3162 nghttp2; :3647-3653 nghttp3 forced off without ngtcp2
    "acinclude.m4",                 # :1021-1177 CURL_CHECK_CA_BUNDLE — the builder-filesystem scan, the capath trap, --with-ca-fallback; :1184-1208 --with-ca-embed and its perl warning
    "m4/curl-openssl.m4",           # :286 and :293, the OpenSSL >= 3.0.0 floor this fragment already verified
    "lib/vtls/openssl.c",           # :3081-3088 what CURL_CA_FALLBACK does
    "lib/vtls/vtls_config.c",       # :297 libcurl reads only a compiled-in bundle
    "src/tool_operate.c",           # :2273-2289 the tool reads CURL_CA_BUNDLE, SSL_CERT_DIR, SSL_CERT_FILE
    "src/Makefile.am",              # :49 bin_PROGRAMS = curl
    "Makefile.am",                  # :78 bin_SCRIPTS = curl-config
    "scripts/Makefile.am",          # :33 dist_bin_SCRIPTS = wcurl
    "https://curl.se/download.html", # the .asc beside each archive, and the "PGP Key" link that leads to the signer
  ]

  consulted = [
    # Read for TWO facts, neither copied: how ca-certs is meant to be consumed
    # (a runtime `SSL_CERT_FILE` env, which the CA flags above rely on), and
    # that its build fetches the bundle with `curl -k` from inside the build
    # script — TLS verification disabled, no digest — which is
    # go-zpkg/zpkb#487's shape and why ca-certs has no recipe of ours yet.
    "pkgxdev/pantry projects/curl.se/ca-certs/package.yml",
    # Read for what upstream's libpsl depends on, which is what made declaring
    # it look expensive. Our own libpsl recipe is written from libpsl's files.
    "pkgxdev/pantry projects/rockdaboot.github.io/libpsl/package.yml",
  ]

  note = <<EOT
The source archive is signed, and the signature was checked when this digest
was recorded rather than at every build.

  signature  https://curl.se/download/curl-8.23.0.tar.xz.asc
  key        https://daniel.haxx.se/mykey.asc
  identity   Daniel Stenberg <daniel@haxx.se>
  signed at  2026-10-14T05:55:16Z
  fingerprint 27EDEAF22F3ABCEB50DB9A125CC908FDB71E12C2

The same signer and the same chain as libssh2.org (go-zpkg/recipes#170):
curl.se/download.html links "PGP Key" to https://daniel.haxx.se/address.html,
which prints this fingerprint and links /mykey.asc. GitHub's account endpoint
for `bagder` holds the key id 5CC908FDB71E12C2 — the fingerprint's last sixteen
digits — but cannot export it, so the id has two publishers and the key bytes
one. The key is not on the tarball's host. No keyserver was asked.

⛔ NOT BUILT. No session here can run the factory. What is established is the
inputs, each traced to a line in curl's own files, and a test written to fail
on each choice that could silently go the other way — zlib above all, which
configure cannot be made to refuse.
EOT
}
