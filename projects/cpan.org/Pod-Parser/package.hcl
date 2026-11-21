# cpan.org/Pod-Parser — Pod::Parser, used by po4a's Pod and KernelHelp modules
# (po4a Build.PL:22 `recommends { 'Pod::Parser' => 0 }`). Written from its own
# files at 1.67 (go-zpkg/packages#440). Pure Perl; removed from core at 5.32.

summary = "Pod::Parser: base class for POD parsers and translators"

# lib/Pod/Parser.pm:6 and :1823-1831 "under the same terms as Perl itself",
# naming the Artistic License.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/M/MA/MAREKR/"
  match = "/Pod-Parser-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/Pod-Parser-/", "/\\.tar\\.gz/"]
}

dependencies = {
  "perl.org" = ">=5.8"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/M/MA/MAREKR/Pod-Parser-{{version.raw}}.tar.gz"
  strip-components = 1

  # 80961 bytes. The local hash, fastapi.metacpan.org/v1/release/Pod-Parser
  # and authors/id/M/MA/MAREKR/CHECKSUMS agree; same host as the archive.
  sha256 = {
    "1.67" = "5deccbf55d750ce65588cd211c1a03fa1ef3aaa15d1ac2b8d85383a42c1427ea"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # Makefile.PL:74-75 PL_FILES/EXE_FILES generate scripts/podselect.
    "perl Makefile.PL INSTALL_BASE={{prefix}}",
    "make install",
    "fix-shebangs.ts {{prefix}}/bin/podselect",
  ]
}

provides = [
  "bin/podselect",
]

test {
  script = [
    "perl -Mlib={{prefix}}/lib/perl5 -MPod::Parser -e 'print Pod::Parser->VERSION, \"\\n\"' | grep -F {{version.raw}}",
  ]
}

provenance {
  read = [
    "Makefile.PL",          # :37-42 EXE_FILES; :59-63 PREREQ_PM (Test::More, Cwd, File::Basename); :74-75 PL_FILES
    "lib/Pod/Parser.pm",    # :6 and :1823-1831 the licence
    "scripts/podselect.PL", # the one script installed
    "https://cpan.metacpan.org/authors/id/M/MA/MAREKR/CHECKSUMS", # the sha256 for 1.67
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/Pod-Parser", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it.
EOT
}
