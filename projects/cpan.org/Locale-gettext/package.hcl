# cpan.org/Locale-gettext — Locale::gettext, which po4a uses to translate its
# own messages (po4a Build.PL:36 `recommends { 'Locale::gettext' => '1.01' }`).
# Written from its own files at 1.07 (go-zpkg/packages#440). XS over libintl.

summary = "Locale::gettext: Perl bindings for the POSIX gettext functions"

# README:14-15 "either the GNU General Public License or the Artistic
# License"; Makefile.PL:46 `LICENSE => 'perl'`.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

versions {
  url   = "https://cpan.metacpan.org/authors/id/P/PV/PVANDRY/"
  match = "/Locale-gettext-\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/Locale-gettext-/", "/\\.tar\\.gz/"]
}

dependencies = {
  "perl.org"       = ">=5.8"
  # gettext.xs includes <libintl.h>; Makefile.PL:12-20 links libc's gettext or
  # `-lintl` and dies when neither works. gnu.org/gettext ships libintl.
  "gnu.org/gettext" = "^1"
}

distributable {
  url              = "https://cpan.metacpan.org/authors/id/P/PV/PVANDRY/Locale-gettext-{{version.raw}}.tar.gz"
  strip-components = 1

  # 8651 bytes. The local hash, fastapi.metacpan.org/v1/release/Locale-gettext
  # and authors/id/P/PV/PVANDRY/CHECKSUMS agree; same host as the archive.
  sha256 = {
    "1.07" = "909d47954697e7c04218f972915b787bd1244d75e3bd01620bc167d5bbc49c15"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    # ⛔ Makefile.PL:5-9 compiles its probes with $ENV{CC} (else perl's cc),
    # so naming the gettext prefix here makes the probe link the staged
    # libintl rather than whatever the host has. The build itself reads
    # INC/LIBS below.
    CC = "cc -I{{deps.gnu.org/gettext.prefix}}/include -L{{deps.gnu.org/gettext.prefix}}/lib"
  }

  script = [
    "perl Makefile.PL INSTALL_BASE={{prefix}} INC=-I{{deps.gnu.org/gettext.prefix}}/include \"LIBS=-L{{deps.gnu.org/gettext.prefix}}/lib -lintl\"",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = []

test {
  script = [
    "perl -Mlib={{prefix}}/lib/perl5 -MLocale::gettext -e 'print Locale::gettext->VERSION, \"\\n\"' | grep -F {{version.raw}}",
    # With no catalog installed, gettext returns the msgid unchanged.
    "perl -Mlib={{prefix}}/lib/perl5 -MLocale::gettext -e 'exit(gettext(\"hello\") eq \"hello\" ? 0 : 1)'",
  ]
}

provenance {
  read = [
    "Makefile.PL",   # :5-9 probe compiler from $ENV{CC}; :12-20 gettext in libc else -lintl; :25-27 optional dgettext/ngettext/bind_textdomain_codeset; :36 LIBS; :46 LICENSE perl
    "README",        # :14-15 the licence
    "gettext.xs",    # the XS source compiled
    "https://cpan.metacpan.org/authors/id/P/PV/PVANDRY/CHECKSUMS", # the sha256 for 1.07
  ]

  consulted = [
    "https://fastapi.metacpan.org/v1/release/Locale-gettext", # download_url and sha256, facts only
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe passed `zpkb lint` only; no session here can run
the factory. The digest rests on CPAN's published CHECKSUMS on the archive's
own host; its PAUSE signing key was not found published, so nothing
independent warrants it.

Unverified: whether the builder's runtime finds the staged libintl without an
rpath (Makefile.PL's `LIBS` is passed through to the link line only).
EOT
}
