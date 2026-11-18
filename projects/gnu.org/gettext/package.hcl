# gnu.org/gettext — and it carries the sharpest auto-detection this campaign
# has found: a PROGRAM THAT CHANGES LANGUAGE depending on what was staged.
#
# ⛔ WRITTEN FROM GETTEXT'S OWN FILES (go-zpkg/packages#431), at 1.0, read out
# of the signed release tarball.
#
# ⭐ THE CONSUMER HALVES HAVE BEEN HERE SINCE go-zpkg/recipes#32 AND #33 —
# gawk's darwin gettext declaration, and fontconfig/bash/libgpg-error's libintl
# one — and gnu.org/glibc declares it too. This closes a project that four
# recipes already name.
#
# ⚠ AND THE VERSION NUMBER IS A TRAP WORTH NAMING FIRST. gettext went 0.26 →
# 1.0, so `1.0` is the CURRENT release, not an ancient one. A `versions` block
# copying python.org's idiom — which excludes `^v?[01]\.` because CPython's
# 1.x is from 1994 — would delete the newest gettext there is. Measured on
# ftp.gnu.org/gnu/gettext/: the directory holds 0.19.1 through 0.26 and then
# 1.0.

summary = "GNU gettext: the internationalization toolset, libintl, and the msg* tools"

# ⛔ TWO LICENCES, AND THE SPLIT IS THE PROJECT'S OWN. PACKAGING recommends
# distributors split the install into five binary packages, and the licensing
# follows that split: the gettext-runtime library half (libintl, libasprintf)
# is LGPL so that non-free programs may link it, while the gettext-tools half
# — the msg* programs, xgettext, autopoint — is GPL. COPYING is the GPLv3
# text; the LGPL applies to the runtime subtree, which is where libintl lives
# and which is the half our four consumers link.
license = "GPL-3.0-or-later AND LGPL-2.1-or-later"

platforms = ["linux", "darwin", "windows", "freebsd", "openbsd", "netbsd"]

versions {
  url   = "https://ftp.gnu.org/gnu/gettext/"
  match = "/gettext-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^gettext-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/gettext/gettext-{{version.raw}}.tar.xz"
  strip-components = 1

  # 10721600 bytes, recorded with the builder's own fetcher and a verified
  # signature:
  #
  #   zpkb sourcepin --sig auto --key ./gpgkey-1BBEAC08.asc \
  #     --fingerprint "E0FF BD97 5397 F77A 32AB  76EC B630 1D9E 1BBE AC08" \
  #     --key-source "<see provenance>" --version 1.0 \
  #     https://ftp.gnu.org/gnu/gettext/gettext-1.0.tar.xz
  #
  #   signed by E0FFBD975397F77A32AB76ECB6301D9E1BBEAC08
  #   Bruno Haible (Free Software Development) <bruno@clisp.org>
  #   no keyserver was asked
  #   1 key(s) read from the file
  sha256 = {
    "1.0" = "71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7"
  }
}

build {
  # ⛔ THE PROJECT SHIPS ITS OWN DEPENDENCY CENSUS, and this list is read from
  # it rather than inferred: `DEPENDENCIES` names every library with what it
  # buys and what is lost without it. That file is why this recipe can be
  # precise about consequences instead of listing flags.
  dependencies = {
    # DEPENDENCIES: "Recommended. Needed for 'xgettext' and 'msgfmt', so that
    # it can parse XML files. Also needed for the --color option … If not
    # present, A SUBSET OF LIBXML2 (INCLUDED IN THIS PACKAGE) will be compiled
    # into libgettextlib." We have the real one (go-zpkg/recipes#149, #150), so
    # the vendored subset is refused below by pointing configure at ours.
    "gnome.org/libxml2" = "*"

    # DEPENDENCIES: "Highly recommended. Needed for styling of terminal output
    # (libtextstyle and the --color option of the 'msgcat' program)."
    "invisible-island.net/ncurses" = 6

    # ⛔ DECLARED FOR `spit`, AND IT IS NOT ENOUGH ON ITS OWN — see the long
    # note below. libcurl is one of the TWO libraries that decide whether
    # bin/spit is a compiled program or a Python script; the other is
    # libjson-c, which this tree has no recipe for.
    "curl.se" = "*"
  }

  # ⛔⛔ THE FINDING THAT MATTERS MOST: `bin/spit` IS EITHER A COMPILED PROGRAM
  # OR A PYTHON SCRIPT, AT THE SAME PATH, AND NO FLAG DECIDES IT.
  #
  # gettext-tools/src/Makefile.am:34-43:
  #
  #     if BUILD_SPIT_IN_C
  #     bin_PROGRAMS += spit
  #     endif
  #     noinst_SCRIPTS = spit.py
  #     if !BUILD_SPIT_IN_C
  #     noinst_SCRIPTS += spit
  #     endif
  #
  # and :816-820 installs it either way:
  #
  #     install-exec-local:
  #     if !BUILD_SPIT_IN_C
  #     	$(INSTALL_SCRIPT) spit.py $(DESTDIR)$(bindir)/spit
  #
  # `BUILD_SPIT_IN_C` comes from whether configure found libjson-c AND
  # libcurl — and there is NO `--with-json-c`, NO `--with-libcurl`, nothing.
  # Measured: `--with|--without|--enable|--disable` over `configure` yields 91
  # distinct switches and not one of them names json or curl; the two appear
  # only as library probes inside gettext-tools/configure.
  #
  # ⛔ SO THE ARTIFACT CONTAINS A FILE AT bin/spit WHOSE *NATURE* DEPENDS ON
  # THE BUILD MACHINE, and `provides` is satisfied either way — which is
  # exactly what makes it dangerous. `zpkb lint` cannot tell the two apart.
  #
  # ⛔⛔ AND IN THE SCRIPT ARM THE ARTIFACT GAINS AN UNDECLARED RUNTIME
  # DEPENDENCY. DEPENDENCIES says so in its own words, under "runtime
  # dependencies, but not build dependencies": "Python 3.7 or newer.
  # Recommended if GNU Gettext was built without libjson-c or without
  # libcurl." and "The Python module 'requests'."
  #
  # ⚠ THIS TREE HAS NO json-c RECIPE, so BUILD_SPIT_IN_C CANNOT BE SATISFIED
  # TODAY and spit WILL be the Python script. That is stated rather than
  # papered over, and so is the consequence: `spit` is gettext's
  # machine-translation helper, it will need python3 and the `requests`
  # module, and `requests` is a pip package this tree does not carry — so
  # **spit's machine translation will not work in this artifact**. Nothing
  # else in gettext depends on it.
  #
  # The fix is a `github.com/json-c/json-c` recipe, after which this recipe
  # declares it and spit becomes the compiled program deterministically. Until
  # then the limitation is named here and in the test block rather than
  # discovered by whoever first runs `spit`.
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ POINT configure AT OUR libxml2 so the vendored subset is not used.
      # The `--with-included-libxml` switch forces the opposite; leaving both
      # unset makes it an auto-detection, which is the state this avoids.
      "--with-libxml2-prefix={{deps.gnome.org/libxml2.prefix}}",

      # ⚠ libunistring IS vendored ON PURPOSE AND EXPLICITLY. DEPENDENCIES:
      # "Optional. Needed for the line breaking in PO files and for xgettext.
      # If not present, a subset of libunistring (included in this package)
      # will be compiled into libgettextlib." This tree has no libunistring
      # recipe, so the subset is what we get either way — and saying so with
      # the flag makes it a DECISION rather than an accident of staging, which
      # is the whole difference this campaign is about.
      "--with-included-libunistring",

      # ⛔⛔ FOUR LANGUAGE TOOLCHAINS DECIDE WHAT IS IN THE ARTIFACT, and all
      # four are settled OFF. DEPENDENCIES lists them as "Recommended":
      #
      #   Java      → builds libintl.jar, and lets msgfmt/msgunfmt handle
      #               Java classes and .properties files
      #   C#        → builds GNU.Gettext.dll, same for C# resources
      #   D         → builds libintl_d.a
      #   Modula-2  → builds libintl_m2.so
      #
      # Each is auto-detected, so without these flags the artifact's CONTENTS
      # — whole libraries, and two msgfmt input formats — would depend on
      # which compilers happened to be on the build machine. None of the four
      # is in this tree.
      "--disable-java",
      "--disable-modula2",
      "--enable-csharp=no",
      "--enable-d=no",

      # ⚠ ncurses is declared above, so the styling half is deterministic
      # rather than probed. Stated with the flag for the same reason.
      "--enable-curses",

      # ⛔ TWO LINUX-ONLY AUTO-DETECTIONS, settled. DEPENDENCIES: libacl and
      # libattr are "Recommended on Linux systems. Needed so that the creation
      # of backup files respects the access control lists (ACLs) set on the
      # original files." Neither has a recipe here, so found-or-not would be a
      # property of the build host.
      "--disable-acl",
      "--disable-xattr",

      # ⛔ THREE TOOLS `autopoint` LOOKS FOR, settled the same way.
      # DEPENDENCIES says git is "Needed by the 'autopoint' program, if not
      # configured with --without-git", and bzip2/xz likewise. git has no
      # recipe here; bzip2 and xz do, but enabling them would add runtime
      # requirements to autopoint for an archive format nothing in this tree
      # feeds it. Off, so autopoint uses tar and gzip — both base-toolchain
      # members.
      "--without-git",
      "--without-bzip2",
      "--without-xz",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ READ FROM THE Makefile.am FILES THAT INSTALL THEM, not from `ls bin`:
#
#   gettext-runtime/src/Makefile.am:27  gettext ngettext printf_gettext
#                                       printf_ngettext envsubst
#   gettext-runtime/src/Makefile.am:71  gettext.sh
#   gettext-tools/src/Makefile.am:29-36 the msg* family, xgettext,
#                                       recode-sr-latin, and spit
#   gettext-tools/autotools/Makefile.am:28  autopoint
#   gettext-tools/wizard/Makefile.am:28     gettextize
#   gettext-tools/misc/Makefile.am:28       po-fetch
#
# ⚠ THE `examples/` SUBDIRECTORIES ALSO DECLARE bin_PROGRAMS — thirty-odd
# `hello` programs in as many languages — and NONE is listed here. They are
# demonstration sources built only when the examples are enabled, and listing
# one would make `provides` describe a build this recipe does not do.
provides = [
  "bin/gettext",
  "bin/ngettext",
  "bin/printf_gettext",
  "bin/printf_ngettext",
  "bin/envsubst",
  "bin/gettext.sh",
  "bin/msgattrib",
  "bin/msgcat",
  "bin/msgcmp",
  "bin/msgcomm",
  "bin/msgconv",
  "bin/msgen",
  "bin/msgexec",
  "bin/msgfilter",
  "bin/msgfmt",
  "bin/msggrep",
  "bin/msginit",
  "bin/msgmerge",
  "bin/msgpre",
  "bin/msgunfmt",
  "bin/msguniq",
  "bin/recode-sr-latin",
  "bin/xgettext",
  "bin/autopoint",
  "bin/gettextize",
  "bin/po-fetch",
  "bin/spit",
]

test {
  script = [
    "\"{{prefix}}/bin/gettext\" --version",
    "\"{{prefix}}/bin/xgettext\" --version",
    "\"{{prefix}}/bin/msgfmt\" --version",

    # ⭐ A ROUND TRIP THROUGH THE TOOLSET, because --version proves none of it:
    # extract strings from a C file, compile the catalogue, and read it back.
    # xgettext is the half that needs libxml2 and libunistring; msgfmt is the
    # half consumers invoke.
    {
      run = <<EOT
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
cat > "$d/hello.c" <<'C'
#include <libintl.h>
int main(void) { return puts(gettext("a translatable string")) < 0; }
C
"{{prefix}}/bin/xgettext" --language=C --keyword=gettext -o "$d/out.pot" "$d/hello.c"
grep -q "a translatable string" "$d/out.pot"
# A catalogue has to compile and then be readable again.
sed -e 's/CHARSET/UTF-8/' "$d/out.pot" > "$d/fr.po"
"{{prefix}}/bin/msgfmt" -o "$d/fr.mo" "$d/fr.po"
test -s "$d/fr.mo"
"{{prefix}}/bin/msgunfmt" "$d/fr.mo" > "$d/back.po"
grep -q "a translatable string" "$d/back.po"
EOT
    },

    # ⛔⛔ AND THE ASSERTION THAT NAMES WHICH `spit` THIS ARTIFACT GOT. It is
    # NOT a failure either way — both arms are legitimate builds — so this
    # REPORTS rather than refuses, because a test that failed here would fail
    # on every build until a json-c recipe exists. What it must not do is stay
    # silent: a Python script at bin/spit is a runtime dependency on an
    # interpreter this package never declared.
    {
      run = <<EOT
set -e
p="{{prefix}}/bin/spit"
test -e "$p"
if head -c 2 "$p" | grep -q '#!' ; then
  echo "gettext: bin/spit is the PYTHON SCRIPT variant." >&2
  echo "  gettext-tools/src/Makefile.am:34-43 picks between a compiled" >&2
  echo "  program and spit.py from the automake conditional BUILD_SPIT_IN_C," >&2
  echo "  which configure sets from whether libjson-c AND libcurl were found." >&2
  echo "  There is no flag for it: 91 configure switches, none naming json" >&2
  echo "  or curl." >&2
  echo "  CONSEQUENCE: this artifact needs python3 >= 3.7 and the 'requests'" >&2
  echo "  module for spit's machine translation, and declares neither." >&2
  echo "  Write a json-c recipe to make it the compiled program." >&2
else
  echo "gettext: bin/spit is the compiled C program (BUILD_SPIT_IN_C was on)." >&2
fi
EOT
    },
  ]
}

provenance {
  read = [
    "DEPENDENCIES",                          # the project's OWN dependency census: libiconv, ncurses, libxml2 ("a subset … included in this package" if absent), libjson-c and libcurl ("'spit' will be a Python script instead of an executable"), libacl, libattr, Java, C#, D, Modula-2, git, tar, gzip, bzip2, xz, libunistring ("a subset … included"), and the runtime half naming Python 3.7 and 'requests'
    "PACKAGING",                             # the maintainer's own five-package split, and why gettext-runtime is separate from gettext-tools
    "COPYING",                               # the GPLv3 text
    "configure",                             # the 91-switch census; :4672-4674 and :5403-5406 the --with-included-* pair; :47395 and :75583 where they force the bundled copies
    "gettext-tools/configure",               # where libjson-c and libcurl are probed, with no switch of their own
    "gettext-tools/src/Makefile.am",         # :29-36 bin_PROGRAMS and the BUILD_SPIT_IN_C arm; :40-43 spit.py as the other arm; :799-806 the script copy; :816-820 install-exec-local installing spit EITHER WAY; :423-424 spit_SOURCES and its json/curl CFLAGS
    "gettext-runtime/src/Makefile.am",       # :27 and :71, the runtime binaries and gettext.sh
    "gettext-tools/autotools/Makefile.am",   # :28 autopoint
    "gettext-tools/wizard/Makefile.am",      # :28 gettextize
    "gettext-tools/misc/Makefile.am",        # :28 po-fetch
  ]

  consulted = [
    # Read for the SIGNING KEY only, never for the build.
    "gentoo sec-keys/openpgp-keys-gettext-20250608.ebuild (SRC_URI, which names haible.de and not a keyserver)",
  ]

  note = <<EOT
⭐⭐ THE STRONGEST PROVENANCE CHAIN THIS CAMPAIGN HAS RECORDED, and the reason
is structural rather than a matter of degree: THE KEY AND THE TARBALL LIVE ON
DIFFERENT HOSTS.

  fingerprint  www.haible.de/bruno/gpgkeys.html, the maintainer's own site:
               "E0FF BD97 5397 F77A 32AB  76EC B630 1D9E 1BBE AC08"
               — ed25519, created 2025-01-28, marked [SC], expires 2030-01-27
  key bytes    www.haible.de/bruno/gpgkey-1BBEAC08.asc, same site
  tarball      ftp.gnu.org/gnu/gettext/gettext-1.0.tar.xz
  signature    ftp.gnu.org/gnu/gettext/gettext-1.0.tar.xz.sig

Whoever controls ftp.gnu.org cannot forge a signature without haible.de's key,
and whoever controls haible.de cannot substitute the tarball. musl.libc.org's
chain is single-host — tarball, .asc, fingerprint and key all from one domain,
which is continuity rather than independence — and cmake.org's stops one rung
short because its key is reachable only from a keyserver. This one is complete.

⚠ GENTOO CORROBORATES THE SOURCE BUT NOT THE FINGERPRINT.
sec-keys/openpgp-keys-gettext fetches three keys from haible.de by SHORT KEY ID
(1BBEAC08, 7C6A406D, 2E4616C2) and states no fingerprint at all. A short id is
not a pin — it is 32 bits — so the fingerprint above comes from Haible's own
page, where all three are written out in full, and the two older ones are
visibly expired (2025-02-10 and 2019-10-04). The one used here is the only
current signing key.

⭐ AND THE VERIFIER READ IT, which is worth recording because this tree has two
recipes where it could not: gnu.org/help2man's DSA/SHA-1 signature and
kernel.org/linux-headers' "a good signature our verifier cannot read"
(go-zpkg/recipes#115, #126). An ed25519 signature verifies cleanly, and the
PRIMARY key is the signer — no subkey indirection, so the fingerprint on the
page is the one the signature names. gnu.org/glibc's note records the opposite
case, where comparing a signing subkey against a published primary reported a
false absence.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every switch, dependency, installed path and licence
traced to a line in gettext's own files and cited in `read` above.

⚠ AND ONE THING THIS RECIPE DOES NOT DO, named because PACKAGING asks for it:
the maintainer recommends splitting the install into FIVE binary packages —
gettext-runtime, gettext-runtime-d, gettext-runtime-m2, libtextstyle and
gettext-tools — observing that the runtime half is 420 KB against the tools'
5.5 MB, and that the runtime "should be in the default installation list, like
GNU coreutils". This tree ships one package. The four consumers here
(gnu.org/glibc, gawk, fontconfig, bash) all want only libintl, so they pay for
the tools they do not use. That is the same shape as go-zpkg/recipes#122's
tcl-lang.org monolith and belongs in an issue rather than in a silent decision.
EOT
}
