# gnu.org/libidn2 — IDNA2008/TR46 internationalised domain names. One of the
# twenty projects the base-toolchain closure needed and this tree did not carry
# at all (`zpkb closure -build -require-standalone go-zpkg/base-toolchain`,
# 2026-11-19); gnu.org/wget declares it.
#
# ⛔ WRITTEN FROM LIBIDN2'S OWN FILES (go-zpkg/packages#431), at 2.3.8.
#
# ⭐⭐ WHAT WRITING IT FOUND, and most of it is not about libidn2:
#
#   1. Its signature could not be verified by this pantry AT ALL, for two
#      separate reasons, both now fixed in zpkb — see provenance.note.
#   2. Its project page names two signing keys, both EXPIRED, and neither of
#      them signed this release.
#   3. It compiles in a libunistring it bundles or one the builder happens to
#      have, by detection. Pinned to the bundled one — see `build`.

summary = "GNU Libidn2: IDNA2008 and TR46 internationalised domain names"

# README.md:43-57 — three licences in one package:
#   - the C library: "either the GNU General Public License version 2.0 or
#     later … or the GNU Lesser General Public License version 3.0 or later";
#   - the command line tool: "the GNU General Public License version 3.0 or
#     later";
#   - the Unicode character data parsed into the library: COPYING.unicode,
#     whose EXHIBIT 1 and "COPYRIGHT AND PERMISSION NOTICE … 1991-2016"
#     (lines 36-77) are the 2016 Data Files and Software agreement.
license = "(GPL-2.0-or-later OR LGPL-3.0-or-later) AND GPL-3.0-or-later AND Unicode-DFS-2016"

versions {
  url   = "https://ftp.gnu.org/gnu/libidn/"
  match = "/libidn2-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = ["/libidn2-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # DEPENDENCIES.md:42-45: libintl, part of GNU gettext — "Not needed on
  # systems with glibc. But recommended on all other systems. Needed for
  # localization of messages."
  "gnu.org/gettext" = "*"
}

distributable {
  # Only .tar.gz is published for this release; a .sig sits beside it.
  url              = "https://ftp.gnu.org/gnu/libidn/libidn2-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2234804 bytes. Recorded with `zpkb sourcepin --sig` (signature verified —
  # see provenance.note for what that took) and confirmed by a second,
  # independent fetch-and-hash.
  sha256 = {
    "2.3.8" = "f557911bf6171621e1f72ff35f5b1825bb35b52ed45325dcdee931e5d3c0787a"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ libunistring IS CHOSEN BY DETECTION, IN THE PROJECT'S OWN WORDS.
      # DEPENDENCIES.md:23-27:
      #
      #   GNU libunistring — Optional. … If not present, a subset of
      #   libunistring (included in this package) will be compiled into
      #   libidn2.
      #
      # So the artifact links the builder's libunistring if it has one and
      # compiles in its own subset if not — two different libraries behind the
      # same name, varying by builder. It is also why `gnu.org/libunistring`
      # was among the soname providers `zpkb closure -implicit` named as "no
      # recipe declares it". DEPENDENCIES.md:38-40 names the pin:
      #
      #   If you want to use the subset of libunistring included in this
      #   package rather than a preinstalled libunistring, pass the option
      #   --with-included-libunistring to 'configure'.
      #
      # The bundled subset is taken rather than a declared libunistring: it
      # keeps libidn2 self-contained, and the cost is stated in the same file —
      # "This increase the size of the library."
      "--with-included-libunistring",

      # ⛔ NLS needs libintl found, and an autoconf gettext search that misses
      # disables NLS rather than failing. DEPENDENCIES.md:54-55 names the lever
      # for a dependency outside the standard directories.
      "--with-libintl-prefix={{deps.gnu.org/gettext.prefix}}",

      # configure:2956 — "don't generate any documentation". Generating it is
      # what upstream's texinfo build dependency was for.
      "--disable-doc",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# src/Makefile.am:22 `bin_PROGRAMS = idn2`; lib/Makefile.am:23
# `lib_LTLIBRARIES = libidn2.la`; lib/Makefile.am:25 `include_HEADERS = idn2.h`.
provides = [
  "bin/idn2",
]

test {
  script = [
    "test -f \"{{prefix}}/include/idn2.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/libidn2.pc\"",

    # The tool converts a name, which exercises the library end to end.
    {
      run = <<EOT
set -eu
out=$(LC_ALL=C.UTF-8 "{{prefix}}/bin/idn2" "räksmörgås.se" 2>/dev/null || "{{prefix}}/bin/idn2" "räksmörgås.se")
test "$out" = "xn--rksmrgs-5wao1o.se" || { echo "idn2 gave $out" >&2; exit 1; }
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR --with-included-libunistring, read off the
    # artifact. libidn2.pc.in is `Libs.private: @LTLIBICONV@ @LTLIBUNISTRING@`,
    # and LTLIBUNISTRING is filled only when a SYSTEM libunistring was linked
    # (lib/Makefile.am:42 links the bundled subset otherwise). So the shipped
    # .pc names -lunistring exactly when the pin was dropped and the builder had
    # one.
    {
      run = <<EOT
set -eu
if grep -q unistring "{{prefix}}/lib/pkgconfig/libidn2.pc"; then
  echo "libidn2 links a system libunistring, which this recipe pinned away:" >&2
  grep '^Libs' "{{prefix}}/lib/pkgconfig/libidn2.pc" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "DEPENDENCIES.md",     # :23-40 libunistring optional, detected, and the pin; :42-55 libintl and its prefix option
    "configure",           # :2956 --disable-doc; :2978-2980 the libunistring options; :2982 --with-libintl-prefix
    "configure.ac",        # :91-92 AM_GNU_GETTEXT([external]); :224 the libunistring summary line
    "libidn2.pc.in",       # Libs.private carries @LTLIBUNISTRING@
    "lib/Makefile.am",     # :23 the library, :25 the header, :42 the bundled libunistring
    "src/Makefile.am",     # :22 the idn2 tool
    "README.md",           # :43-57 the three licences
    "COPYING.unicode",     # :36-77 the 2016 Data Files and Software agreement
    "https://ftp.gnu.org/gnu/libidn/", # the release listing and the .sig beside the archive
    "https://www.gnu.org/software/libidn/", # :505-509 the keys the project page names — see note
  ]

  consulted = [
    # Read for facts only: the version listing it matches, and that it
    # declares gettext and builds docs with texinfo. Nothing copied.
    "pkgxdev/pantry projects/gnu.org/libidn2/package.yml",
  ]

  note = <<EOT
⛔⛔ THIS SIGNATURE COULD NOT BE VERIFIED BY THIS PANTRY UNTIL TWO DEFECTS IN
`zpkb sourcepin` WERE FIXED, and both are worth more than this recipe.

  signature  https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz.sig
  signer     subkey 51722B08FE4745A2 (Ed25519), signed 2025-03-08
  primary    B1D2BD1375BECB784CF4F8C4D73CF638C53C06BE
  identity   Simon Josefsson <simon@josefsson.org>
  key from   https://ftp.gnu.org/gnu/gnu-keyring.gpg

1. THE KEY WAS UNREACHABLE. The signer's primary sits past position 402 in the
   GNU keyring, where sourcepin's keyring walk stopped on "Cannot have multiple
   embedded signatures"; gpg reads 614 keys from the same file. Fixed in
   go-zpkg/zpkb#511 (v0.88.0): the walk now steps over packets it does not
   parse, and found this key after 556.

2. THE KEY WAS REFRESHED AFTER IT SIGNED. Its user-ID self-signature in the
   keyring is dated 2026-04-17, after the 2025-03-08 release, and judged at the
   release's instant a self-signature from later counts as expired. Fixed in
   go-zpkg/zpkb#513 (v0.89.0, closing go-zpkg/zpkb#512): the check is judged
   at the key's newest self-signature,
   and sourcepin prints both instants — "signed at 2025-03-08T23:10:44Z;
   judged at 2026-04-17T08:55:45Z".

⚠ AND THE PROJECT PAGE NAMES THE WRONG KEYS. https://www.gnu.org/software/libidn/
lines 505-509 say releases are signed "with an OpenPGP key with fingerprint
0xB565716F or with OpenPGP key 0x08302DB6A2670428". Measured: 0xB565716F is
the key in https://josefsson.org/key.txt, a 1280-bit RSA key that EXPIRED on
2014-11-10, and it is a 32-bit id this pantry refuses as a selector;
0x08302DB6A2670428 is in the GNU keyring and EXPIRED on 2021-02-26. Neither
signed this release.

⚠ SO THE RUNG, STATED: the signer's fingerprint is published by no page the
project controls. It was read from the signature's own issuer field (`gpg
--list-packets`) and found in GNU's maintainer keyring, so the warrant is GNU's
curation of that keyring — on the same host as the tarball, which is
continuity and not independence, the same limit gnu.org/gzip records. The
signature also embeds the signer's key (subpacket 38); that was not used,
because a key a signature supplies about itself vouches for nothing.

⛔ NOT BUILT. No session here can run the factory. What is established is the
inputs, each traced to a line in libidn2's own files.
EOT
}
