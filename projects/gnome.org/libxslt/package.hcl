# gnome.org/libxslt — the XSLT 1.0 library (libxslt, libexslt) and xsltproc.
#
# Written from libxslt's own files (go-zpkg/packages#440, step 1): po4a.org
# named `gnome.org/libxslt` and no recipe existed, so it is written here.
# libxml2 is the one library it needs, and gnome.org/libxml2 is whole.

summary = "libxslt: the XSLT 1.0 library, libexslt and the xsltproc command"

# Copyright:1-20 `Licence for libxslt except libexslt`, the MIT text ("Permission
# is hereby granted, free of charge, to any person obtaining a copy"). libexslt
# carries its own notice in the same file, with the same grant; a single
# identifier stays correct.
license = "MIT"

# The same per-series index libxml2's recipe measured: the directory listing
# names series only, cache.json covers every one. Only `.tar.xz` matches, so the
# old 1.1.4 archives (.tar.gz, .tar.bz2) do not enter.
versions {
  url   = "https://download.gnome.org/sources/libxslt/cache.json"
  match = "/libxslt-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^libxslt-/",
    "/\\.tar\\.xz$/",
  ]
}

dependencies = {
  # configure.ac:25 `LIBXML_REQUIRED_VERSION=2.15.1`, checked at :407 through
  # pkg-config (`libxml-2.0 >= 2.15.1`) and refused below it (:427). libxml2
  # 2.15 is the series this tree carries.
  "gnome.org/libxml2" = "^2.15"
}

distributable {
  # `{{version.marketing}}` is major.minor, 1.1, the series directory.
  url              = "https://download.gnome.org/sources/libxslt/{{version.marketing}}/libxslt-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1519992 bytes, recorded with `zpkb sourcepin --version 1.1.45`.
  #
  # NO SIGNATURE is published: the 1.1 directory offers `.tar.xz`, `.news` and
  # `.sha256sum` per release, no `.asc`. The second witness is upstream's own
  # checksum file, which this digest reproduces:
  #
  #   https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.45.sha256sum
  #   9acfe68419c4d06a45c550321b3212762d92f41465062ca4ea19e632ee5d216e  libxslt-1.1.45.tar.xz
  #
  # That is upstream's statement served by the host that serves the bytes: it
  # shows we fetched what they published, not who published it.
  sha256 = {
    "1.1.45" = "9acfe68419c4d06a45c550321b3212762d92f41465062ca4ea19e632ee5d216e"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ THE ONE DEFAULT THAT IS ON AND WOULD FAIL. configure.ac:187-200 builds
      # the Python bindings unless `--without-python` ("(on)", and the test is
      # `!= "xno"`): AM_PATH_PYTHON then PKG_CHECK_MODULES for python-X.Y, a
      # configure error where no Python carries a .pc. No Python is declared.
      "--without-python",

      # (off) at :202-205, `!= "yes"`: exslt's crypto functions need libgcrypt
      # (:236), which this tree does not have. Named so that a host libgcrypt
      # is never picked up through a flip of the default.
      "--without-crypto",

      # Both (off): `!= "yes"` at :255 and :267, though the help text at :254
      # and :266 says "(on)". The generated code is the fact, as it was for
      # libxml2's --with-python.
      "--without-debug",
      "--without-debugger",

      # (on) at :280 (`= "no"` turns it off), the profiler is part of the
      # library's ordinary feature set and stays.
      "--with-profiler",

      # (off) at :447-452. Plugins load shared objects at run time; none are
      # shipped, so the capability would only widen the attack surface.
      "--without-plugins",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile.am:13 `bin_SCRIPTS = xslt-config` is a script and not promised, as
# xml2-config is not (libxml2's recipe); xsltproc/Makefile.am:5 is the program.
provides = [
  "bin/xsltproc",
]

test {
  script = [
    "test -f \"{{prefix}}/include/libxslt/xslt.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/libxslt.pc\"",
    "test -f \"{{prefix}}/lib/pkgconfig/libexslt.pc\"",
    "\"{{prefix}}/bin/xsltproc\" --version 2>&1 | grep -q \"{{version}}\"",

    # A transform that has to produce a value, and a stylesheet that is
    # refused: a processor that accepts anything also "runs".
    {
      run = <<EOT
set -eu
cat > t.xsl <<'XSL'
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:template match="/a"><xsl:value-of select="count(b)"/></xsl:template>
</xsl:stylesheet>
XSL
printf '<a><b/><b/><b/></a>\n' > in.xml
out=$("{{prefix}}/bin/xsltproc" t.xsl in.xml)
test "$out" = "3"
printf '<not-a-stylesheet/>\n' > bad.xsl
if "{{prefix}}/bin/xsltproc" bad.xsl in.xml >/dev/null 2>&1; then
  echo "xsltproc accepted a document that is not a stylesheet" >&2
  exit 1
fi
EOT
    },

    # The bindings flag, asserted on the installed tree.
    {
      run = <<EOT
if ls -d "{{prefix}}"/lib/python* >/dev/null 2>&1; then
  echo "python bindings were installed: --without-python was dropped" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Copyright",      # :1-20 the MIT text for libxslt, libexslt covered below it
    "configure.ac",   # :25 libxml2 >= 2.15.1; :187-200 python (on), the build fails without a Python .pc; :202-205 crypto (off); :254-261 debug and :266-273 debugger (off, help says on); :279-287 profiler (on); :405-413 libxml found by pkg-config; :447-452 plugins (off)",
    "Makefile.am",    # :13 bin_SCRIPTS = xslt-config; :46 libxslt.pc and libexslt.pc
    "xsltproc/Makefile.am", # :5 bin_PROGRAMS = xsltproc
    "https://download.gnome.org/sources/libxslt/cache.json", # the version enumeration; 1.1.45 newest .tar.xz
    "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.45.sha256sum", # the digest
  ]

  consulted = [
    "projects/gnome.org/libxml2/package.hcl (this tree): the cache.json enumeration and the series-directory url",
    "go-zpkg/recipes#214 and projects/postgresql.org/package.hcl: libxslt 1.1.45 links libxml2.so.16, so the range follows libxml2 2.15",
  ]

  note = <<EOT
NOT BUILT. No session here can run the factory. The configure switches were
read from configure.ac, and the three whose help text says "(on)" (python,
debug, debugger) were read from their tests rather than their help: python is
the only one that is really on.

No signature exists upstream; the checksum file is the second witness and is
upstream's own statement about the same bytes.
EOT
}
