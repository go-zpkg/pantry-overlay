# invisible-island.net/ncurses — the terminal library, which 8 recipes in this
# tree name, and which `gnu.org/readline` (12 more) cannot be written without.
#
# ⛔ WRITTEN FROM NCURSES' OWN FILES (go-zpkg/packages#431), at 6.6. Seventh of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145), zstd (#146),
# bzip2 (#147), libexpat (#148), libxml2 (#149, corrected by #150) and
# pcre.org/v2 (#151).
#
# ⭐ IT IS DELIBERATELY NEXT. ncurses brings NO dependency of its own, so it is
# a clean −1; and writing it is what turns gnu.org/readline from a recipe that
# would RAISE the skip count into one that lowers it by twelve.

summary = "ncurses: the terminal-handling library, with tic, infocmp and tput"

# ⚠ X11 AND NOT MIT, AND THE DIFFERENCE IS ONE PARAGRAPH THAT WAS READ RATHER
# THAN ASSUMED. `COPYING:4-21` is the MIT text word for word, which is where a
# quick reading stops; `:24-27` then adds
#
#   "Except as contained in this notice, the name(s) of the above copyright
#    holders shall not be used in advertising or otherwise to promote the sale,
#    use or other dealings in this Software without prior written authorization."
#
# That advertising clause is exactly what SPDX separates X11 from MIT by. The
# holders are two (`:1-2`: Thomas E. Dickey 2018-2025, the FSF 1998-2018), which
# changes the notice and not the identifier.
license = "X11"

versions {
  url   = "https://ftp.gnu.org/gnu/ncurses/"
  match = "/ncurses-\\d+(\\.\\d+)+\\.tar\\.gz/"
  strip = [
    "/^ncurses-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/ncurses/ncurses-{{version.raw}}.tar.gz"
  strip-components = 1

  # 3791150 bytes, recorded with `zpkb sourcepin -version 6.6`.
  sha256 = {
    "6.6" = "355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11"
  }

  # ⭐⭐ THE STRONGEST ANCHOR OF THE SEVEN, and the only one where the author
  # publishes the fingerprint, the KEY BYTES and a signature chain, all on his
  # own domain:
  #
  #   https://invisible-island.net/public/public.html
  #     :48-50  pub rsa3072/2167BE03 2021-07-30
  #             19882D92DDA4C400C22C0D56CC2AF4472167BE03
  #             — the fingerprint is the LINK TEXT and the href is the key file
  #     :64-87  the older keys that signed this one, "to establish continuity"
  #     :100-104 the page itself is signed with the current key, and THAT
  #             signature is signed with the previous one
  #
  # And that fingerprint is exactly what signed this tarball
  # (`ncurses-6.6.tar.gz.sig`, issuer fpr 19882D92…2167BE03, 2025-12-30).
  # Verified with `zpkb sourcepin -sig auto -fingerprint 19882D92… -key <that
  # file>`: "no keyserver was asked".
  #
  # Ranked against the six before it: pcre.org/v2 (#151) publishes the primary
  # fingerprint but the signing key is unreachable; openssl.org (#145) the
  # fingerprint in prose; sourceware.org/bzip2 (#147) eighty bits of it in a
  # filename; zstd (#146) and libexpat (#148) a signature with no anchor;
  # gnome.org/libxml2 (#149) no signature and a published checksum. This is the
  # first that is complete.
}

# ⚠ THE SIGNATURE URL IS NOT A FIELD. `sig` is read by nothing
# (go-zpkg/zpkb#282) and `sha` means "where the expected SHA-256 is published",
# so a `.sig` placed there FAILS the build. It lives in `provenance` below.

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    PCDIR = "{{prefix}}/lib/pkgconfig"

    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ NCURSES BUILDS STATIC-ONLY BY DEFAULT, AND EIGHT RECIPES HERE LINK
      # IT. configure:6125-6130 is the `--with-shared` AC_ARG_WITH, and its else
      # branch is `with_shared=no`. Without this flag the install contains
      # libncursesw.a and NO shared object at all — a build that succeeds, a
      # package that installs, and every consumer linking it statically or
      # failing to find a .so. This is the single flag this recipe cannot lose.
      "--with-shared",

      # The C++ binding gets the same treatment; `--with-cxx-shared` is what
      # makes libncurses++w a shared object rather than an archive.
      "--with-cxx-shared",

      # ⛔ GPM IS AUTO-DETECTED AND THE DEFAULT IS `maybe`. configure:7788-7793
      # sets `with_gpm=maybe` when the flag is absent, and :7797 then probes for
      # `gpm.h` — so a sandbox that happens to stage GPM produces a libncurses
      # with libgpm in its DT_NEEDED, and one that does not produces a different
      # artifact from the same recipe. That is the defect class this campaign is
      # about (facebook.com/zstd, #146, where three link probes decided what the
      # binary contained). `=no` is the only value that is a decision rather
      # than a measurement of the builder.
      "--with-gpm=no",

      # ⛔ ADA IS ON BY DEFAULT AND BUILT ONLY IF A COMPILER IS FOUND — the same
      # shape one layer up. configure:1827 sets `cf_with_ada=yes`, and
      # :27580-27581 build the Ada95 bindings when `cf_cv_prog_gnat_correct` is
      # yes. So the INSTALLED TREE differs depending on whether the builder had
      # GNAT, silently. `--without-ada` is what makes the answer ours.
      "--without-ada",

      # ⭐ `enable_pc_files=no` IS THE DEFAULT (configure:4650-4652), so without
      # this flag ncurses installs no pkg-config files at all — and pkg-config
      # is how most of the eight consumers find it. `--with-pkg-config-libdir`
      # says where, because the default is the pkg-config installation's own
      # directory, which is another package's prefix.
      "--enable-pc-files",
      "--with-pkg-config-libdir=$PCDIR",

      # ⚠ A PIN, NOT A CHANGE, AND SAID SO. configure:1754 sets
      # `cf_dft_widec=no`, and :1757-1774 overrides it to `yes` for ABI 6 and
      # above, which 6.6 is (`cf_cv_abi_default=${NCURSES_MAJOR}` at :1300,
      # NCURSES_MAJOR=6 in dist.mk:39). So wide-character support is already on
      # here; naming it pins the value against an ABI default this recipe does
      # not control — the same reason gnome.org/libxml2 names `--without-python`
      # (#150).
      "--enable-widec",

      # SIGWINCH handling: ncurses resizes on terminal resize only when this is
      # asked for.
      "--enable-sigwinch",
    ]

    linux = {
      ARGS = [
        # Splits the terminfo functions into libtinfo, which is what linux
        # consumers link when they want terminfo without the full curses API.
        "--with-termlib",
        # Installs the terminfo database as symlinks rather than copies.
        "--enable-symlinks",
      ]
    }
  }

  script = [
    "mkdir -p $PCDIR",
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }} install",

    # ⛔ THE WIDE LIBRARIES ARE THE ONLY ONES BUILT, AND CONSUMERS LINK THE
    # UNDECORATED NAMES. With `--enable-widec` the libraries are libncursesw,
    # libformw, libmenuw, libpanelw and libncurses++w; a consumer that passes
    # `-lncurses` finds nothing. These aliases are what the eight expect.
    #
    # ⚠ Written as explicit names rather than the pantry's `tr -d w` over `find`
    # output: deleting every `w` from a path is a rule about the whole string,
    # and it is one directory named `sw` away from renaming the wrong file.
    {
      run               = <<EOT
set -eu
for stem in ncurses form menu panel ncurses++ tinfo; do
  for so in "lib$${stem}w".*; do
    [ -e "$so" ] || continue
    ln -sf "$so" "$(echo "$so" | sed "s|^lib$${stem}w|lib$${stem}|")"
  done
done
EOT
      working-directory = "{{prefix}}/lib"
    },

    # ⭐ TERMCAP IS AN ALIAS, NOT A CLAIM ABOUT A DIFFERENT LIBRARY. ncurses
    # implements the termcap API, so older software that links `-ltermcap` is
    # correctly served by libncurses.
    {
      run               = "ln -sf libncurses.so libtermcap.so"
      working-directory = "{{prefix}}/lib"
      if                = "linux"
    },

    # ⛔⛔ THE PANTRY'S `libtinfo.so.5` SYMLINK IS NOT CARRIED, AND THAT IS A
    # DELIBERATE DIFFERENCE. Upstream's recipe creates it with the comment "ghc
    # needs to find libtinfo.so.5, which is built from v6 on ubuntu 18.04". The
    # ABI here is SIX — dist.mk:39 `NCURSES_MAJOR = 6`, and
    # configure:1300 `cf_cv_abi_default=${NCURSES_MAJOR}` — so that link
    # publishes an soname the library does not have: anything resolving
    # `libtinfo.so.5` gets ABI 6 and the loader has no way to object.
    #
    # ⚠ Checked before dropping rather than after: `git grep -F libtinfo.so.5`
    # over this tree's 240 recipes matches NOTHING, with `libtinfo` itself
    # matching two files as the control. No consumer here asks for it, and the
    # distribution it was added for is from 2018.

    # ⭐ THE HEADERS ARE FLATTENED, because `--enable-widec` installs them under
    # `include/ncursesw/` and consumers include <curses.h> or <ncurses.h>. The
    # directory is kept as a symlink to `.` so a consumer that DOES say
    # `ncursesw/curses.h` still resolves.
    {
      run               = <<EOT
set -eu
if [ -d ncursesw ]; then
  mv ncursesw/* .
  rmdir ncursesw
  ln -sf . ncursesw
fi
EOT
      working-directory = "{{prefix}}/include"
    },

    # ⛔ THE INSTALLED PREFIX IS BAKED INTO BOTH THE .pc FILES AND THE CONFIG
    # SCRIPT, and `zpkb bakedpaths` refuses a versioned store path in a
    # published file — the same shape as openssl's HASHBANGPERL (#145) and
    # pcre2's pcre2-config (#151). `${pcfiledir}` is pkg-config's own relative
    # anchor; the script gets the same treatment it got there.
    {
      run               = <<EOT
set -eu
sed -i.bak 's|{{prefix}}|$${pcfiledir}/../..|g' *.pc
rm -f ./*.pc.bak
EOT
      working-directory = "{{prefix}}/lib/pkgconfig"
    },
    {
      run               = <<EOT
set -eu
sed -i.bak 's|^prefix=.*|prefix=$(cd "$(dirname "$0")/.." \&\& pwd)|' ncursesw6-config
rm -f ncursesw6-config.bak
EOT
      working-directory = "{{prefix}}/bin"
    },

    # Some older software asks for `ncurses.pc` and `tinfo.pc` by those names.
    {
      run               = "ln -sf ncursesw.pc ncurses.pc"
      working-directory = "{{prefix}}/lib/pkgconfig"
    },
    {
      run               = "ln -sf tinfow.pc tinfo.pc"
      working-directory = "{{prefix}}/lib/pkgconfig"
      if                = "linux"
    },
  ]
}

# ⚠ TERMINFO_DIRS PUTS THE SYSTEM FIRST, AND THAT IS THE ONE PLACE THIS TREE
# DEFERS TO THE HOST ON PURPOSE. Everywhere else a sovereign build reading the
# host's data would be a defect; terminfo describes THE USER'S TERMINAL, which
# is a property of the machine and not of this package, and a host entry for a
# terminal we have never heard of is the right answer. Our own database is the
# fallback, not the other way round.
runtime {
  env = {
    TERMINFO_DIRS = "/usr/share/terminfo:{{prefix}}/share/terminfo"
  }
}

# ⛔ `ncursesw6-config` IS INSTALLED AND IS NOT PROMISED — the SEVENTH time this
# tree has made that call by hand, after tukaani.org/xz, openssl.org (#145),
# facebook.com/zstd (#146), sourceware.org/bzip2 (#147), gnome.org/libxml2
# (#149) and pcre.org/v2 (#151). It is generated from misc/ncurses-config.in,
# whose first line is `#!@SHELL@` — substituted at configure time, so the
# interpreter is chosen by the BUILDER and the installed script carries it;
# either way a script cannot run where there is no interpreter.
# pkgxdev/pantry promises it; ours does not. Filed as a check in
# go-zpkg/zpkb#500 so an eighth recipe need not remember it.
provides = [
  "bin/captoinfo",
  "bin/clear",
  "bin/infocmp",
  "bin/infotocap",
  "bin/reset",
  "bin/tabs",
  "bin/tic",
  "bin/toe",
  "bin/tput",
  "bin/tset",
]

test {
  script = [
    # ⛔⛔ THE REGRESSION TEST FOR `--with-shared`, AND IT IS THE ONE THAT
    # MATTERS. The default is static-only (configure:6130), so losing the flag
    # leaves a build that compiles, installs and passes anything that only
    # looks at headers — while every one of the eight consumers loses its
    # shared library. Asserted on the installed tree.
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libncursesw.so* >/dev/null 2>&1 \
  || ls "{{prefix}}"/lib/libncursesw.dylib >/dev/null 2>&1 \
  || { echo "no shared ncurses — --with-shared was dropped" >&2; exit 1; }
EOT
    },

    # The undecorated aliases the eight consumers link.
    {
      run = <<EOT
set -eu
for stem in ncurses form menu panel; do
  ls "{{prefix}}"/lib/lib$${stem}.* >/dev/null 2>&1 \
    || { echo "lib$${stem} alias missing" >&2; exit 1; }
done
EOT
    },

    # ⭐ pkg-config has to answer, because that is how most consumers find this.
    # `--enable-pc-files` defaults to no, so this asserts the flag survived.
    {
      run = <<EOT
set -eu
test -f "{{prefix}}/lib/pkgconfig/ncursesw.pc"
test -f "{{prefix}}/lib/pkgconfig/ncurses.pc"
EOT
    },

    "test -f \"{{prefix}}/include/curses.h\"",

    # ⛔ AND IT HAS TO READ A TERMINAL DESCRIPTION. `tput -T` with a terminfo
    # name that exists must succeed and print something; one that cannot exist
    # must FAIL — a tput that answers for every name is not reading a database.
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/tput" -T xterm longname > /dev/null
if "{{prefix}}/bin/tput" -T no-such-terminal-xyzzy longname > /dev/null 2>&1; then
  echo "tput answered for a terminal that does not exist" >&2
  exit 1
fi
EOT
    },

    # ⚠ AND THE WIDE BUILD HAS TO BE THE WIDE BUILD. `ncursesw6-config --libs`
    # names the w-suffixed library; if the ABI default ever moves and
    # --enable-widec stops being honoured, this is what notices.
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/ncursesw6-config" --libs | grep -q 'ncursesw' \
  || { echo "ncursesw6-config does not name a wide library" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "COPYING",            # :4-21 the MIT text; :24-27 the advertising clause that makes it X11 and not MIT; :1-2 the two holders
    "misc/ncurses-config.in", # :1 `#!@SHELL@` — why ncursesw6-config is not in `provides`
    "dist.mk",   # :39-41 NCURSES_MAJOR 6, MINOR 6, PATCH 20251230 — the ABI major that decides the widec default and makes the pantry's libtinfo.so.5 link a false soname
    "configure", # the GENERATED script: :1300 cf_cv_abi_default=${NCURSES_MAJOR}; :1754 and :1757-1774 the widec default per ABI; :1827 Ada on by default; :4650-4652 pc-files OFF by default; :6125-6130 shared OFF by default; :6678-6680 termlib off; :7788-7793 gpm defaults to `maybe` and :7797 probes gpm.h; :27580-27581 Ada built only if GNAT is found
  ]

  consulted = [
    "pkgxdev/pantry projects/invisible-island.net/ncurses/package.yml", # read deliberately: this recipe differs from it in `provides`, in dropping the libtinfo.so.5 symlink and in not deleting the prefix's include directory, and a difference cannot be stated without reading what it differs from
    "https://invisible-island.net/public/public.html",                  # the author's own key page: the fingerprint, the key file and the signature chain
  ]

  note = <<EOT
⛔⛔ NCURSES BUILDS STATIC-ONLY BY DEFAULT, AND EIGHT RECIPES HERE LINK IT.
configure:6125-6130 is the `--with-shared` AC_ARG_WITH whose else branch is
`with_shared=no`. Without the flag the install carries libncursesw.a and no
shared object at all — a build that succeeds, a package that installs, and
eight consumers that lose their library. It is the one flag this recipe cannot
lose, and the first test asserts it on the installed tree.

⛔ TWO AUTO-DETECTIONS, BOTH PINNED. `with_gpm` defaults to `maybe`
(configure:7788-7793) and then probes for gpm.h (:7797), so a sandbox carrying
GPM produces a libncurses with libgpm in its DT_NEEDED and one without produces
a different artifact from the same recipe. Ada is on by default
(configure:1827) and built only when `cf_cv_prog_gnat_correct` is yes
(:27580-27581), so the installed tree depends on whether the builder had GNAT.
`--with-gpm=no` and `--without-ada` are what make both answers ours rather than
the builder's.

⚠ `--enable-widec` IS A PIN, NOT A CHANGE, and the note says so rather than
claiming a defect. configure:1754 sets `cf_dft_widec=no` and :1757-1774
overrides it to yes for ABI 6 and above, which 6.6 is. Naming it protects
against an ABI default this recipe does not control.

⛔⛔ THE PANTRY'S `libtinfo.so.5` SYMLINK IS NOT CARRIED. Its stated reason is
"ghc needs to find libtinfo.so.5, which is built from v6 on ubuntu 18.04". The
ABI here is SIX (dist.mk:39, configure:1300), so that link publishes an soname
the library does not have, and anything resolving it gets ABI 6 with no way for
the loader to object. ⚠ Checked before dropping rather than after: `git grep -F
libtinfo.so.5` over this tree's 240 recipes matches nothing, with `libtinfo`
matching two files as the control.

⚠ THE PANTRY'S `rm -rf {{prefix}}/include` IS ALSO NOT CARRIED. It is guarded by
a `#FIXME because our build infra is recursive`, which is a statement about that
factory and not about ncurses; a recipe that deletes part of its own prefix
before configuring is one mis-expansion away from deleting something else, and
this factory builds into a fresh prefix.

⭐ THE PROVENANCE IS THE BEST OF THE SEVEN AND THE FIRST THAT IS COMPLETE. The
author publishes, on his own domain, the fingerprint
(19882D92DDA4C400C22C0D56CC2AF4472167BE03), the key bytes it links to, and a
chain: older keys that signed this one "to establish continuity", the page
itself signed with the current key, and that signature signed with the previous
one. That fingerprint is exactly what signed this tarball. `zpkb sourcepin`
verified it and reported "no keyserver was asked".

⚠ `acdefault` (go-fleettools/fleettools#347) WAS RUN AND REFUSED THE TREE, which
is the correct answer and a finding in itself: ncurses' help lines carry no
default tokens at all — `--with-shared  generate shared-libraries`, with no
"(on)" or "[default=…]" anywhere — so there is nothing to compare the code
against. The tool exits 2 saying "documents no --with-*/--enable-* switch with a
stated default; nothing was examined" rather than reporting a clean zero. Every
default above was therefore read from the generated `configure` by hand, with
the line numbers in `read`.

⚠ NOT BUILT. Measured here: the digest and its signature against a fingerprint
published by the author, the switch census against the generated configure, the
absence of any libtinfo.so.5 consumer in this tree, and `zpkb lint`. The scripts
are a claim about ncurses' build system read from that build system, and they
stay a claim until a factory runs them.
EOT
}
