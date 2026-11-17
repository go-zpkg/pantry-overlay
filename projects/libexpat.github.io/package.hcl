# libexpat.github.io — Expat, the stream-oriented XML parser, which 10 recipes
# in this tree name.
#
# ⛔ WRITTEN FROM EXPAT'S OWN FILES (go-zpkg/packages#431), at 2.10.0. Fourth of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145),
# facebook.com/zstd (#146) and sourceware.org/bzip2 (#147).
#
# ⚠ pkgxdev/pantry's recipe was NOT opened: that tree carries no licence
# (go-zpkg/packages#431), so `consulted` is empty on purpose.

summary = "Expat: a stream-oriented XML parser library in C, and the xmlwf validator"

# COPYING is the MIT text — "Permission is hereby granted, free of charge, to
# any person obtaining a copy of this software and associated documentation
# files", the no-warranty paragraph, and no further condition. Copyright is
# "Thai Open Source Software Center Ltd and Clark Cooper" plus "Expat
# maintainers"; two holders, one licence.
license = "MIT"

versions {
  github = "libexpat/libexpat/releases"
}

distributable {
  # ⛔ THE TAG IS NOT THE VERSION, and this is the only recipe here so far where
  # they differ by more than a prefix: the release NAME is `2.10.0` and the TAG
  # is `R_2_10_0`. The download URL is built from the tag, so the dots have to
  # become underscores — `{{version.major}}_{{version.minor}}_{{version.patch}}`
  # rather than a strip on `{{version.raw}}`, which cannot rewrite separators.
  url              = "https://github.com/libexpat/libexpat/releases/download/R_{{version.major}}_{{version.minor}}_{{version.patch}}/expat-{{version.raw}}.tar.xz"
  strip-components = 1

  # 543404 bytes, recorded with `zpkb sourcepin --version 2.10.0`, and confirmed
  # by an independent `curl` + `shasum -a 256` giving the same value.
  sha256 = {
    "2.10.0" = "c624ba2998fc65df1163a49641ff3f9ab73138b11641d92c86bee0fb01b1bc7f"
  }

  # ⛔⛔ A SIGNATURE IS PUBLISHED AND CANNOT BE USED — the second project in this
  # campaign in that state, after facebook.com/zstd (#146).
  #
  # expat ships `expat-2.10.0.tar.xz.asc` (870 bytes) beside the archive and
  # publishes NO fingerprint. Looked for on 2026-11-17, four surfaces, all
  # negative:
  #
  #   README.md at R_2_10_0     no "fingerprint", "gpg", "pgp key" or "signing"
  #   SECURITY.md at R_2_10_0   13 lines, none of them about a key
  #   https://libexpat.github.io/   no "fingerprint", "gpg", "pgp", "signature"
  #   the repository root tree  no KEYS, *.asc, *.gpg or pubkey file
  #
  # `--key-source` is mandatory and no keyserver is ever asked, so with no
  # published anchor there is nothing an answer could be checked AGAINST —
  # uscan(1) states it as an instruction: "verify the downloaded OpenPGP key
  # using its full fingerprint value WHICH YOU KNOW is the trusted one".
  #
  # Contrast sourceware.org/bzip2 (#147), where the anchor is the published
  # FILENAME `gpgkey-5C1D1AA44BE649DE760A.gpg` carrying eighty bits of the
  # fingerprint, and openssl.org (#145), where it is a sentence naming the
  # primary key. The digest below is the warrant here.
  #   https://github.com/libexpat/libexpat/releases/download/R_2_10_0/expat-2.10.0.tar.xz.asc
}

# ⚠ NO RUNTIME DEPENDENCIES: expat links nothing but libc. That is measured by
# absence rather than asserted — configure.ac names no library check at all, and
# the entropy sources below are libc functions or a device file.

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ THE ENTROPY SOURCE IS AUTO-DETECTED, AND IT IS A SECURITY PROPERTY.
      # Expat uses entropy to SALT ITS HASH TABLE — the defence against
      # hash-collision denial of service (CVE-2012-0876, CVE-2016-5300) — and
      # configure.ac decides where that entropy comes from with FIVE probes
      # against whatever the sandbox happens to have:
      #
      #   :236 --with-arc4random        :299 --with-getentropy
      #   :244 --with-arc4random-buf    :341 --with-getrandom
      #   :366 --with-sys_getrandom     :418 --with-dev-urandom
      #
      # ⛔ EACH DEFAULTS TO `check` (:305 `with_getentropy=check` and its
      # siblings), and in `check` mode a failed probe is SILENT: the error at
      # :332-333 fires only when the switch was ENFORCED. Nothing refuses a
      # build in which no source at all was found — configure merely prints a
      # summary (:595-598 "Entropy sources: … getentropy: ${have_getentropy}")
      # and carries on. So two machines can produce artifacts whose hash
      # randomisation differs in strength, and the weaker one says nothing.
      #
      # ⭐ NAMING IT TURNS THE SILENCE INTO A REFUSAL, which is the whole value:
      # with `--with-getentropy` the probe at :332-333 becomes
      # `AC_MSG_ERROR([enforced the use of getentropy --with-getentropy, but not
      # detected])`. getentropy is the portable modern choice — the check's own
      # text says "BSD, macOS 10.12+, glibc 2.25+" and our glibc is 2.44 — so a
      # target that lacks it is a target we have not thought about, and a loud
      # failure there is the correct outcome rather than a quiet downgrade.
      "--with-getentropy",

      # ⛔⛔ `--without-tests` IS NOT AN OPTIMISATION — IT KEEPS A C++ COMPILER
      # OUT OF A C LIBRARY'S BUILD. configure.ac:210-213 defaults
      # `with_tests=yes`, and :216-217 then runs
      # `AX_CXX_COMPILE_STDCXX_11([noext], [mandatory])` — MANDATORY, so the
      # default configuration of a pure-C library REQUIRES a C++11 compiler.
      # Left alone this either fails in a sandbox that staged no C++, or pulls
      # libstdc++ into the build closure of a project that links only libc.
      "--without-tests",

      # Built by default (:204-207) and installed nowhere useful.
      "--without-examples",

      # ⛔ ANOTHER `check` DEFAULT DECIDING WHAT THE ARTIFACT CONTAINS.
      # configure.ac:460 is `with_docbook=check`, and :463-464 then searches for
      # docbook2x-man, db2x_docbook2man, docbook2man and docbook-to-man. If one
      # is on PATH the build generates and installs a man page; if none is, it
      # does not — the same recipe, two different artifacts, decided by the
      # sandbox. Named `no` so the answer is the same everywhere.
      "--without-docbook",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# `xmlwf` is the one program expat installs (configure.ac:198-201,
# `with_xmlwf=yes` by default and kept). It is a compiled binary, not a script.
provides = [
  "bin/xmlwf",
]

test {
  script = [
    "test -f \"{{prefix}}/include/expat.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libexpat.* >/dev/null
EOT
    },

    # The pkg-config file, because that is how most of the ten consumers find
    # this library rather than by guessing paths.
    {
      run = <<EOT
test -f "{{prefix}}/lib/pkgconfig/expat.pc"
EOT
    },

    {
      run = <<EOT
"{{prefix}}/bin/xmlwf" -v 2>&1 | grep -q "{{version}}"
EOT
    },

    # ⛔ IT HAS TO PARSE, not merely link. A well-formed document and a
    # malformed one, so the test fails both if the parser is broken and if it
    # accepts anything. xmlwf exits non-zero on a malformed document.
    {
      run = <<EOT
printf '<a><b>x</b></a>\n' > ok.xml
"{{prefix}}/bin/xmlwf" ok.xml
printf '<a><b>x</a>\n' > bad.xml
if "{{prefix}}/bin/xmlwf" bad.xml > bad.out 2>&1 && ! grep -q . bad.out; then
  echo "xmlwf accepted a malformed document" >&2
  exit 1
fi
EOT
    },

    # ⛔ AND IT HAS TO LINK, which is what the ten consumers want from it.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <expat.h>
#include <string.h>
static int depth = 0;
static void s(void *u, const XML_Char *n, const XML_Char **a) { (void)u; (void)n; (void)a; depth++; }
int main(void)
{
  const char *doc = "<a><b/><c/></a>";
  XML_Parser p = XML_ParserCreate(NULL);
  if (p == NULL) return 1;
  XML_SetStartElementHandler(p, s);
  if (XML_Parse(p, doc, (int)strlen(doc), 1) != XML_STATUS_OK) return 2;
  XML_ParserFree(p);
  return depth == 3 ? 0 : 3;
}
SRC
"$CC" conftest.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lexpat -o conftest
./conftest
EOT
    },
  ]
}

provenance {
  read = [
    "COPYING",       # the MIT text, two copyright holders, no further condition
    "configure.ac",  # :130 C99 required; :198-214 the xmlwf/examples/tests switches and their yes defaults; :216-217 tests pull in a MANDATORY C++11 compiler; :236-418 the five entropy probes; :305 their `check` default; :332-333 the error an ENFORCED switch produces; :454-466 the docbook `check` default; :595-598 the entropy summary configure prints
    "README.md",     # looked at for a published key fingerprint; there is none
    "SECURITY.md",   # the same, 13 lines, none about a key
  ]

  consulted = []

  note = <<EOT
⭐⭐ THE DEFECT THIS RECIPE PREVENTS IS AN AUTO-DETECTED SECURITY PROPERTY, which
is a rung above the ones the three recipes before it caught. zstd's probes
decided which compression formats a binary supported; expat's decide WHERE ITS
HASH-TABLE SALT COMES FROM — the defence against hash-collision denial of
service. Five `AC_ARG_WITH` probes, each defaulting to `check`, each silent when
it fails, and nothing in configure refusing a build that found no source at all.
`--with-getentropy` converts that silence into `AC_MSG_ERROR` and fixes the
answer across machines.

⚠ AND THE TEST BLOCK DOES NOT ASSERT IT, deliberately. The chosen entropy source
leaves no observable trace in the installed artifact — `expat_config.h` is not
installed, and no exported symbol or output differs — so a test claiming to
check it would be a test that passes for the wrong reason. go-fleettools/
fleettools#337 cost two vacuous tests in one pull request to learn that; the
honest record is this paragraph and the citation to configure.ac:305, not a
green assertion over nothing. What the block DOES assert is parsing (well-formed
accepted, malformed refused) and linking, both of which are observable.

⛔ `--without-tests` IS LOAD-BEARING FOR A DIFFERENT REASON than it looks.
configure.ac:216-217 makes a C++11 compiler MANDATORY when tests are built, and
tests are built by default — so the stock configuration of a pure-C library
drags libstdc++ into its build closure, or fails where there is no C++ at all.
That is not a preference about running tests; it is a dependency this recipe
must not acquire.

⛔ A SIGNATURE IS PUBLISHED AND CANNOT BE ANCHORED — the second such project in
this campaign, after facebook.com/zstd. Four surfaces checked and recorded
above. The ladder across the four recipes written today is worth keeping:
openssl.org publishes the full fingerprint in a sentence that also names the
primary key as the trust anchor; sourceware.org/bzip2 publishes it as eighty
bits inside the key's FILENAME; facebook.com/zstd and this one publish a
signature and no anchor at all. Two of four.

⚠ NOT BUILT. Measured here: the digest by two paths, the version enumeration,
the switch census against the project's own configure.ac, and `zpkb lint`. The
scripts are a claim about expat's build system read from that build system, and
they stay a claim until a factory runs them.
EOT
}
