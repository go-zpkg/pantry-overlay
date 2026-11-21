# cpan.org/Module-Build — Module::Build, the pure-Perl build system po4a's
# Build.PL runs under (`configure_requires { Module::Build => 0.42 }`).
# Written from its own files at 0.4234 (go-zpkg/packages#440), as a dependency
# of po4a.org. Perl dropped it from core at 5.32, so a perl.org build has none.

summary = "Module::Build: build and install Perl modules with a Perl-only Build.PL"

# LICENSE:4-19 and :273-279 carry both texts of "the same terms as the Perl 5
# programming language system itself"; Build.PL:16 `license => 'perl'`.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/L/LE/LEONT/"
  match = "/Module-Build-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/Module-Build-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # Build.PL:30 `'perl' => '5.006001'`.
  "perl.org" = ">=5.8"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/L/LE/LEONT/Module-Build-{{version.raw}}.tar.gz"
  strip-components = 1

  # 311666 bytes. Three readings agree: the local hash, the sha256 field of
  # fastapi.metacpan.org/v1/release/Module-Build, and the sha256 CPAN
  # publishes in authors/id/L/LE/LEONT/CHECKSUMS. All three sit on or beside
  # the same host as the archive: continuity, not independence.
  sha256 = {
    "0.4234" = "66aeac6127418be5e471ead3744648c766bd01482825c5b66652675f2bc86a8f"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # Module::Build builds itself with Build.PL:9 ("We use Module::Build to
    # test & install itself"); --install_base puts bin/ and lib/perl5/ under
    # the prefix.
    "perl Build.PL --install_base {{prefix}}",
    "./Build",
    "./Build install",

    # bin/config_data starts with the builder's absolute perl path.
    "fix-shebangs.ts {{prefix}}/bin/config_data",
  ]
}

provides = [
  "bin/config_data",
]

test {
  script = [
    "perl -Mlib={{prefix}}/lib/perl5 -MModule::Build -e 'print \"$Module::Build::VERSION\\n\"' | grep -F {{version.raw}}",
  ]
}

provenance {
  read = [
    "Build.PL",    # :9-10 builds itself; :16 license perl; :30 requires perl 5.006001; :119 script_files bin/config_data
    "LICENSE",     # :4-19 the Perl 5 terms; :273-279 the Artistic License 1.0
    "https://cpan.metacpan.org/authors/id/L/LE/LEONT/CHECKSUMS", # the sha256 for 0.4234
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/Module-Build", # the download_url and sha256 field, for facts only
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; this recipe passed
`zpkb lint` only. The inputs are traced to lines in Module::Build's own files.

The digest has no signature behind it: CPAN's CHECKSUMS is clearsigned by a
PAUSE key whose fingerprint was not found published, so it is a published
checksum on the archive's own host, not an independent warrant.
EOT
}
