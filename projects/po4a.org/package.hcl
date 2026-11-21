# po4a.org — po4a, "PO for anything": maintain translations of documentation
# (man pages, POD, AsciiDoc, XML, YAML …) with gettext PO files. Written from
# its own files at 0.74 (go-zpkg/packages#440). Pure Perl, built with
# Module::Build; the two DocBook manpages are turned into roff by xsltproc at
# build time.

summary = "po4a: maintain translations of documentation with gettext PO files"

# README.md:136 "under the terms of GPL v2.0 or later (GPL2+ -- see COPYING)".
license = "GPL-2.0-or-later"

versions {
  github = "mquinson/po4a/tags"
  strip  = "/^v/"
}

dependencies = {
  "perl.org" = ">=5.22"

  # `msgfmt`, `xgettext`, `msggrep`, `msgconv` and `msgexec` are run as
  # programs by the po4a scripts and modules.
  "gnu.org/gettext" = "^1"

  # The runtime CPAN modules Build.PL:21-40 lists under `recommends`. Each is a
  # recipe of its own; SGMLS is not packaged, so the Sgml module stays unusable.
  # Pod::Simple is part of perl itself.
  "cpan.org/YAML-Tiny"        = "*"
  "cpan.org/Pod-Parser"       = "*"
  "cpan.org/Unicode-LineBreak" = "*"
  "cpan.org/Text-WrapI18N"    = "*"
  "cpan.org/Term-ReadKey"     = "*"
  "cpan.org/Locale-gettext"   = "*"
}

distributable {
  url              = "https://github.com/mquinson/po4a/releases/download/v{{version.raw}}/po4a-{{version.raw}}.tar.gz"
  strip-components = 1

  # 5907018 bytes. The builder's own fetcher (`zpkb sourcepin`) and curl agree.
  # The release is a GitHub asset published without a signature or a checksum
  # file, so this is one host fetched twice: it catches a corrupt download, not
  # a replaced asset.
  sha256 = {
    "0.74" = "25fc323f2ba37bbd48c3af0ebf49952644b0e468261f98633e91219a838fe7c2"
  }
}

build {
  dependencies = {
    # Build.PL:16 configure_requires Module::Build >= 0.42.
    "cpan.org/Module-Build" = "*"
    "gnome.org/libxslt"     = "^1.1"
    "gnome.org/libxml2"     = "*"
    "docbook.org/xsl"       = "^1.79"
  }

  env {
    # ⛔ Po4aBuilder.pm:257-266 asks `xmlcatalog` to resolve the sourceforge URL
    # of the DocBook manpage stylesheet and falls back to fetching it over http
    # under `--nonet` (:276), which fails. docbook.org/xsl installs a catalog
    # that maps that URL to its own files; this makes xmlcatalog read it.
    XML_CATALOG_FILES = "{{deps.docbook.org/xsl.prefix}}/share/xml/docbook-xsl/catalog-sourceforge.xml"

    # Build.PL needs Module::Build, and the build needs the module recipes
    # above, all installed with INSTALL_BASE under lib/perl5.
    PERL5LIB = "{{deps.cpan.org/Module-Build.prefix}}/lib/perl5:{{deps.cpan.org/YAML-Tiny.prefix}}/lib/perl5:{{deps.cpan.org/Pod-Parser.prefix}}/lib/perl5"
  }

  script = [
    "perl Build.PL --install_base {{prefix}}",
    "./Build",
    "./Build install",
    # The scripts are installed with a `#!` naming the build-time perl.
    "fix-shebangs.ts {{prefix}}/bin/po4a {{prefix}}/bin/po4a-gettextize {{prefix}}/bin/po4a-updatepo {{prefix}}/bin/po4a-translate {{prefix}}/bin/po4a-normalize {{prefix}}/bin/msguntypot {{prefix}}/bin/po4a-display-man {{prefix}}/bin/po4a-display-pod",
  ]
}

# Build.PL:45-50 script_files.
provides = [
  "bin/po4a",
  "bin/po4a-gettextize",
  "bin/po4a-updatepo",
  "bin/po4a-translate",
  "bin/po4a-normalize",
  "bin/msguntypot",
  "bin/po4a-display-man",
  "bin/po4a-display-pod",
]

test {
  script = [
    "PERL5LIB={{prefix}}/lib/perl5:{{deps.cpan.org/YAML-Tiny.prefix}}/lib/perl5 po4a --version | grep -F {{version.raw}}",
  ]
}

provenance {
  read = [
    "Build.PL",         # :16 configure_requires Module::Build 0.42; :21-40 recommends; :45-50 script_files
    "Po4aBuilder.pm",   # :112 msgfmt; :174-283 the manpage and translation build; :257-276 xmlcatalog then xsltproc --nonet
    "META.yml",         # the declared requirements
    "COPYING",          # GPL v2
    "README.md",        # :136 GPL v2.0 or later
    "https://github.com/mquinson/po4a/releases", # v0.74 and its archive
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. Nothing here was run: not Build.PL, not xsltproc, not po4a.

Unverified assumptions, stated so they are not mistaken for findings:

  - The runtime modules are staged by their own recipes under
    <prefix>/lib/perl5; po4a's scripts do not know that. The test sets
    PERL5LIB by hand and no recipe in this tree has a mechanism that does it
    for a consumer, so an installed `po4a` finds YAML::Tiny, Unicode::GCString,
    Text::WrapI18N and the rest only when the caller sets PERL5LIB.
  - Only the module recipes this one lists are guaranteed on the build's
    PERL5LIB; the others are runtime only.
  - SGMLS is not packaged: the Sgml module and its tests are unusable, and the
    test suite was not run.
  - XML_CATALOG_FILES names catalog-sourceforge.xml, written by docbook.org/xsl
    and itself unbuilt.
EOT
}
