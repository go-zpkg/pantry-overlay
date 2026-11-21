# trurl — a command line tool for URL parsing and manipulation, on libcurl's URL API.
#
# A WHOLE recipe, written from trurl's own Makefile and README
# (go-zpkg/packages#440, step 1). It was a fragment: no versions, no
# distributable.

summary = "Command line tool for URL parsing and manipulation, built on libcurl"

# The licence is curl's own, named by SPDX id in the sources: Makefile:21 and
# version.h:23 both say `SPDX-License-Identifier: curl`, and COPYING is the
# short permissive notice that licence uses. Not MIT and not ISC, though the
# text resembles them.
license = "curl"

versions {
  # The releases carry the version in their NAME ("trurl 0.16.1"), with the tag
  # spelled "trurl-0.16.1", the same shape as curl/curl's.
  github = "curl/trurl/releases"
  strip  = "/^trurl /"
}

dependencies = {
  # libcurl is the only library trurl links (README.md:151-156): `curl-config
  # --libs/--cflags` is what the Makefile asks (:28-29). The README states a
  # floor of 7.62.0 and says several features need 7.77-7.88, so the current
  # major is the one that gives "all the documented goodness".
  "curl.se" = "^8"
}

distributable {
  # The STORED release asset the maintainer uploaded, with its .asc beside it,
  # not a GitHub-generated tag archive.
  url              = "https://github.com/curl/trurl/releases/download/trurl-{{version.raw}}/trurl-{{version.raw}}.tar.gz"
  strip-components = 1

  # 64088 bytes, fetched with `zpkb sourcepin --sig auto`: the detached
  # signature verifies against Daniel Stenberg's key. The chain is in
  # provenance.note.
  sha256 = {
    "0.16.1" = "aac947d4fb421a58abc19a3771e87942cd4721b8f855c433478c94c11a8203ba"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # Plain make; there is no configure. The Makefile reads PREFIX (:39) and
  # DESTDIR, and its `install` target (:59-69) installs the binary and, when
  # present, trurl.1 and the zsh completion.
  #
  # The release tarball already CONTAINS trurl.1 (listed in the archive), so
  # nothing needs perl (scripts/cd2nroff is a perl script) or python. The
  # `trurl` target is named explicitly so `make` does not try to regenerate
  # trurl.1 from trurl.md if the extraction left the two with equal times.
  # The completion file scripts/_trurl.zsh is NOT in the tarball (only
  # completions/_trurl.zsh.in is), so install's `test -f` skips it.
  #
  # TRURL_IGNORE_CURL_CONFIG is left unset on purpose: the Makefile then asks
  # `curl-config`, which the declared libcurl provides, instead of finding a
  # libcurl by luck. NDEBUG=1 drops -Werror -g (:34-36), so a newer compiler's
  # new warning cannot fail a release build.
  script = [
    "make trurl NDEBUG=1",
    "make install PREFIX={{prefix}}",
  ]
}

provides = [
  "bin/trurl",
]

test {
  script = [
    "trurl --version",
    # A parse and a rewrite through libcurl's URL API.
    {
      run = <<EOT
set -eu
host=$(trurl --url 'https://example.com:8080/a/b?x=1' --get '{host}')
test "$host" = "example.com"
port=$(trurl --url 'https://example.com:8080/a/b?x=1' --get '{port}')
test "$port" = "8080"
out=$(trurl --url 'https://example.com/a' --set host=example.org --set query=y=2)
test "$out" = "https://example.org/a?y=2"
EOT
    },
  ]
}

provenance {
  read = [
    "Makefile",   # :25-36 TARGET, curl-config flags, NDEBUG; :39-46 PREFIX/BINDIR/MANDIR; :48-56 all and the trurl.1 rule; :58-69 install
    "README.md",  # :135 `make`; :151-156 libcurl >= 7.62.0, 7.80/7.81 features; :166-175 per-feature minimum libcurl
    "version.h",  # :23 SPDX-License-Identifier: curl; :27 TRURL_VERSION_TXT
    "COPYING",    # the permissive notice
  ]

  consulted = [
    "pkgxdev/pantry projects/curl.se/trurl/package.yml",
  ]

  note = <<EOT
The source archive is signed, and the signature was checked when this digest
was recorded rather than at every build.

  signature  https://github.com/curl/trurl/releases/download/trurl-0.16.1/trurl-0.16.1.tar.gz.asc
  key        https://daniel.haxx.se/mykey.asc
  identity   Daniel Stenberg <daniel@haxx.se>
  signed at  2025-05-12T06:26:23Z
  fingerprint 27EDEAF22F3ABCEB50DB9A125CC908FDB71E12C2

The fingerprint is the issuer fingerprint printed inside the release's own .asc
(`gpg --list-packets`), and the key file is the author's own, the same chain as
curl.se (curl.se/download.html links to https://daniel.haxx.se/address.html,
which links /mykey.asc). The key file holds three keys; this is the third. No
keyserver was asked.

The Makefile's CFLAGS handling that the old fragment patched with sed is not
needed: CFLAGS from the environment already reaches make.

⛔ NOT BUILT. No session here can run the factory. The inputs are traced to
lines in trurl's own files; the test asserts a parse and a rewrite.
EOT
}
