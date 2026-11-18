# nghttp2.org — the HTTP/2 C library, which 3 recipes in this tree name:
# curl.se, where it is what makes HTTP/2 available at all, isc.org/bind9 and
# php.net. ⚠ Counted rather than estimated — the first draft of this line said
# two.
#
# ⛔ WRITTEN FROM NGHTTP2'S OWN FILES (go-zpkg/packages#431), at 1.71.0.
# Thirteenth of the twenty-two in go-zpkg/recipes#143.
#
# ⭐ AND IT BRINGS NO DEPENDENCY, which is true only because the build is
# narrowed to the library — and the narrowing is the finding.

summary = "nghttp2: the HTTP/2 C library"

# Read from `COPYING`: "The MIT License", over "Copyright (c) 2012, 2014, 2015,
# 2016 Tatsuhiro Tsujikawa" and the same years for "nghttp2 contributors".
# ⚠ There is no LICENSE file in this tarball; the licence is in COPYING.
license = "MIT"

versions {
  github = "nghttp2/nghttp2/releases"
  strip  = ["/^nghttp2 v/"]
}

distributable {
  # ⚠ .tar.xz rather than the pantry's .tar.gz: the release publishes three
  # formats and a single `checksums.txt` covering all of them, so the choice
  # costs nothing and the smaller archive is the one fetched.
  url              = "https://github.com/nghttp2/nghttp2/releases/download/v{{version.raw}}/nghttp2-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1995680 bytes, and reproducing the line for this file in the release's own
  # `checksums.txt` exactly.
  sha256 = {
    "1.71.0" = "c0f55121d88650e4b9227aec28cebaf664d2417ca60fe70be0f8d38829f52116"
  }

  # ⛔⛔ THE SIGNATURE'S KEY IS NOT THE MAINTAINER'S, AND IS PUBLISHED NOWHERE
  # THE PROJECT CONTROLS. Measured 2026-11-18, and the shape is sharper than
  # pcre.org/v2's (#151):
  #
  #   the .asc is signed by 516B622918D15C478AB1EA3A5339A2BE82E07DEC
  #   `users/tatsuhiro-t/gpg_keys` publishes 7E8403D5D673C366 — a DIFFERENT key
  #   searching the repository for either spelling returns 0 results
  #   the release's own author is `github-actions[bot]`
  #
  # ⚠ The bot authorship is the likely explanation and not an accusation: a
  # release built and signed by CI holds its key in the repository's secrets,
  # and nothing obliges a project to publish it. But the consequence stands —
  # there is no copy of that key this tree can reach without asking a
  # keyserver, which it does not, so `zpkb sourcepin --sig` cannot be run.
  #
  # ⭐ WHAT DOES ANCHOR THESE BYTES is `checksums.txt`, published as a release
  # asset beside the three archives, whose line for this file reproduces the
  # digest above character for character. The same rung as gnome.org/libxml2
  # (#149) and bytereef.org/mpdecimal (#157): it establishes that we fetched
  # what the release published, not that nobody else could have published it.
  # Below github.com/besser82/libxcrypt (#156), whose signing key has an
  # independent copy on the owning account.
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ THE PANTRY NARROWS THIS BUILD BY NOT RUNNING PART OF IT, WHERE THE
      # PROJECT PROVIDES A FLAG TO NARROW THE CONFIGURATION. Its script is
      #
      #   ./configure --prefix={{prefix}}
      #   make -j N -C lib install
      #
      # — only the `lib` subdirectory is built, so the applications never
      # appear and no dependency is needed. The artifact is right; the method
      # leaves configure doing work whose answers nothing uses:
      #
      #   configure:1637-1638  --enable-app           [default=check]
      #   configure:1639       --enable-hpack-tools   [default=check]
      #   configure:1640       --enable-examples      [default=check]
      #
      # `check` means PROBE: configure looks for openssl, libev, c-ares, zlib,
      # jansson and the rest to decide whether those applications COULD be
      # built, on every build, with the answers recorded in config.h and the
      # generated Makefiles. A sandbox that happens to stage one of them
      # changes what configure decides — and a probe that fails in the wrong
      # way stops the build for an application this recipe never wanted.
      #
      # ⭐ configure:1642-1644 is the declared way to say it:
      #
      #   --enable-lib-only   Build libnghttp2 only. This is a short hand for
      #                       --disable-app --disable-examples
      #                       --disable-hpack-tools
      #
      # Naming it asks for the narrowing instead of achieving it by omission,
      # and the three `check` probes stop running. The same shape as
      # bytereef.org/mpdecimal (#157), where `rm -rf {{prefix}}/share` undid
      # what `--disable-doc` can ask for.
      "--enable-lib-only",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: with --enable-lib-only this build installs libnghttp2, its
# headers and its pkg-config file, and no programs. lib/Makefile.am:36 is
# `lib_LTLIBRARIES = libnghttp2.la` and there is no bin_PROGRAMS anywhere in
# the library's makefile. The pantry names none either.

test {
  script = [
    "test -f \"{{prefix}}/include/nghttp2/nghttp2.h\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libnghttp2.* >/dev/null 2>&1 \
  || { echo "libnghttp2 is missing from {{prefix}}/lib" >&2; exit 1; }
test -f "{{prefix}}/lib/pkgconfig/libnghttp2.pc"
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR `--enable-lib-only`, asserted as an ABSENCE.
    # If the flag is dropped, configure's three `check` probes run again and a
    # sandbox carrying openssl and libev will build and install nghttp, nghttpd,
    # nghttpx and h2load — programs this recipe does not promise, does not
    # declare dependencies for, and whose contents would then vary by sandbox.
    {
      run = <<EOT
set -eu
for app in nghttp nghttpd nghttpx h2load; do
  if [ -e "{{prefix}}/bin/$${app}" ]; then
    echo "$${app} was installed — --enable-lib-only was dropped and the applications were built" >&2
    exit 1
  fi
done
EOT
    },

    # ⭐ AND THE LIBRARY HAS TO BE THE VERSION THIS RECIPE PINNED. nghttp2
    # reports it at run time, so this links against the installed library and
    # asks it, rather than reading a file name.
    {
      run = <<EOT
set -eu
cat > probe.c <<'CEOF'
#include <stdio.h>
#include <nghttp2/nghttp2.h>
int main(void) {
  nghttp2_info *i = nghttp2_version(0);
  if (!i) return 1;
  printf("%s\n", i->version_str);
  return 0;
}
CEOF
cc probe.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lnghttp2 -o probe
./probe > ver.txt
grep -qx "{{version}}" ver.txt || { echo "libnghttp2 reports a different version:" >&2; cat ver.txt >&2; exit 1; }
EOT
    },

    # ⛔ AND IT HAS TO REFUSE. nghttp2_version takes a minimum ABI version and
    # returns NULL when the library is older than asked for; a library that
    # answers for every number is not checking.
    {
      run = <<EOT
set -eu
cat > refuse.c <<'CEOF'
#include <stdio.h>
#include <nghttp2/nghttp2.h>
int main(void) {
  /* A version far beyond anything released: must be refused. */
  if (nghttp2_version(0x7fffffff) != NULL) {
    printf("accepted\n");
    return 1;
  }
  printf("refused\n");
  return 0;
}
CEOF
cc refuse.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lnghttp2 -o refuse
./refuse > r.txt
grep -qx refused r.txt
EOT
    },
  ]
}

provenance {
  read = [
    "COPYING",          # "The MIT License" and its two copyright lines; there is no LICENSE file here
    "lib/Makefile.am",  # :36 lib_LTLIBRARIES = libnghttp2.la, and no bin_PROGRAMS — why `provides` is absent
    "configure",        # the GENERATED script: :1637-1638 --enable-app [default=check]; :1639 --enable-hpack-tools [default=check]; :1640 --enable-examples [default=check]; :1642-1644 --enable-lib-only and what it is shorthand for; :1645-1646 --enable-http3 and its extra requirements
  ]

  consulted = [
    "pkgxdev/pantry projects/nghttp2.org/package.yml",     # read deliberately: its `make -C lib install` is what this recipe replaces with --enable-lib-only
    "github.com/nghttp2/nghttp2 releases/tag/v1.71.0",     # the assets, the checksums.txt, the .asc signatures and the release's bot authorship
    "https://api.github.com/users/tatsuhiro-t/gpg_keys",   # the maintainer's published key, which is NOT the one that signed this release
  ]

  note = <<EOT
⛔⛔ THE PANTRY NARROWS THIS BUILD BY NOT RUNNING PART OF IT, WHERE THE PROJECT
PROVIDES A FLAG TO NARROW THE CONFIGURATION. Its script is `./configure
--prefix=…` followed by `make -C lib install`: only the `lib` subdirectory is
built, so the applications never appear and no dependency is needed. The
artifact is right; the method leaves configure doing work whose answers nothing
uses. configure:1637-1640 defaults --enable-app, --enable-hpack-tools and
--enable-examples to `check` — PROBE — so it looks for openssl, libev, c-ares,
zlib and jansson on every build, to decide whether applications this recipe
never wanted COULD be built. A sandbox that happens to stage one changes what
configure decides, and a probe that fails in the wrong way stops the build.

⭐ configure:1642-1644 is the declared way to say it: `--enable-lib-only  Build
libnghttp2 only. This is a short hand for --disable-app --disable-examples
--disable-hpack-tools`. Naming it asks for the narrowing instead of achieving it
by omission, and the three probes stop running. The same shape as
bytereef.org/mpdecimal (#157), where `rm -rf {{prefix}}/share` undid what
`--disable-doc` can ask for, and ncurses (#152), where `rm -rf
{{prefix}}/include` undid what a fresh prefix already gives.

⛔⛔ THE SIGNATURE'S KEY IS NOT THE MAINTAINER'S, AND IS PUBLISHED NOWHERE THE
PROJECT CONTROLS — a sharper shape than pcre.org/v2's (#151), where the
documented key simply was not the signer. Here:
  the .asc is signed by 516B622918D15C478AB1EA3A5339A2BE82E07DEC
  users/tatsuhiro-t/gpg_keys publishes 7E8403D5D673C366 — a DIFFERENT key
  a code search of the repository for either spelling returns 0 results
  the release's own author is `github-actions[bot]`
⚠ The bot authorship is the likely explanation and not an accusation: a release
built and signed by CI holds its key in the repository's secrets, and nothing
obliges a project to publish it. The consequence stands — no copy of that key is
reachable without a keyserver, which this tree never asks, so `zpkb sourcepin
--sig` cannot be run. There is also no attestation: `gh attestation verify`
answers HTTP 404.

⭐ WHAT ANCHORS THESE BYTES is `checksums.txt`, a release asset covering all
three archives, whose line for the .tar.xz reproduces the pinned digest
character for character. The same rung as gnome.org/libxml2 (#149) and
bytereef.org/mpdecimal (#157); below github.com/besser82/libxcrypt (#156), whose
signing key has an independent copy on the owning account.

⚠ NOT BUILT. Measured here: the digest against the release's own checksums.txt,
the signing key against the maintainer's published one and against the
repository's contents, the absence of an attestation, the switch census, and
`zpkb lint`. The scripts are a claim about nghttp2's build system read from that
build system, and they stay a claim until a factory runs them.
EOT
}
