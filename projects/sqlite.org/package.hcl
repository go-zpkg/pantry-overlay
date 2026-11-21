# sqlite.org — SQLite, the embedded SQL database library, and its `sqlite3` shell.
#
# ⛔ WRITTEN FROM THE AUTOCONF BUNDLE'S OWN FILES at 3.54.1 (go-zpkg/packages#440,
# go-zpkg/packages#431). There was no recipe before this one.
#
# ⭐ WHY THIS RECIPE EXISTS AT ALL: go-zpkg/artifact#238 records sqlite.org as
# "cannot be expressed" — the artifact lives at
#   https://sqlite.org/2026/sqlite-autoconf-3540100.tar.gz
# for 3.54.1, and 3540100 is arithmetic with zero padding on a value known only
# after resolution, while the year is not derivable from the version at all.
# It CAN be expressed with the mechanisms zpkb has today, and nothing in
# artifact or zpkb was changed to do it:
#
#   number  {{version.major}}{{version.minor}}0{{version.patch}}00 — the encoding
#           is major*1000000 + minor*10000 + patch*100 (sqlite3.h:
#           SQLITE_VERSION_NUMBER), so for a two-digit minor and a one-digit
#           patch it is a plain concatenation with two literal zeros. Both
#           bounds are enforced by the `ignore` list below, so a version outside
#           them is not resolved rather than fetched from a wrong URL.
#   year    the list form of `distributable` is tried IN ORDER and a failed fetch
#           falls through to the next entry (build/runner.go, "trying next
#           mirror"); one entry per year, newest first, 404 → next. The pin is per
#           VERSION, so whichever year answers is checked against that version's
#           digest.
#
# ⚠ THE LIMITS, STATED: (1) a new calendar year needs one more entry, and until
# it is added the NEWEST release 404s — `zpkb lint --check-newest-pinned` does
# not fetch, so only the first build says so; (2) the first fetch of a version
# from an older year costs one 404 per newer year listed.

summary = "SQLite: self-contained, serverless SQL database engine (library and sqlite3 shell)"

# README.md / sqlite3.h: "The author disclaims copyright to this source code. In
# place of a legal notice, here is a blessing". SPDX has no id for a dedication
# of this shape; the project says "public domain".
license = "blessing"

# github.com/sqlite/sqlite is the project's own mirror and tags every release
# `version-X.Y.Z`. The ignore list keeps exactly
# the shape the URL encoding above can spell: three numeric fields, a
# two-digit minor, a one-digit patch. Historic four-field tags (3.8.11.1) and
# anything with a suffix are dropped.
versions {
  github = "sqlite/sqlite"
  strip  = "/^version-/"
  # Everything that is NOT exactly 3.<two digits>.<one digit>.
  ignore = ["/^(?!3\\.\\d\\d\\.\\d$)/"]
}

dependencies = {
  # zlib has NO option: autosetup/sqlite-config.tcl:682 probes zlib.h and
  # deflate and silently turns the shell's zipfile/sqlar compression on or off.
  "zlib.net" = "*"
  # --enable-readline below is FATAL when readline is not found (:1237), and
  # tgetent comes from ncurses (:1309).
  "gnu.org/readline"             = "^8.2"
  "invisible-island.net/ncurses" = "*"
}

# THE SAME DIGEST IS REPEATED IN EACH ENTRY because a pin belongs to an entry
# (build/runner.go oneSource), so a fetch that fell through to an older year is
# still verified.
#
# 3332984 bytes. Two witnesses, both read 2026-11-21:
#   1. `zpkb sourcepin` of the archive (sha256);
#   2. the project's download page https://sqlite.org/download.html, whose CSV
#      manifest names the same file with SHA3-256
#      b6ced585c750916b1052667239a12c25a7ff34e7f06e1e6e01ecb0427657d9c4,
#      recomputed locally from the archive (`openssl dgst -sha3-256`) and equal.
# ⚠ The page and the archive are one host: continuity, not independence. The
# project publishes no signature.
distributable = [
  {
    url              = "https://sqlite.org/2026/sqlite-autoconf-{{version.major}}{{version.minor}}0{{version.patch}}00.tar.gz"
    strip-components = 1
    sha256 = {
      "3.54.1" = "926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e"
    }
  },
  {
    url              = "https://sqlite.org/2025/sqlite-autoconf-{{version.major}}{{version.minor}}0{{version.patch}}00.tar.gz"
    strip-components = 1
    sha256 = {
      "3.54.1" = "926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e"
    }
  },
  {
    url              = "https://sqlite.org/2024/sqlite-autoconf-{{version.major}}{{version.minor}}0{{version.patch}}00.tar.gz"
    strip-components = 1
    sha256 = {
      "3.54.1" = "926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e"
    }
  },
]

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # EVERYTHING the bundle's --all would switch on, named: fts4 fts5 rtree
      # geopoly session dbpage dbstat carray (autosetup/sqlite-config.tcl:68).
      # fts3 comes with fts4. Memsys3/5, update-limit and column-metadata are
      # left at their off defaults.
      "--all",
      "--fts3",

      # ON by default, named so a changed default shows here.
      "--enable-threadsafe",
      "--enable-load-extension",
      "--enable-math",
      "--enable-json",
      "--enable-shared",
      "--enable-static",

      # ⛔ READLINE: on, by explicit request so a miss is fatal instead of a
      # silent shell without line editing (:1233-1241). Not editline, not
      # linenoise (:1165-1178 would adopt a `../linenoise` directory if one
      # sat beside the build; the sandbox has none). ICU is OFF: it is enabled
      # only by --with-icu-ldflags or --with-icu-config, neither given.
      "--enable-readline",
    ]

    # The probes for readline.h, -lreadline and tgetent take no directory from the
    # environment, only from flags: the declared prefixes go first.
    CPPFLAGS = "-I{{deps.gnu.org/readline.prefix}}/include -I{{deps.invisible-island.net/ncurses.prefix}}/include -I{{deps.zlib.net.prefix}}/include"
    LDFLAGS  = "-L{{deps.gnu.org/readline.prefix}}/lib -L{{deps.invisible-island.net/ncurses.prefix}}/lib -L{{deps.zlib.net.prefix}}/lib"

    linux = {
      LDFLAGS = "-L{{deps.gnu.org/readline.prefix}}/lib -L{{deps.invisible-island.net/ncurses.prefix}}/lib -L{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.gnu.org/readline.prefix}}/lib -Wl,-rpath,{{deps.invisible-island.net/ncurses.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/sqlite3",
]

test {
  script = [
    {
      run = <<EOT
set -eu
S="{{prefix}}/bin/sqlite3"
"$S" --version | grep -q '^{{version.raw}} '
# the extensions --all names, each exercised
"$S" :memory: "create virtual table t using fts5(a); insert into t values('hello world'); select count(*) from t where t match 'hello';" > fts5.txt
[ "$(cat fts5.txt)" = "1" ]
"$S" :memory: "create virtual table r using rtree(id,x0,x1); insert into r values(1,0,1); select id from r;" > rtree.txt
[ "$(cat rtree.txt)" = "1" ]
"$S" :memory: "select count(*) from sqlite_dbpage limit 1;" > /dev/null
"$S" :memory: "select count(*) from dbstat;" > /dev/null
# zlib: only registered in the shell when the zlib probe succeeded
"$S" :memory: "select length(sqlar_compress(zeroblob(1000))) < 100;" > zlib.txt
[ "$(cat zlib.txt)" = "1" ]
# readline, read off the binary: a build that linked it names libreadline
grep -q libreadline "{{prefix}}/bin/sqlite3"
EOT
    },
  ]
}

provenance {
  read = [
    "auto.def",                       # :7 sqlite-configure autoconf; :12-24 static-shell options
    "autosetup/sqlite-config.tcl",    # :68 --all list; :682 zlib probe, no option; :1154-1241 readline/editline/linenoise selection; :1309 tgetent
    "README.txt",                     # :46 `./configure; make`; :59-66 CFLAGS note
    "sqlite3.h",                      # SQLITE_VERSION / SQLITE_VERSION_NUMBER encoding; the blessing
    "configure",                      # --help read: the option list above
  ]

  consulted = [
    "https://sqlite.org/download.html",   # the CSV manifest: year directory, 7-digit name, size and SHA3-256 per file
    "go-zpkg/artifact#238",               # the blocker this recipe sidesteps without changing artifact or zpkb
  ]

  note = <<EOT
⚠ NOT BUILT. The build lines were read from the bundle's own files, not run;
the autosetup `./configure --help` output was read from the 3.54.1 archive.

⭐ THE ENCODING TRICK, because it is what #238 said could not be done. The
version number SQLite builds into its file names is major*10^6 + minor*10^4 +
patch*10^2; with a two-digit minor and a one-digit patch that is the four
moustaches and two literal zeros in the URL. The `versions` ignore list admits
only those shapes. The year directory is not derivable, so the list form of
`distributable` (one entry per year, tried in order, a 404 falling through) is
used — the runner's own fallback behaviour, not a new mechanism.

The limit that matters: a new year needs one more entry, and the newest release
404s until then.
EOT
}
