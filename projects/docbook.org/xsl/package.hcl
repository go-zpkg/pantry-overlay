# docbook.org/xsl — the DocBook XSL stylesheets (the no-namespace edition),
# which po4a's build runs through `xsltproc` to turn its two DocBook manpages
# into roff (po4a Po4aBuilder.pm:253-281). Written from the release's own
# files at 1.79.2 (go-zpkg/packages#440). No compiler, no configure: the
# stylesheets are installed as data.

summary = "DocBook XSL stylesheets: DocBook to HTML, FO, manpages and more"

# COPYING:1-30 is the MIT-style notice ("Permission is hereby granted, free of
# charge … without restriction"), plus a clause that a derived, publicly
# distributed stylesheet must carry a different name — SPDX calls that
# DocBook-Stylesheet.
license = "DocBook-Stylesheet"

versions {
  # ⛔ The tag list holds `release/X.Y.Z` AND dozens of `snapshot/…` tags, the
  # snapshots being the later ones; only the release tags are versions.
  github = "docbook/xslt10-stylesheets/tags"
  ignore = "/^snapshot/"
  strip  = "/^release\\//"
}

distributable {
  # The `nons` archive is the no-namespace edition, which is the one
  # `http://docbook.sourceforge.net/release/xsl/current/` has always named and
  # the one po4a asks for (Po4aBuilder.pm:257).
  url              = "https://github.com/docbook/xslt10-stylesheets/releases/download/release/{{version.raw}}/docbook-xsl-nons-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 23400667 bytes. Two fetches agree, the builder's own fetcher
  # (`zpkb sourcepin`) and curl. The release publishes no signature and no
  # checksum file, and GitHub's asset `digest` field is absent for it; the
  # sourceforge mirror it once had no longer serves the file. So this is one
  # host fetched twice: it catches a corrupt download, not a replaced asset.
  sha256 = {
    "1.79.2" = "ee8b9eca0b7a8f89075832a2da7534bce8c5478fc8fc2676f512d5d87d832102"
  }
}

build {
  # ⛔ A CATALOG THAT NAMES THE URL PO4A ASKS FOR. The archive's catalog.xml
  # rewrites `http://cdn.docbook.org/release/xsl-nons/…` only, but
  # Po4aBuilder.pm:257-266 asks `xmlcatalog` to resolve
  # `http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl`
  # and, on a miss, hands xsltproc that http URL under `--nonet` (:276), which
  # fails. The second catalog maps the sourceforge name to the same files; its
  # rewritePrefix is relative to the catalog file, as the upstream one is, so
  # the install stays relocatable.
  script = <<EOT
set -eu
dest="{{prefix}}/share/xml/docbook-xsl"
mkdir -p "$dest"
cp -R . "$dest"
cat > "$dest/catalog-sourceforge.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
  <rewriteURI uriStartString="http://docbook.sourceforge.net/release/xsl/current/" rewritePrefix="./"/>
  <rewriteSystem systemIdStartString="http://docbook.sourceforge.net/release/xsl/current/" rewritePrefix="./"/>
</catalog>
XML
EOT
}

provides = []

test {
  script = [
    "test -f \"{{prefix}}/share/xml/docbook-xsl/manpages/docbook.xsl\"",
    "test -f \"{{prefix}}/share/xml/docbook-xsl/catalog.xml\"",
    "grep -F 'docbook.sourceforge.net/release/xsl/current/' \"{{prefix}}/share/xml/docbook-xsl/catalog-sourceforge.xml\"",
    "grep -F {{version.raw}} \"{{prefix}}/share/xml/docbook-xsl/VERSION\"",
  ]
}

provenance {
  read = [
    "COPYING",       # :1-30 the licence notice; the different-name clause for derived stylesheets
    "catalog.xml",   # rewrites cdn.docbook.org/release/xsl-nons/ only, with a relative rewritePrefix
    "INSTALL",       # :87 "The catalog.xml file should be packaged"
    "VERSION",       # the version string the test greps
    "manpages/docbook.xsl", # the entry point po4a's xsltproc call names
    "https://github.com/docbook/xslt10-stylesheets/releases", # release/1.79.2 and its nons archive
  ]

  consulted = [
    "mquinson/po4a Po4aBuilder.pm", # :253-281 how the stylesheet is located and invoked; read at 0.74
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. Nothing here was run through xsltproc.

Unverified assumptions, stated so they are not mistaken for findings:

  - po4a runs `xmlcatalog --noout "" <url>` and parses `file:/…` out of the
    answer. For that to see catalog-sourceforge.xml the consumer must put it
    in XML_CATALOG_FILES; po4a.org's build does.
  - The two manpages are DocBook XML 4.5 documents whose DOCTYPE names a DTD
    this tree does not carry. They contain no entity references (grep for
    `&name;` finds none), so a failed DTD load under --nonet should only
    warn. Not run.
EOT
}
