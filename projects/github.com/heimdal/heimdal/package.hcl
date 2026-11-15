dependencies = {
  "gnu.org/readline" = "*"
  "invisible-island.net/ncurses" = "*"
  "sqlite.org" = "*"
  "thrysoee.dk/editline" = "*"
}
provides = [
  "bin/kinit",
  "bin/klist",
  "bin/kdestroy",
  "bin/kgetcred",
  "bin/kpasswd",
  "bin/kswitch",
  "bin/ktutil",
  "bin/string2key",
  "bin/hxtool",
  "bin/asn1_compile",
  "sbin/kdc",
  "sbin/kadmind",
  "sbin/kstash",
  "sbin/iprop-log",
]
test = <<EOT
kinit --version | grep -i heimdal
ls {{prefix}}/lib/libgssapi.*
EOT

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "github.com/westes/flex" = "*"
    "gnu.org/bison" = "*"
    "perl.org" = "*"
    "python.org" = "*"
  }
  script = [
    {
      run = <<EOT
mkdir -p "$SRCROOT/compat-lib"
for w in {{deps.invisible-island.net/ncurses.prefix}}/lib/libncursesw.*; do
  ln -sf "$w" "$SRCROOT/compat-lib/$(basename "$w" | sed 's/ncursesw/ncurses/')"
done
export LDFLAGS="-L$SRCROOT/compat-lib $${LDFLAGS:-}"
export LIBS="-ltinfo $${LIBS:-}"
EOT
    },
    {
      run = <<EOT
sed -i.bak           -e 's/^typedef struct hc_HMAC_CTX HMAC_CTX;$/typedef struct hc_HMAC_CTX hc_HMAC_CTX;\n#define HMAC_CTX hc_HMAC_CTX/'           lib/hcrypto/hmac.h
grep -q '^#define HMAC_CTX hc_HMAC_CTX$' lib/hcrypto/hmac.h
EOT
    },
    "./configure $ARGS",
    "make",
    "make install",
  ]

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--without-openssl",
      "--with-sqlite3={{deps.sqlite.org.prefix}}",
      "--with-readline={{deps.gnu.org/readline.prefix}}",
      "--with-libedit={{deps.thrysoee.dk/editline.prefix}}",
      "--without-berkeley-db",
      "--without-openldap",
      "--without-libintl",
      "--without-capng",
      "--disable-heimdal-documentation",
      "--disable-otp",
      "--disable-afs-support",
    ]
  }
}

distributable {
  strip-components = 1
  url = "https://github.com/heimdal/heimdal/releases/download/heimdal-{{version}}/heimdal-{{version}}.tar.gz"
}

versions {
  github = "heimdal/heimdal/releases/tags"
  strip = [
    "/^heimdal-/",
  ]
}

provenance {
  read = [
    "configure.ac",        # :453 tgetent in termcap/ncurses/curses; :179-187 sqlite3, :294-306 readline, :303 libedit, :120-128 openldap, :202-204 libintl, :163-169 capng, :616 otp, :250-280 afs
    "cf/crypto.m4",        # :67,:82,:144 AC_ARG_WITH — where --without-openssl is DECLARED, not configure.ac
    "cf/db.m4",            # :7,:12,:19 AC_ARG_WITH — likewise --without-berkeley-db, :12-21
    "lib/hcrypto/hmac.h",  # :42-43 the typedef the second patch rewrites
  ]

  note = <<EOT
Read at heimdal-7.8.0, the tag this recipe builds. The flags are the ordinary
part; the two PATCHES are what needed the project's own files, and both are now
explained by a line rather than by a guess.

⛔ THE ncurses SHIM IS JUSTIFIED BY ONE LINE, configure.ac:453:

    AC_FIND_FUNC_NO_LIBS(tgetent, termcap ncurses curses, [...])

heimdal looks for `tgetent` in `termcap`, `ncurses` and `curses` — never
`ncursesw`, and never `tinfo`. Our ncurses artifact ships the WIDE library
only, and a modern ncurses puts `tgetent` in **libtinfo**. So both halves of
the first script step come from that one line: the symlinks give the names
configure will try, and `-ltinfo` supplies the symbol those names no longer
carry. Neither half is optional and neither is a preference.

⭐ AND THE SECOND PATCH VERIFIES ITSELF, which is worth keeping. It rewrites
`lib/hcrypto/hmac.h` — `typedef struct hc_HMAC_CTX HMAC_CTX;` at :42-43 — and
then runs

    grep -q '^#define HMAC_CTX hc_HMAC_CTX$' lib/hcrypto/hmac.h

A `sed` whose pattern stops matching an upstream file does NOTHING and reports
success; the `grep` turns that silence into a build failure. That is the right
shape for every patch in this tree, and this is the only recipe here that does
it.

⛔ TWO OF THE TEN OPTIONS ARE NOT IN configure.ac, AND CITING IT WOULD HAVE
BEEN WRONG. Measured over its 678 lines: `openssl` and `berkeley-db` appear in
NEITHER. `AC_CONFIG_MACRO_DIR([cf])` at :8 says where to look, and `cf/`
carries `crypto.m4` (50 occurrences of openssl, `AC_ARG_WITH` at :67, :82,
:144) and `db.m4` (`berkeley-db` at :12-21, `AC_ARG_WITH` at :7, :12, :19).
That is the second time today a provenance would have named the obvious file
and pointed at the wrong one — the first was
`COMPILER_RT_DEFAULT_TARGET_ONLY`, which is in
`compiler-rt/cmake/base-config-ix.cmake` and in none of
`compiler-rt/CMakeLists.txt`'s 937 lines.

What is deliberately NOT claimed here: that `--without-openssl` and
`--without-berkeley-db` are REQUIRED rather than merely accepted. The two m4
files declare them; whether configure fails or degrades without them was not
measured in this pass, unlike crun's, where the AC_MSG_ERROR is quoted.
EOT
}
