# cpan.org/Text-CharWidth — Text::CharWidth, the XS column-width primitive
# Text::WrapI18N needs (Makefile.PL:6 of Text-WrapI18N-0.06). Written from its
# own files at 0.04 (go-zpkg/packages#440), as part of po4a.org's closure.

summary = "Text::CharWidth: get the display width of a character or string"

# CharWidth.pm:75-76 "under the same terms as Perl itself".
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/K/KU/KUBOTA/"
  match = "/Text-CharWidth-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/Text-CharWidth-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # CharWidth.xs is compiled against perl's headers. Makefile.PL:1 `use 5.008`.
  "perl.org" = ">=5.8"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/K/KU/KUBOTA/Text-CharWidth-{{version.raw}}.tar.gz"
  strip-components = 1

  # 8387 bytes. The local hash, fastapi.metacpan.org/v1/release/Text-CharWidth
  # and authors/id/K/KU/KUBOTA/CHECKSUMS agree; same host as the archive.
  sha256 = {
    "0.04" = "abded5f4fdd9338e89fd2f1d8271c44989dae5bf50aece41b6179d8e230704f8"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # Makefile.PL:8 PREREQ_PM is empty and :12 LIBS is empty: no library is
    # probed, it uses libc's wcwidth.
    "perl Makefile.PL INSTALL_BASE={{prefix}}",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = []

test {
  script = [
    "perl -Mlib={{prefix}}/lib/perl5 -MText::CharWidth=mbswidth -e 'exit(mbswidth(\"abc\") == 3 ? 0 : 1)'",
  ]
}

provenance {
  read = [
    "Makefile.PL",   # :6-14 no prerequisites, no LIBS
    "CharWidth.pm",  # :75-76 the licence
    "CharWidth.xs",  # the XS source compiled
    "https://cpan.metacpan.org/authors/id/K/KU/KUBOTA/CHECKSUMS", # the sha256 for 0.04
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/Text-CharWidth", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it. mbswidth's result depends on the process locale; the
test uses ASCII so it holds under the C locale.
EOT
}
