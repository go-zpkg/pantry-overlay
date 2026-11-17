# gnome.org/libxml2 — the XML parser and toolkit, which 9 recipes in this tree
# name.
#
# ⛔ WRITTEN FROM LIBXML2'S OWN FILES (go-zpkg/packages#431), at 2.15.4. Fifth of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145), zstd (#146),
# bzip2 (#147) and libexpat (#148).
#
# ⚠ pkgxdev/pantry's recipe was NOT opened: that tree carries no licence
# (go-zpkg/packages#431), so `consulted` is empty on purpose.

summary = "libxml2: the XML C parser and toolkit, with xmllint and xmlcatalog"

# Read from `Copyright`: "Permission is hereby granted, free of charge, to any
# person obtaining a copy" — the MIT text. ⚠ Its own first paragraph warns that
# `dict.c` and `list.c` are "covered by a similar licence but with different
# Copyright notices"; different HOLDER, same licence, so the expression stays a
# single identifier.
license = "MIT"

# ⛔⛔ THE INDEX IS PER-SERIES, SO THE OBVIOUS `url` WOULD FREEZE ONE.
# download.gnome.org/sources/libxml2/ lists directories (2.11 … 2.15), and the
# tarballs live one level down. Pointing `url` at `2.15/` would pin this recipe
# to a series forever, which is the defect tcl-lang.org already carries here —
# an enumeration scraped from a page that only lists what upstream currently
# shows. GNOME publishes a `cache.json` covering EVERY series, so the match runs
# over that instead. Measured below rather than assumed.
versions {
  url   = "https://download.gnome.org/sources/libxml2/cache.json"
  match = "/libxml2-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^libxml2-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  # `{{version.marketing}}` is major.minor — 2.15 for 2.15.4 — which is exactly
  # the series directory. This is the case libexpat (#148) did NOT have: there
  # the tag needed underscores, here the path component is a token already.
  url              = "https://download.gnome.org/sources/libxml2/{{version.marketing}}/libxml2-{{version.raw}}.tar.xz"
  strip-components = 1

  # 3177444 bytes, recorded with `zpkb sourcepin --version 2.15.4`.
  sha256 = {
    "2.15.4" = "98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821"
  }

  # ⛔ NO SIGNATURE IS PUBLISHED AT ALL — a third shape, and the weakest rung so
  # far. The 2.15 directory offers exactly three files per release:
  # `libxml2-2.15.4.tar.xz`, `libxml2-2.15.4.sha256sum`, `libxml2-2.15.4.news`.
  # There is no `.asc` and no `.sig` to be unanchored.
  #
  # ⭐ What upstream does publish is its own SHA-256, and ours reproduces it
  # byte for byte:
  #
  #   https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.4.sha256sum
  #   98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821  libxml2-2.15.4.tar.xz
  #
  # ⚠ That is upstream's STATEMENT about the bytes, served by the same host as
  # the bytes — so it establishes that we fetched what they published, not that
  # nobody else could have published it. Ranked against the four before it:
  # openssl.org (#145) publishes the fingerprint in prose naming the primary as
  # the trust anchor; sourceware.org/bzip2 (#147) publishes eighty bits of it in
  # the key's FILENAME; facebook.com/zstd (#146) and libexpat (#148) publish a
  # signature with no anchor; this one publishes no signature and a checksum.
}

# ⚠ ICONV IS DECLARED FOR DARWIN ONLY, and that is measured rather than copied.
# configure.ac:83-84 defaults `--with-iconv` to (on), and on linux/glibc the
# iconv functions ARE the libc's — the same shape as gnu.org/gettext, where
# glibc exports gettext/dcgettext/bindtextdomain and a `gnu.org/gettext`
# declared outside `darwin:` is dead weight (measured 2026-10-28 on glibc 2.44).
# ⛔ This tree already states that distinction correctly for gnu.org/libiconv,
# which declares gettext under `darwin:` for exactly this reason; getting it
# backwards is how ten projects ended up carrying a linux dependency nothing
# links.
dependencies = {
  darwin = {
    "gnu.org/libiconv" = "*"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ NAMED BECAUSE THE HELP TEXT IS WRONG — NOT BECAUSE THE DEFAULT IS
      # ON. configure.ac:97-98 documents `--with-python` as "(on)" and that line
      # is STALE: the bindings became off-by-default in 2.15.
      #
      # The generated script, which is the artifact that runs, settles it.
      # `configure:14421-14423` is the two-argument AC_ARG_WITH form, so
      # `with_python` is assigned ONLY when the flag is passed; the script's one
      # textual assignment to it, `configure:14642`, sits inside the
      # `--with-minimum` branch. A plain `./configure` therefore leaves it
      # EMPTY, and both consumers test for "yes":
      #   :15354 / configure.ac:579-582  AM_PATH_PYTHON + PKG_CHECK_MODULES
      #   :15832 / configure.ac:589-593  `test "$with_python" = "yes" ||
      #             test "$with_docs" = "yes"` → AC_PATH_PROG(DOXYGEN) →
      #             AC_MSG_ERROR([cannot find doxygen]).
      # Both are reachable through a FLAG and never by default.
      #
      # ⛔ So what this flag defends against is the documentation, and the
      # pantry. pkgxdev/pantry's recipe passes `--with-python` deliberately and
      # consequently build-depends on `doxygen.nl` and `python.org >=3<3.12`,
      # and sets a runtime PYTHONPATH. python.org is one of the twenty-two
      # (go-zpkg/recipes#143): taking that path would RAISE this closure's skip
      # count instead of lowering it. Named explicitly rather than left to a
      # help string that already disagrees with its own code.
      "--without-python",

      # (off) by default already (:73-74), named because it is the OTHER half of
      # the doxygen condition at :589 and a future default flip would be silent.
      "--without-docs",

      # ⭐ NAMED BECAUSE THE DEFAULT IS THE SURPRISING ONE. configure.ac:125-126
      # documents `--with-zlib` as "(off)", so libxml2 does NOT compress by
      # default — the opposite of what a reader expects from a GNOME library,
      # and the opposite of what this recipe's author assumed before reading it.
      # Left to the default, which is what the nine consumers get today; stated
      # so that a silent flip upstream is visible as a diff here.
      "--without-zlib",

      # (off) by default (:85-86, :75-78). icu would add a large runtime
      # dependency this tree does not have; history/readline would add
      # gnu.org/readline, which is also one of the twenty-two and would raise
      # the skip count. configure.ac:213-221 shows `--with-history` FORCING
      # readline on, so naming history is what keeps readline out.
      "--without-icu",
      "--without-history",
      "--without-readline",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ `xml2-config` IS INSTALLED AND IS NOT PROMISED — the FIFTH time this tree
# has made that call by hand, after tukaani.org/xz, openssl.org (#145),
# facebook.com/zstd (#146) and sourceware.org/bzip2 (#147). Makefile.am:35 is
# `bin_SCRIPTS = xml2-config` and xml2-config.in:1 is `#! /bin/sh`; a script
# cannot run where there is no interpreter. The convention is filed as a check
# in go-zpkg/zpkb#500 precisely so a sixth recipe need not remember it.
#
# The two binaries are Makefile.am:33 `bin_PROGRAMS = xmllint` and :53
# `bin_PROGRAMS += xmlcatalog`, the latter under WITH_CATALOG_SOURCES and
# WITH_OUTPUT_SOURCES — both (on) by default (:69-70, :91-92), so it is built.
provides = [
  "bin/xmllint",
  "bin/xmlcatalog",
]

test {
  script = [
    "test -f \"{{prefix}}/include/libxml2/libxml/parser.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libxml2.* >/dev/null
test -f "{{prefix}}/lib/pkgconfig/libxml-2.0.pc"
EOT
    },

    {
      run = <<EOT
"{{prefix}}/bin/xmllint" --version 2>&1 | grep -q "{{version}}"
EOT
    },

    # ⛔ IT HAS TO PARSE AND IT HAS TO REFUSE. A well-formed document and a
    # malformed one, because a parser that accepts everything also "parses".
    {
      run = <<EOT
printf '<a><b>x</b></a>\n' > ok.xml
"{{prefix}}/bin/xmllint" --noout ok.xml
printf '<a><b>x</a>\n' > bad.xml
if "{{prefix}}/bin/xmllint" --noout bad.xml 2>/dev/null; then
  echo "xmllint accepted a malformed document" >&2
  exit 1
fi
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR `--without-python`, AND IT GUARDS A FLIP
    # RATHER THAN A REMOVAL. Dropping the flag today changes nothing: the
    # default is already off. What it catches is the day configure.ac:97-98
    # stops being stale, or the day someone "aligns" this recipe with the
    # pantry, which passes `--with-python`. Either way the build SUCCEEDS on a
    # machine carrying doxygen and a Python with its .pc, and silently ships
    # bindings plus a dependency on a project that has no recipe. Asserted on
    # the installed tree: no python module directory may appear under lib.
    {
      run = <<EOT
if ls -d "{{prefix}}"/lib/python* >/dev/null 2>&1; then
  echo "python bindings were installed — --without-python was dropped" >&2
  exit 1
fi
EOT
    },

    # ⛔ AND IT HAS TO LINK, which is what the nine consumers want.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <string.h>
int main(void)
{
  const char *doc = "<a><b/><c/></a>";
  xmlDocPtr d = xmlReadMemory(doc, (int)strlen(doc), "t.xml", NULL, 0);
  int n = 0;
  xmlNodePtr root, cur;
  if (d == NULL) return 1;
  root = xmlDocGetRootElement(d);
  if (root == NULL) return 2;
  for (cur = root->children; cur != NULL; cur = cur->next)
    if (cur->type == XML_ELEMENT_NODE) n++;
  xmlFreeDoc(d);
  xmlCleanupParser();
  return n == 2 ? 0 : 3;
}
SRC
"$CC" conftest.c -I"{{prefix}}/include/libxml2" -L"{{prefix}}/lib" -lxml2 -o conftest
./conftest
EOT
    },
  ]
}

provenance {
  read = [
    "Copyright",      # the MIT text, and the note that dict.c/list.c differ in HOLDER rather than licence
    "configure.ac",   # :67-134 the thirty-three AC_ARG_WITH and their stated defaults; :83-84 iconv (on); :85-86 icu (off); :97-98 python documented "(on)" and STALE; :125-126 zlib (OFF); :213-221 --with-history FORCES readline on; :223-255 the --with-minimum branch; :579-582 python needs AM_PATH_PYTHON and its .pc; :589-593 python or docs makes doxygen MANDATORY, AC_MSG_ERROR otherwise
    "configure",      # the GENERATED script, read because the .ac help text disagreed with it: :14421-14423 the two-arg AC_ARG_WITH form (with_python set only when the flag is passed), :14642 its one assignment, inside --with-minimum; :15354 and :15832 the two consumers, both testing for "yes"
    "Makefile.am",    # :33 bin_PROGRAMS = xmllint; :35 bin_SCRIPTS = xml2-config; :51-53 xmlcatalog under WITH_CATALOG_SOURCES and WITH_OUTPUT_SOURCES
    "xml2-config.in", # :1 #! /bin/sh — why it is not in `provides`
  ]

  consulted = [
    "pkgxdev/pantry projects/gnome.org/libxml2/package.yml", # read AFTER writing this recipe, to settle the python default; it is why the correction below exists
  ]

  note = <<EOT
⛔⛔ THIS RECIPE SHIPPED WITH A FALSE HEADLINE AND THIS PARAGRAPH REPLACES IT.
The first version of this note said "the default configuration of this C
library refuses to configure without doxygen", from configure.ac:97-98
documenting `--with-python` as "(on)". That help text is STALE — the bindings
became off-by-default in 2.15 — and the claim was wrong.

⭐ WHAT SETTLED IT WAS THE GENERATED SCRIPT, not more argument about the .ac
file. `configure:14421-14423` is the two-argument AC_ARG_WITH form, which
assigns `with_python` only when the flag is PASSED; the script's one textual
assignment to it, `configure:14642`, is inside the `--with-minimum` branch; and
its two consumers, `:15354` and `:15832`, both test for "yes". A plain
`./configure` leaves the variable EMPTY, so the AC_MSG_ERROR for doxygen is
reachable only through a flag. `./configure --help` would have printed the same
stale "(on)", because it prints that string.

⛔ SO THE LESSON IS THE INVERSE OF THE ONE FIRST WRITTEN HERE. I had read the
help text beside the macro and believed it, then read `:239` — which does state
the true default, `with_python=no` — and talked myself OUT of it because it sits
inside the `--with-minimum` branch at :223. The branch reading was correct and
the conclusion was still wrong, because the general case is not "yes" but
EMPTY, which is also off. A documented default is a claim; the assignment in
the artifact that runs is the fact.

⭐ `--without-python` stays, and is now named for a measured reason rather than
a wrong one: pkgxdev/pantry's recipe passes `--with-python` deliberately and so
build-depends on `doxygen.nl` and `python.org >=3<3.12` and sets a runtime
PYTHONPATH. python.org is one of the twenty-two (go-zpkg/recipes#143), so that
path would RAISE this closure's skip count. The flag pins us against the stale
documentation and against that alignment.

⚠ TWO ASSUMPTIONS OF MY OWN WERE WRONG AND ARE CORRECTED HERE RATHER THAN
QUIETLY DROPPED. I picked this project believing it "depends on zlib and xz,
both already written". configure.ac:125-126 defaults `--with-zlib` to OFF, and
there is no `--with-lzma` in 2.15 at all. So the dependency that justified the
pick does not exist, and the recipe is a clean −1 for a different reason than
the one I gave: it depends on nothing on linux, and on gnu.org/libiconv on
darwin only.

⭐ THE VERSION INDEX IS PER-SERIES, which would have frozen the enumeration.
download.gnome.org/sources/libxml2/ lists directories, not tarballs, so a `url`
pointing at `2.15/` would pin this recipe to one series — the defect
tcl-lang.org already carries in this tree, where an enumeration scraped from a
page showing only current recommendations stopped matching what SourceForge
still served. GNOME's `cache.json` covers every series and is what the match
runs over.

⚠ NOT BUILT. Measured here: the digest by two paths including upstream's own
published sha256sum, the version enumeration, the switch census against the
project's own configure.ac AND the generated `configure` that overrules it, and
`zpkb lint`. The scripts are a claim about
libxml2's build system read from that build system, and they stay a claim until
a factory runs them.
EOT
}
