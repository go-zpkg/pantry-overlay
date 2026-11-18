# github.com/besser82/libxcrypt — the modern libcrypt, which 3 recipes in this
# tree name and which every passphrase hash in the closure goes through.
#
# ⛔ WRITTEN FROM LIBXCRYPT'S OWN FILES (go-zpkg/packages#431), at 4.5.2.
# Eleventh of the twenty-two in go-zpkg/recipes#143, after openssl.org (#145),
# zstd (#146), bzip2 (#147), libexpat (#148), libxml2 (#149, corrected by #150),
# pcre.org/v2 (#151), invisible-island.net/ncurses (#152), gnu.org/readline
# (#153), sourceware.org/libffi (#154) and libpng.org (#155).
#
# ⛔⛔ AND THE TWO FLAGS THIS RECIPE DOES NOT PASS ARE THE WHOLE OF IT. The
# pantry's recipe turns off libxcrypt's failure tokens and its symbol
# versioning. Both change BEHAVIOUR rather than the build, both are against
# upstream's default, and upstream's own help text says what the first one
# costs.

summary = "libxcrypt: the modern libcrypt, with the hashing methods a passphrase file may hold"

# Read from `LICENSING`: "The overall license for libxcrypt is the GNU Lesser
# General Public License, version 2.1 (or, at your option, any later version)".
license = "LGPL-2.1-or-later"

versions {
  github = "besser82/libxcrypt/releases/tags"
  strip  = ["/^v/"]
}

distributable {
  url              = "https://github.com/besser82/libxcrypt/releases/download/v{{version.raw}}/libxcrypt-{{version.raw}}.tar.xz"
  strip-components = 1

  # 669820 bytes, recorded with `zpkb sourcepin -version 4.5.2`, and matching
  # the `libxcrypt-4.5.2.tar.xz.sha256sum` the release publishes beside it.
  sha256 = {
    "4.5.2" = "71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071"
  }

  # ⭐ THE MOST COMPLETE RELEASE OF THE ELEVEN — and the reason it is strong is
  # NOT the reason it first appears to be. The release ships four files:
  #
  #   libxcrypt-4.5.2.tar.xz
  #   libxcrypt-4.5.2.tar.xz.asc          a detached signature
  #   libxcrypt-4.5.2.tar.xz.sha256sum    a checksum, which matches
  #   libxcrypt-gpgkey.asc                THE SIGNING KEY ITSELF
  #
  # ⛔ A KEY SHIPPED BESIDE THE SIGNATURE IT VALIDATES PROVES NOTHING ON ITS
  # OWN: whoever can replace the tarball can replace both, and the set verifies
  # against itself perfectly. Read that way this is the most convincing-looking
  # provenance in the campaign and the most circular.
  #
  # ⭐ What makes it the strongest anyway is a SECOND, INDEPENDENT copy. The
  # signature is by 678CE3FEE430311596DB8C16F52E98007594C21D, and
  # `users/besser82/gpg_keys` — GitHub's record for the account that OWNS this
  # repository — publishes exactly `F52E98007594C21D`, with
  # besser82@fedoraproject.org and bjoern.esser@gmail.com as verified
  # addresses. That copy is bound to the identity that controls the releases
  # and is not reachable by replacing a release asset.
  #
  # Verified against THAT copy rather than the shipped one, with `zpkb
  # sourcepin -fingerprint 678CE3FE…7594C21D`: "no keyserver was asked".
}

build {
  dependencies = {
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "~0.29"
    "perl.org"                   = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⚠ KEPT FROM THE PANTRY, AND IT IS THE ONLY ONE OF ITS THREE THAT
      # BELONGS. Valgrind is a TEST dependency: configure:1527-1534 offers it
      # for the unit tests only, so disabling it removes a build-time
      # requirement without touching the installed library.
      "--disable-valgrind",

      # ⛔⛔ `--disable-failure-tokens` IS NOT PASSED, AND UPSTREAM'S OWN HELP
      # SAYS WHY. configure:1535-1543:
      #
      #   "Make crypt and crypt_r return NULL on failure, instead of a special
      #    'failure token' string that isn't the hash of any passphrase. This
      #    matches the behavior of several other crypt implementations, BUT
      #    WILL BREAK PROGRAMS THAT ASSUME THESE FUNCTIONS NEVER RETURN NULL."
      #
      # The default is on (configure:17294, `enable_failure_tokens=1`). The
      # failure token exists so that a crypt() that could not hash returns
      # something that cannot match any stored hash; returning NULL instead
      # hands every caller a pointer it may not check. Three recipes here link
      # this library, and none of them was consulted about that change.
      #
      # ⚠ This is a DIFFERENCE FROM THE PANTRY and not a fix to libxcrypt:
      # upstream's default is simply kept.

      # ⛔⛔ AND `--disable-symvers` IS NOT PASSED EITHER. configure:1526 states
      # `[default=auto]`, and :16039 shows what auto means — `want_symvers=yes`,
      # then :16045 probes the linker for a version-script flag and falls back
      # if there is none. So the default already handles a platform that cannot
      # do it; disabling it unconditionally turns off symbol versioning where
      # the probe WOULD have succeeded.
      #
      # Symbol versioning is what makes this library a drop-in for glibc's
      # libcrypt: a binary linked against `crypt@@GLIBC_2.2.5` resolves against
      # a versioned libxcrypt and does not resolve against an unversioned one.
      # Turning it off removes the reason the project exists.
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: libxcrypt installs no programs — Makefile.am has no
# `bin_PROGRAMS` and no `bin_SCRIPTS`, measured with `lib_LTLIBRARIES` matching
# once as the control. The pantry names none either.

test {
  script = [
    "test -f \"{{prefix}}/include/crypt.h\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libcrypt.* >/dev/null 2>&1 \
  || { echo "libcrypt is missing from {{prefix}}/lib" >&2; exit 1; }
test -f "{{prefix}}/lib/pkgconfig/libcrypt.pc"
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR THE FAILURE TOKEN, which is the flag this
    # recipe declines to pass. A crypt() given a setting it cannot use must
    # return a NON-NULL string that is not a hash — "*0" or "*1". If
    # --disable-failure-tokens is ever added, this returns NULL and the test
    # goes red instead of the behaviour changing silently under three
    # consumers.
    {
      run = <<EOT
set -eu
cat > probe.c <<'CEOF'
#include <stdio.h>
#include <string.h>
#include <crypt.h>
int main(void) {
  /* An invalid setting: crypt() cannot produce a hash from it. */
  char *r = crypt("passphrase", "*invalid-setting");
  if (r == NULL) {
    printf("NULL\n");
    return 1;
  }
  printf("%s\n", r);
  /* A failure token never matches the setting it was given. */
  return strcmp(r, "*invalid-setting") == 0 ? 1 : 0;
}
CEOF
cc probe.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lcrypt -o probe
./probe > token.txt || {
  echo "crypt() returned NULL on failure — --disable-failure-tokens was added" >&2
  cat token.txt >&2
  exit 1
}
grep -q '^\*' token.txt || {
  echo "crypt() did not return a failure token on an invalid setting" >&2
  cat token.txt >&2
  exit 1
}
EOT
    },

    # ⛔ AND IT HAS TO HASH, AND THE HASH HAS TO VERIFY. A crypt() that returns
    # a constant also "hashes", so the round trip is asserted: the stored hash
    # re-derives from the right passphrase and does not from a wrong one.
    {
      run = <<EOT
set -eu
cat > rt.c <<'CEOF'
#include <stdio.h>
#include <string.h>
#include <crypt.h>
int main(void) {
  const char *setting = "$6$abcdefghijklmnop";
  char stored[256];
  char *h = crypt("correct horse", setting);
  if (!h || h[0] == '*') { printf("no hash\n"); return 1; }
  snprintf(stored, sizeof stored, "%s", h);
  char *again = crypt("correct horse", stored);
  if (!again || strcmp(again, stored) != 0) { printf("round trip failed\n"); return 1; }
  char *wrong = crypt("wrong horse", stored);
  if (wrong && strcmp(wrong, stored) == 0) { printf("a wrong passphrase matched\n"); return 1; }
  printf("ok\n");
  return 0;
}
CEOF
cc rt.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lcrypt -o rt
./rt > rt.txt
grep -q '^ok$' rt.txt
EOT
    },

    # ⚠ AND THE SYMBOL VERSIONS HAVE TO BE THERE, which is the other flag this
    # recipe declines to pass. Without them the library exports a bare `crypt`
    # and stops being a drop-in for glibc's libcrypt.
    {
      run = <<EOT
set -eu
if ! readelf --version-info "{{prefix}}/lib/libcrypt.so" 2>/dev/null | grep -q 'XCRYPT_\|GLIBC_'; then
  echo "libcrypt.so exports no versioned symbols — --disable-symvers was added" >&2
  exit 1
fi
EOT
      if  = "linux"
    },
  ]
}

provenance {
  read = [
    "LICENSING",   # "the GNU Lesser General Public License, version 2.1 (or, at your option, any later version)"
    "Makefile.am", # no bin_PROGRAMS and no bin_SCRIPTS, with lib_LTLIBRARIES as the control — why `provides` is absent
    "configure",   # the GENERATED script: :1526 --disable-symvers "[default=auto]"; :16034-16045 what auto means — want_symvers=yes, then a linker probe with a fallback; :1527-1534 valgrind is for the unit tests; :1535-1543 the failure-token help, including "will break programs that assume these functions never return NULL"; :17289-17294 enable_failure_tokens defaults to 1; :1548-1574 the obsolete-api settings and what `no` does to the soname
  ]

  consulted = [
    "pkgxdev/pantry projects/github.com/besser82/libxcrypt/package.yml", # read deliberately: the two behaviour flags this recipe declines to pass are its, and a difference cannot be stated without reading what it differs from
    "https://api.github.com/users/besser82/gpg_keys",                     # the independent copy of the signing key, bound to the account that owns the repository
  ]

  note = <<EOT
⛔⛔ THE TWO FLAGS THIS RECIPE DOES NOT PASS ARE THE WHOLE OF IT, and both change
BEHAVIOUR rather than the build.

`--disable-failure-tokens`, which the pantry passes, is described by upstream's
own help (configure:1535-1543) as making crypt and crypt_r "return NULL on
failure, instead of a special 'failure token' string that isn't the hash of any
passphrase … but WILL BREAK PROGRAMS THAT ASSUME THESE FUNCTIONS NEVER RETURN
NULL." The default is on (configure:17294). The token exists so a crypt() that
could not hash returns something that cannot match a stored hash; NULL hands
every caller a pointer it may not check. Three recipes here link this library.

`--disable-symvers`, which the pantry also passes, is stated as `[default=auto]`
at configure:1526 — and :16039-16045 show that auto already means "want it, then
probe the linker and fall back". So the default handles the platform that cannot
do it, and disabling unconditionally turns off symbol versioning where the probe
WOULD have succeeded. Symbol versioning is what makes this a drop-in for glibc's
libcrypt: a binary linked against crypt@@GLIBC_2.2.5 resolves against a
versioned libxcrypt and not against an unversioned one. Turning it off removes
the reason the project exists.

⚠ NEITHER IS A FIX TO LIBXCRYPT. Upstream's defaults are simply kept, and both
are asserted by tests so that re-adding either goes red rather than changing
behaviour silently under three consumers.

⭐ THE MOST COMPLETE RELEASE OF THE ELEVEN, FOR A REASON THAT IS NOT THE OBVIOUS
ONE. It ships the tarball, a detached .asc, a .sha256sum that matches, and
`libxcrypt-gpgkey.asc` — the signing key itself. ⛔ A key shipped beside the
signature it validates proves nothing on its own: whoever replaces the tarball
replaces both, and the set verifies against itself perfectly. Read that way it
is the most convincing-looking provenance here and the most circular.

⭐ What makes it strongest anyway is a SECOND, INDEPENDENT copy:
`users/besser82/gpg_keys` — GitHub's record for the account that OWNS this
repository — publishes exactly the signing key, F52E98007594C21D, with two
verified addresses. That copy is bound to the identity controlling the releases
and cannot be reached by replacing a release asset. Verification was done
against THAT copy, not the shipped one.

⚠ NOT BUILT. Measured here: the digest against the release's own sha256sum, the
signature against the independently published key, the two behaviour defaults in
the generated configure, and `zpkb lint`. The scripts are a claim about
libxcrypt's build system read from that build system, and they stay a claim
until a factory runs them.
EOT
}
