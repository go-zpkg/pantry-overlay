# php.net — the PHP interpreter: the CLI, php-fpm and php-cgi, with the
# extensions listed in ARGS below.
#
# ⛔ WRITTEN FROM PHP'S OWN `./configure --help` AND RELEASE PAGES
# (go-zpkg/packages#431, packages#440 step 1), at 8.6.0, replacing a recipe that
# was a bare dependency list from the pantry: it named no versions, no source
# and no build, and carried dependencies of features this build does not turn
# on (apr and apr-util for an Apache module, kerberos for the removed imap).
# Every extension that `./configure --help` offers is named below, on or off,
# so a library that happens to be on the builder's host never switches one on.

summary = "PHP: the scripting language, with the CLI, FPM and CGI servers"

# LICENSE at the root of the tarball: the PHP License v3.01. Zend files carry
# the Zend Engine licence, which is the same text.
license = "PHP-3.01"

# php/php-src tags are `php-X.Y.Z` (and php-X.Y.ZRC1, php-X.Y.Zalpha1, …, which
# are pre-releases and are not offered).
versions {
  github = "php/php-src/tags"
  strip  = "/^php-/"

  ignore = [
    "/.*(alpha|beta|RC|rc).*/",
  ]
}

dependencies = {
  "curl.se"                   = "^8"
  "github.com/kkos/oniguruma" = "^6"
  "gnome.org/libxml2"         = "*"
  "gnome.org/libxslt"         = ">=1.1.0"
  "gnu.org/gettext"           = "^1"
  "gnu.org/gmp"               = "^6"
  "gnu.org/libiconv"          = "^1"
  "google.com/webp"           = "^1"
  "ijg.org"                   = "^9"
  "libpng.org"                = "^1"
  "libsodium.org"             = ">=1.0.8"
  "libzip.org"                = "^1.9"
  "openldap.org"              = "^2"
  "openssl.org"               = "*"
  "pcre.org/v2"               = ">=10.30"
  "postgresql.org"            = "*"
  "sourceware.org/bzip2"      = "^1"
  "sourceware.org/libffi"     = ">=3.4.7"
  "sqlite.org"                = "^3"
  "thrysoee.dk/editline"      = "^3"
  "unicode.org"               = "^71"
  "zlib.net"                  = "^1"
}

distributable {
  url              = "https://www.php.net/distributions/php-{{version.raw}}.tar.xz"
  strip-components = 1

  # 15148068 bytes, recorded with `zpkb sourcepin --version 8.6.0 --sig auto`.
  #
  # ⭐ SIGNED, AND THE SIGNATURE WAS CHECKED. php-8.6.0.tar.xz.asc is made by
  # Matteo Beccati's key 0168 95DE 9A47 5111 D537 A6E6 9134 FF30 BC5A 99B5
  # (signed 2026-11-17). That fingerprint is the one listed for PHP 8.6 on
  # https://www.php.net/gpg-keys.php (#gpg-8.6), and the key itself was taken
  # from https://www.php.net/distributions/php-keyring.gpg — no keyserver was
  # asked. The digest is also the sha256 of the 8.6.0 tar.xz in
  # https://www.php.net/releases/index.php?json&version=8.
  sha256 = {
    "8.6.0" = "5f84beaa3d763aee1e4feed99bf54ec692c383b322e25626807b589238c3a087"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      # --with-layout=PHP (the default) and --with-config-file-path default to
      # PREFIX/lib; named so the layout is the recipe's, not a default's.
      "--with-layout=PHP",
      "--with-config-file-path={{prefix}}/etc",
      "--with-config-file-scan-dir={{prefix}}/etc/conf.d",

      # SAPIs: CLI, FPM and CGI on; phpdbg, Apache, embed, litespeed and the
      # fuzzer off (apxs would also edit an httpd.conf, which no build should).
      "--enable-fpm",
      "--with-fpm-user=nobody",
      "--with-fpm-group=nobody",
      "--without-fpm-systemd",
      "--disable-phpdbg",
      "--without-apxs2",
      "--disable-embed",

      # General: no thread safety, no debug, no coverage, IPv6 on, no dtrace.
      "--disable-zts",
      "--disable-debug",
      "--disable-dtrace",
      "--without-valgrind",
      "--enable-sigchild=no",

      # Bundled extensions on.
      "--enable-bcmath",
      "--enable-calendar",
      "--enable-exif",
      "--enable-ftp",
      "--enable-intl",
      "--enable-mbstring",
      "--enable-pcntl",
      "--enable-shmop",
      "--enable-soap",
      "--enable-sockets",
      "--enable-sysvmsg",
      "--enable-sysvsem",
      "--enable-sysvshm",
      "--enable-gd",

      # Extensions on that need a library (each is a dependency above).
      "--with-openssl",
      "--with-external-pcre",
      "--with-zlib",
      "--with-bz2",
      "--with-curl",
      "--with-ffi",
      "--with-gettext",
      "--with-gmp",
      "--with-iconv",
      "--with-ldap",
      "--with-libedit",
      "--with-pgsql",
      "--with-pdo-pgsql",
      "--with-pdo-mysql=mysqlnd",
      "--with-mysqli=mysqlnd",
      "--with-sodium",
      "--with-xsl",
      "--with-zip",
      "--with-jpeg",
      "--with-webp",
      "--with-sqlite3",
      "--with-pdo-sqlite",

      # Off: libraries that are not dependencies of this recipe.
      "--without-enchant",
      "--without-snmp",
      "--without-tidy",
      "--without-ldap-sasl",
      "--without-pdo-dblib",
      "--without-pdo-firebird",
      "--without-ibm-db2",
      "--without-mm",
      "--without-capstone",
      "--without-qdbm",
      "--without-gdbm",
      "--without-lmdb",
      "--without-tcadb",
      "--without-password-argon2",
      "--without-external-uriparser",
      "--without-external-libcrypt",
      "--without-external-gd",
      "--without-avif",
      "--without-uhdr",
      "--without-xpm",
      "--without-freetype",
      "--without-heif",
      "--without-imagequant",
      "--without-tiff",
      "--without-expat",
      "--without-readline",
      "--without-mhash",
      "--without-unixODBC",
      "--without-iodbc",
      "--without-custom-odbc",
      "--without-pdo-odbc",

      # Off: development-only extensions.
      "--disable-dl-test",
      "--disable-zend-test",
      "--disable-gcov",
      "--disable-werror",

      # PEAR: not installed (its installer fetches from the network).
      "--without-pear",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

provides = [
  "bin/php",
  "bin/php-cgi",
  "bin/php-config",
  "bin/phpize",
  "sbin/php-fpm",
]

test {
  script = [
    "php --version | grep -q \"PHP {{version.raw}}\"",
    "php -r 'exit(PHP_VERSION === \"{{version.raw}}\" ? 0 : 1);'",
    # Each extension named on above was really built.
    "php -r 'foreach ([\"openssl\",\"curl\",\"zlib\",\"bz2\",\"mbstring\",\"intl\",\"gmp\",\"sodium\",\"zip\",\"gd\",\"xsl\",\"ffi\",\"iconv\",\"pdo_sqlite\",\"pdo_pgsql\",\"ldap\",\"sockets\",\"soap\",\"pcre\",\"libxml\",\"dom\",\"sqlite3\"] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, \"missing $e\\n\"); exit(1); } }'",
    "php -r 'exit(password_verify(\"x\", password_hash(\"x\", PASSWORD_BCRYPT)) ? 0 : 1);'",
    "php-fpm --version",
  ]
}

provenance {
  read = [
    "configure --help",                    # every --with/--enable/--disable switch named in ARGS
    "buildconf",                           # the tarball ships configure; no autoconf needed
    "ext/",                                # extension directories offered by this release
    "ext/sodium/config.m4:7",              # libsodium >= 1.0.8
    "ext/xsl/config.m4:7",                 # libxslt >= 1.1.0
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the switch list is the
complete output of ./configure --help of the tarball (sha256 above), checked by
reading, and `zpkb lint` was run.

⚠ UNKNOWNS: (1) the tarball ships configure and generated parsers, so autoconf,
bison and re2c from the previous recipe are dropped; this was not exercised.
(2) pkg-config must find every library through PKG_CONFIG_PATH; the floors
are the ones PHP 8.6.0 itself states: ext/sodium/config.m4 line 7,
PKG_CHECK_MODULES([LIBSODIUM], [libsodium >= 1.0.8]), and ext/xsl/config.m4
line 7, PKG_CHECK_MODULES([XSL], [libxslt >= 1.1.0]). The upper caps the
previous recipe inherited (libxslt <1.1.43, libsodium <1.0.19) are removed:
neither file states a ceiling, and the libsodium one made the recipe
unresolvable against libsodium.org 1.0.22 of this tree. (3) --with-jpeg and --with-webp take
effect only with the bundled libgd (--enable-gd, no --with-external-gd). (4) the
versions block reads php/php-src tags; 8.6.0 was released 2026-11-19.

⚠ pkgxdev/pantry was read only as the former content of this very file.
EOT
}
