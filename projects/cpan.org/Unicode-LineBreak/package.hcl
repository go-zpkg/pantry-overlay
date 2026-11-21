# cpan.org/Unicode-LineBreak — Unicode::LineBreak, which provides
# Unicode::GCString for po4a's AsciiDoc and VimHelp modules (po4a Build.PL:34
# `recommends { 'Unicode::GCString' => 0 }`). Written from its own files at
# 2019.001 (go-zpkg/packages#440). XS, with a bundled copy of libsombok.

summary = "Unicode::LineBreak: UAX #14 line breaking, and Unicode::GCString"

# Makefile.PL:225 `'LICENSE' => 'perl'`; lib/Unicode/LineBreak.pod:981 "under
# the same terms as Perl itself". The ARTISTIC and GPL files ship.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/N/NE/NEZUMI/"
  match = "/Unicode-LineBreak-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/Unicode-LineBreak-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # Makefile.PL:226 MIN_PERL_VERSION 5.008.
  "perl.org" = ">=5.8"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/N/NE/NEZUMI/Unicode-LineBreak-{{version.raw}}.tar.gz"
  strip-components = 1

  # 312225 bytes. The local hash, fastapi.metacpan.org/v1/release/
  # Unicode-LineBreak and authors/id/N/NE/NEZUMI/CHECKSUMS agree; same host as
  # the archive.
  sha256 = {
    "2019.001" = "486762e4cacddcc77b13989f979a029f84630b8175e7fef17989e157d4b6318a"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # ⛔ LOAD-BEARING. Makefile.PL:128-131 asks `pkg-config` for a system
    # sombok >= 2.4.0 and uses it when found, :133 builds the bundled sombok/
    # only when not. That is auto-detection of whatever the builder has
    # installed; `--with-bundled-sombok` (:93-94) makes it the bundled copy
    # always.
    "perl Makefile.PL INSTALL_BASE={{prefix}} --with-bundled-sombok",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = []

test {
  script = [
    "perl -Mlib={{prefix}}/lib/perl5 -MUnicode::LineBreak -e 'print Unicode::LineBreak->VERSION, \"\\n\"' | grep -F {{version.raw}}",
    "perl -Mlib={{prefix}}/lib/perl5 -MUnicode::GCString -e 'exit(Unicode::GCString->new(\"abc\")->length == 3 ? 0 : 1)'",
  ]
}

provenance {
  read = [
    "Makefile.PL",                       # :9-10 sombok 2.4.0..2.99.99; :90-94 --with-bundled-sombok; :128-141 pkg-config probe else bundled; :225-226 LICENSE perl, MIN_PERL_VERSION 5.008
    "lib/Unicode/LineBreak.pod",         # :981 the licence
    "sombok/README",                     # the bundled library
    "https://cpan.metacpan.org/authors/id/N/NE/NEZUMI/CHECKSUMS", # the sha256 for 2019.001
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/Unicode-LineBreak", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it.

2019.001 is the newest release `versions` resolves; its date is 2018-12-29.
EOT
}
