# cpan.org/YAML-Tiny — YAML::Tiny, the YAML reader/writer po4a's Yaml module
# uses (po4a Build.PL:39 `recommends { 'YAML::Tiny' => 0 }`). Written from its
# own files at 1.76 (go-zpkg/packages#440). Pure Perl.

summary = "YAML::Tiny: read/write YAML in a subset, with no dependencies"

# Makefile.PL:16 `"LICENSE" => "perl"`; lib/YAML/Tiny.pm:1482 "under the same
# terms as Perl itself", :1484-1485 "the LICENSE file included with this module".
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/E/ET/ETHER/"
  match = "/YAML-Tiny-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/YAML-Tiny-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # Makefile.PL:17 MIN_PERL_VERSION 5.008001.
  "perl.org" = ">=5.8.1"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/E/ET/ETHER/YAML-Tiny-{{version.raw}}.tar.gz"
  strip-components = 1

  # 75559 bytes. The local hash, fastapi.metacpan.org/v1/release/YAML-Tiny and
  # authors/id/E/ET/ETHER/CHECKSUMS agree; same host as the archive.
  sha256 = {
    "1.76" = "a8d584394cf069bf8f17cba3dd5099003b097fce316c31fb094f1b1c171c08a3"
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
    "perl -Mlib={{prefix}}/lib/perl5 -MYAML::Tiny -e 'print YAML::Tiny->VERSION, \"\\n\"' | grep -F {{version.raw}}",
    "perl -Mlib={{prefix}}/lib/perl5 -MYAML::Tiny -e 'my $y = YAML::Tiny->read_string(\"a: 1\\n\"); exit($y->[0]{a} == 1 ? 0 : 1)'",
  ]
}

provenance {
  read = [
    "Makefile.PL",         # :16 LICENSE perl; :17 MIN_PERL_VERSION 5.008001; :19 PREREQ_PM
    "lib/YAML/Tiny.pm",    # :1482-1485 the licence statement
    "https://cpan.metacpan.org/authors/id/E/ET/ETHER/CHECKSUMS", # the sha256 for 1.76
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/YAML-Tiny", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it.
EOT
}
