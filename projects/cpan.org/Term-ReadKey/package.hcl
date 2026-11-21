# cpan.org/Term-ReadKey — Term::ReadKey, which po4a uses to detect the
# terminal width for Text::WrapI18N (po4a Build.PL:28-30 `recommends`).
# Written from its own files at 2.38 (go-zpkg/packages#440). XS.
# The CPAN distribution is named TermReadKey.

summary = "Term::ReadKey: simple terminal control, including terminal size"

# README:6-16: "dual licensed" — the original terms, or the Perl terms
# (the GNU GPL or the Artistic License); Makefile.PL:15 `LICENSE => 'perl'`.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/J/JS/JSTOWE/"
  match = "/TermReadKey-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/TermReadKey-/", "/\\.tar\\.gz/"]
}

dependencies = {
  "perl.org" = ">=5.8"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/J/JS/JSTOWE/TermReadKey-{{version.raw}}.tar.gz"
  strip-components = 1

  # The local hash, fastapi.metacpan.org/v1/release/TermReadKey and
  # authors/id/J/JS/JSTOWE/CHECKSUMS agree; same host as the archive. The
  # tarball also ships a SIGNATURE file (Module::Signature), which was not
  # checked: no key fingerprint was found published.
  sha256 = {
    "2.38" = "5a645878dc570ac33661581fbb090ff24ebce17d43ea53fd22e105a856a47290"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # Makefile.PL:47 generates ReadKey.pm from ReadKey.pm.PL; :53-54 leave
    # `-lbsd` commented out, so no extra library is linked.
    "perl Makefile.PL INSTALL_BASE={{prefix}}",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = []

test {
  script = [
    "perl -Mlib={{prefix}}/lib/perl5 -MTerm::ReadKey -e 'print Term::ReadKey->VERSION, \"\\n\"' | grep -F {{version.raw}}",
  ]
}

provenance {
  read = [
    "Makefile.PL",     # :15 LICENSE perl; :18 CONFIGURE_REQUIRES; :47 PL_FILES ReadKey.pm.PL; :53-54 no extra INC/LIBS
    "README",          # :6-16 the dual licence
    "ReadKey.xs",      # the XS source compiled
    "https://cpan.metacpan.org/authors/id/J/JS/JSTOWE/CHECKSUMS", # the sha256 for 2.38
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/TermReadKey", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it. The version test avoids reading a terminal: the
module's size functions need a tty the factory does not have.
EOT
}
