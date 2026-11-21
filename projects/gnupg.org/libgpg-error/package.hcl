# libgpg-error — the error codes and the GnuPG run-time library (gpgrt) that
# every other GnuPG component links.
#
# WRITTEN FROM THE PROJECT'S OWN FILES at 1.61 (go-zpkg/packages#440). It was a
# fragment declaring one darwin dependency, gettext.

summary = "Error codes and run-time helpers shared by GnuPG, libgcrypt and libassuan"

# README:33-38: "GNU Lesser General Public License ... version 2.1 ... or (at
# your option) any later version". README:40-46 adds that a few BUILD-time
# files (src/mkerrnos.awk) are under another licence with an exception that
# keeps their output out of the GPL, so the installed artefacts are LGPL.
license = "LGPL-2.1-or-later"

versions {
  url   = "https://gnupg.org/ftp/gcrypt/libgpg-error/"
  match = "/libgpg-error-\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^libgpg-error-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-{{version.raw}}.tar.bz2"
  strip-components = 1

  # `versions` resolves 1.61 as the newest. Fetched with `zpkb sourcepin`
  # (1124751 bytes). Second witness: the detached signature, verified against
  # the key file gnupg.org links from its signature page, no keyserver:
  #
  #   signed by  6DAA6E64A76D2840571B4902528897B826403ADA
  #              Werner Koch (dist signing 2020), signed 2026-05-07T08:26:14Z
  #   key file   https://gnupg.org/signature_key.asc
  #   fprs from  https://gnupg.org/signature_key.html (all six listed
  #              fingerprints match the six keys in the file)
  #   signature  https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.bz2.sig
  #
  # Checked when the digest was recorded, not at every build.
  sha256 = {
    "1.61" = "7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93"
  }
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # configure.ac:235 is AM_GNU_GETTEXT([external]): libintl comes from the
      # host, which is what the old fragment's darwin gettext dependency was
      # for. NLS off removes the dependency on every platform; the cost is
      # untranslated messages.
      "--disable-nls",

      # configure.ac:759-768. The manual needs makeinfo and the test programs
      # are not installed; neither belongs in an installed artefact.
      "--disable-doc",
      "--disable-tests",

      # configure.ac:754 builds lang/cl (Common Lisp) when not disabled.
      "--disable-languages",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:29 bin_PROGRAMS = gpg-error; :86-88 bin_SCRIPTS is
# gpgrt-config, plus gpg-error-config only under
# --enable-install-gpg-error-config (configure.ac:226-231), which is not set.
provides = [
  "bin/gpg-error",
  "bin/gpgrt-config",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "gpg-error --version",
    "gpgrt-config --modversion | grep {{version.raw}}",
    "test -f {{prefix}}/include/gpg-error.h",
    "test -f {{prefix}}/lib/pkgconfig/gpg-error.pc",
    "pkg-config --exists gpg-error",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <gpg-error.h>

int main(void) {
  /* header and library must agree, or a system copy was linked */
  if (strcmp(gpg_error_check_version(GPG_ERROR_VERSION), GPG_ERROR_VERSION) != 0) {
    puts("library older than header");
    return 1;
  }
  if (gpg_err_code(GPG_ERR_EOF) != GPG_ERR_EOF || strlen(gpg_strerror(GPG_ERR_EOF)) == 0) {
    puts("error code round trip failed");
    return 1;
  }
  printf("libgpg-error %s: %s\n", gpg_error_check_version(NULL), gpg_strerror(GPG_ERR_EOF));
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o check $(pkg-config --cflags --libs gpg-error)"
    },
    "./check",
  ]
}

provenance {
  read = [
    "README",                 # :33-46 licence and the build-file exception
    "configure.ac",           # :168 libtool-modification (mingw only); :226-231 install-gpg-error-config; :235 AM_GNU_GETTEXT external; :754-768 languages, doc, tests
    "src/Makefile.am",        # :29 bin_PROGRAMS; :83-92 library, headers, scripts, m4 data
    "https://gnupg.org/signature_key.html",
  ]

  consulted = []

  note = <<EOT
NOT BUILT: the recipe, the flags and the test were written from the source and
checked only by `zpkb lint` and `zpkb versions`. No build was run.

The two release-signing keys that matter: every GnuPG tarball in this family
was signed by Werner Koch's 2020 distribution key, 6DAA6E64...3ADA.
EOT
}
