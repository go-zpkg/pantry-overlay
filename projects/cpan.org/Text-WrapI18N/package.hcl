# cpan.org/Text-WrapI18N — Text::WrapI18N, which po4a uses to wrap long error
# lines (po4a Build.PL:25 `recommends { 'Text::WrapI18N' => 0 }`). Written from
# its own files at 0.06 (go-zpkg/packages#440). Pure Perl over Text::CharWidth.

summary = "Text::WrapI18N: line wrapping aware of multibyte character widths"

# WrapI18N.pm:236-237 "under the same terms as Perl itself".
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/K/KU/KUBOTA/"
  match = "/Text-WrapI18N-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/Text-WrapI18N-/", "/\\.tar\\.gz/"]
}

dependencies = {
  "perl.org"                = ">=5.8"
  # Makefile.PL:5-7 `'Text::CharWidth' => '0.02'`.
  "cpan.org/Text-CharWidth" = ">=0.02"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/K/KU/KUBOTA/Text-WrapI18N-{{version.raw}}.tar.gz"
  strip-components = 1

  # 3812 bytes. The local hash, fastapi.metacpan.org/v1/release/Text-WrapI18N
  # and authors/id/K/KU/KUBOTA/CHECKSUMS agree; same host as the archive.
  sha256 = {
    "0.06" = "4bd29a17f0c2c792d12c1005b3c276f2ab0fae39c00859ae1741d7941846a488"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    "perl Makefile.PL INSTALL_BASE={{prefix}}",
    "make install",
  ]
}

provides = []

test {
  script = [
    # Text::CharWidth lives under the dependency's prefix, not ours.
    "perl -Mlib={{prefix}}/lib/perl5 -Mlib={{deps.cpan.org/Text-CharWidth.prefix}}/lib/perl5 -MText::WrapI18N -e 'print Text::WrapI18N->VERSION, \"\\n\"' | grep -F {{version.raw}}",
  ]
}

provenance {
  read = [
    "Makefile.PL",   # :1-8 PREREQ_PM Text::CharWidth 0.02
    "WrapI18N.pm",   # :236-237 the licence
    "https://cpan.metacpan.org/authors/id/K/KU/KUBOTA/CHECKSUMS", # the sha256 for 0.06
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/Text-WrapI18N", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it.
EOT
}
