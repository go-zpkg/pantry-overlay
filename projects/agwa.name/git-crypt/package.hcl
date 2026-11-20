# agwa.name/git-crypt — transparent file encryption in git.
#
# ⛔ WRITTEN FROM GIT-CRYPT'S OWN FILES (go-zpkg/packages#431), at 0.8.0, from
# the tag's Makefile, git-crypt.hpp, git-crypt.cpp and COPYING.
#
# ⭐⭐ WHAT WRITING IT FOUND: the Makefile has no configure step and nothing
# silent in the crypto — `crypto-openssl-11.o` and `-lcrypto` are unconditional
# (Makefile:27-28), so a missing OpenSSL is a link error, not a fallback.
# Two things are choices anyway:
#
#   ENABLE_MAN  (Makefile:13-14) defaults to `no`; `yes` runs xsltproc against
#       DOCBOOK_XSL = http://docbook.sourceforge.net/... (:14), a FETCH OVER
#       PLAIN HTTP at build time. Refused: ENABLE_MAN is left at `no`.
#   CXXFLAGS ?= (:7) is overridden by a `make CXXFLAGS=...` on the command
#       line, which would also drop the `-std=c++11` of :8. They are passed in
#       the ENVIRONMENT instead, so `+=` still applies.
#
# git-crypt runs `git` and `gpg` at RUN time (commands.cpp, gpg.cpp); neither
# is a build input and neither is declared.

summary = "git-crypt: transparent file encryption in git"

# COPYING is the GNU GPL version 3 text. git-crypt.cpp:5-29 grants "either
# version 3 of the License, or (at your option) any later version" plus an
# additional permission to link OpenSSL (GPL section 7). That text is not one
# the SPDX list carries under an identifier, so it is a LicenseRef.
license = "GPL-3.0-or-later AND LicenseRef-git-crypt-openssl-exception"

versions {
  github = "AGWA/git-crypt"
}

dependencies = {
  # Makefile:27-28: crypto-openssl-11.cpp and -lcrypto, unconditional.
  "openssl.org" = "^3"
}

distributable {
  # GitHub's archive of the tag. The release 0.8.0 carries ONE asset, a
  # linux-x86_64 binary, and no source tarball (so no digest to compare with).
  url              = "https://github.com/AGWA/git-crypt/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 57788 bytes. Recorded with `zpkb sourcepin` and confirmed by a second,
  # independent fetch-and-hash (curl + shasum).
  sha256 = {
    "0.8.0" = "786199c24f8b79a54d62b98c24b1113606c4ebd83125e642b228704686305e69"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    # In the environment, not on the make command line: see the header.
    CXXFLAGS = "-O2 -Wall -I{{deps.openssl.org.prefix}}/include"
    LDFLAGS  = "-L{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib"

    # Makefile:13 — named so a change of default is visible.
    ENABLE_MAN = "no"
  }

  script = [
    "make PREFIX={{prefix}}",
    "make PREFIX={{prefix}} install",
  ]
}

# Makefile:84-86: install-bin installs git-crypt into $(BINDIR).
provides = [
  "bin/git-crypt",
]

test {
  # git-crypt.cpp:81-83 prints "git-crypt " VERSION, and git-crypt.hpp:34
  # defines VERSION "0.8.0".
  script = [
    {
      run = <<EOT
set -eu
test "$(git-crypt version)" = "git-crypt {{version.raw}}"
EOT
    },
  ]
}

provenance {
  read = [
    "Makefile",         # :7-8 flags, :13-14 ENABLE_MAN and the http DOCBOOK_XSL, :27-28 openssl, :84-86 install
    "git-crypt.hpp",    # :34 VERSION
    "git-crypt.cpp",    # :5-29 licence and OpenSSL permission, :81-83 the version line
    "COPYING",
  ]

  consulted = [
    # Read for facts only: that openssl is the one dependency.
    "pkgxdev/pantry projects/agwa.name/git-crypt/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The source is GitHub's generated archive
of the tag 0.8.0 (the release has only a binary asset); it was fetched twice,
independently. Whether the tag itself is signed was not checked, and a
generated archive would not carry a signature either way.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
