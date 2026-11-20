# subversion — Apache Subversion, the centralised version-control system.
#
# ⛔ WRITTEN FROM SUBVERSION'S OWN FILES at 1.15.0, continuing
# go-zpkg/packages#440 step 1. It was an eleven-line fragment naming
# dependencies and nothing else: no source, no build, no version.

summary = "Apache Subversion: centralised version-control client, server and admin tools"

# LICENSE opens with the Apache License 2.0 text ("Apache License / Version
# 2.0, January 2004", :2-3). The tarball also carries code under other
# licences (the tail of LICENSE lists them); the project's own is Apache-2.0.
license = "Apache-2.0"

versions {
  # ⛔ archive.apache.org, NOT downloads.apache.org: the mirror host keeps only
  # the current releases (1.14.5 and 1.15.0 on 2026-11-20). The archive index
  # has 216 tarball names, release candidates and alphas among them, so the
  # match is the three-number form only.
  url   = "https://archive.apache.org/dist/subversion/"
  match = "/subversion-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^subversion-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://archive.apache.org/dist/subversion/subversion-{{version.raw}}.tar.bz2"
  strip-components = 1

  # TWO WITNESSES PER VERSION, INDEPENDENT:
  #
  #   1. The detached signature .tar.bz2.asc, verified with `zpkb sourcepin`
  #      against a key taken from https://downloads.apache.org/subversion/KEYS
  #      (Apache's own published keys; no keyserver was asked):
  #        1.15.0  E7B2A7F4EC28BE9FF8B38BA4B64FFF1209F9FA74  Evgeny Kotkov
  #        1.14.5  8BC4DAE0C5A4D65F404401074F7DBAA99A59B973  Stefan Sperling
  #      sourcepin reads only the FIRST signature packet of an .asc, so the
  #      key of the first signer is the one passed (Nathan Hartman's
  #      3F8E467CB3366E3013E1120D583F00ADF981C39F signed both and was refused
  #      for that reason).
  #
  #   2. The release's own published .tar.bz2.sha512, which matches
  #      `shasum -a 512` of the bytes fetched here:
  #        1.15.0  6bb79686…282ec2   (8611559 bytes)
  #        1.14.5  e4800564…edd0321  (8675355 bytes)
  #
  # ⛔ 1.15.0 IS THE NEWEST `versions` RESOLVES (2026-10-07); 1.14.5 is the
  # LTS line (2024-12-08). Older releases resolve and carry no digest.
  #
  # ⛔ NO `sha` FIELD: Apache publishes SHA-512, not SHA-256.
  sha256 = {
    "1.15.0" = "dfb7b1e5270c7def971ccbd5938b0c03b1b5bd60b6674a2d8a74a9560839fb8c"
    "1.14.5" = "e78a29e7766b8b7b354497d08f71a55641abc53675ce1875584781aae35644a1"
  }
}

# From the fragment this replaces, each one tied to the configure option that
# uses it (configure.ac line numbers at 1.15.0).
dependencies = {
  "apache.org/apr"                  = "^1"  # --with-apr, find_apr.m4:100
  "apache.org/apr-util"             = "^1"  # --with-apr-util, find_apu.m4:110
  "apache.org/serf"                 = "^1"  # --with-serf, serf.m4:59; SVN_LIB_SERF(1,3,4) at configure.ac:233
  "github.com/JuliaStrings/utf8proc" = "^2" # --with-utf8proc, utf8proc.m4:28
  "gnu.org/gettext"                 = "^1"  # NLS, configure.ac:771-790
  "kerberos.org"                    = "^1.20"
  "libexpat.github.io"              = "^2"  # --with-expat, configure.ac:482
  "lz4.org"                         = "^1"  # --with-lz4, lz4.m4:28
  "openssl.org"                     = "^3"
  "sqlite.org"                      = "^3"  # --with-sqlite, sqlite.m4:53; minimum 3.24.0 (configure.ac:264-265)
  "zlib.net"                        = "^1.2" # --with-zlib, zlib.m4:31
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # The libraries it links, each by an explicit prefix, so what the
      # build finds is what the recipe declares and not what a sandbox holds.
      "--with-apr={{deps.apache.org/apr.prefix}}",
      "--with-apr-util={{deps.apache.org/apr-util.prefix}}",

      # ⛔⛔ `--with-serf=PREFIX` IS THE ONLY WAY TO MAKE A MISSING SERF AN
      # ERROR. serf.m4:62-69 sets serf_required for any value, and :84-86 turns
      # a miss into AC_MSG_ERROR. With no option serf is looked for through
      # pkg-config and DROPPED SILENTLY when absent (:83, SVN_DOWNLOAD_SERF
      # only prints "libsvn_ra_serf will not be built"), and the result would
      # be a client that cannot speak http:// or https://. The test asserts
      # ra_serf in `svn --version`.
      "--with-serf={{deps.apache.org/serf.prefix}}",

      "--with-sqlite={{deps.sqlite.org.prefix}}",
      "--with-zlib={{deps.zlib.net.prefix}}",

      # lz4.m4:28-40 and utf8proc.m4:28-40 default to `std`: the system copy.
      "--with-lz4={{deps.lz4.org.prefix}}",
      "--with-utf8proc={{deps.github.com/JuliaStrings/utf8proc.prefix}}",

      # configure.ac:482-486: INCLUDES:LIB_SEARCH_DIRS:LIBS.
      "--with-expat={{deps.libexpat.github.io.prefix}}/include:{{deps.libexpat.github.io.prefix}}/lib:expat",

      # EVERY OPTIONAL FEATURE IS STATED, NOT LEFT TO PROBING: each of these
      # is "enabled by default if found", so the same recipe would build a
      # different svn on a sandbox that happens to hold the library.
      "--without-apxs",          # apache.m4:36-48, mod_dav_svn / mod_authz_svn
      "--without-berkeley-db",   # berkeley-db.m4:48-58, the BDB filesystem
      "--without-sasl",          # sasl.m4:31-40, svnserve SASL
      "--without-libmagic",      # configure.ac:905-932, mime-type guessing
      "--without-gnome-keyring", # libsecret.m4:26-30, default auto
      "--without-swig-perl",     # configure.ac:1404
      "--without-swig-python",   # configure.ac:1449
      "--without-swig-ruby",     # configure.ac:1475
      # KWallet (kwallet.m4:33), javahl (configure.ac:1719) and svnxx
      # (configure.ac:1656) default to NO and are not requested.
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# build.conf marks `install = bin` for exactly these ten programs
# (:145-222, :464): svn, svnadmin, svndumpfilter, svnlook, svnserve, svnsync,
# svnversion, svnrdump, svnmucc and svnfsfs.
provides = [
  "bin/svn",
  "bin/svnadmin",
  "bin/svndumpfilter",
  "bin/svnfsfs",
  "bin/svnlook",
  "bin/svnmucc",
  "bin/svnrdump",
  "bin/svnserve",
  "bin/svnsync",
  "bin/svnversion",
]

test {
  script = [
    "svn --version | grep -q \"{{version.raw}}\"",

    # THE REGRESSION TEST FOR --with-serf: without ra_serf this client cannot
    # reach an http(s) repository.
    "svn --version | grep -q ra_serf",
    "svnadmin --version | grep -q \"{{version.raw}}\"",
    "svnadmin create repo",
    "svnlook youngest repo | grep -qx 0",
  ]
}

provenance {
  read = [
    "configure.ac",                  # :205 SVN_LIB_APR; :220 SVN_LIB_APRUTIL; :233 SVN_LIB_SERF(1,3,4); :264-265 sqlite 3.24.0 min; :482-486 --with-expat; :654-657 gpg-agent; :771-790 nls; :905-932 libmagic; :1404 :1449 :1475 swig; :1656-1664 svnxx; :1719-1726 javahl
    "build/ac-macros/serf.m4",       # :59-86 --with-serf=PREFIX makes a miss fatal; :83 silent drop otherwise
    "build/ac-macros/lz4.m4",        # :28-40 default std
    "build/ac-macros/utf8proc.m4",   # :28-40 default std
    "build/ac-macros/sasl.m4",       # :31-40 auto unless --with-sasl
    "build/ac-macros/apache.m4",     # :36-61 apxs probed in standard dirs when not given
    "build/ac-macros/berkeley-db.m4", # :48-58
    "build/ac-macros/libsecret.m4",  # :26-30 default auto
    "build/ac-macros/kwallet.m4",    # :33 default no
    "build.conf",                    # :145-222 and :464 the programs with install = bin
    "LICENSE",                       # Apache License 2.0, :2-3
    "NOTICE",
    "INSTALL",
    "README",
  ]

  consulted = [
    "https://downloads.apache.org/subversion/",
    "https://downloads.apache.org/subversion/KEYS",
    "https://archive.apache.org/dist/subversion/",
  ]

  note = <<EOT
Autotools build, written from configure.ac and its macros. Nothing was converted.

⛔ NOT RUN: the build was written without a local build of the dependency
closure (apr, apr-util, sqlite and utf8proc are upstream recipes this tree does
not hold), so the script is read-checked, not executed.

⛔ DARWIN: macosx.m4:76 defines --enable-keychain, on by default there; it is
left to its default because it links system frameworks, not a recipe dependency.
EOT
}
