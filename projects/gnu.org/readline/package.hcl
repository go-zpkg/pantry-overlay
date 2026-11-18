# gnu.org/readline — the GNU line-editing library, which 12 recipes in this tree
# name: the single largest consumer count of the twenty-two.
#
# ⛔ WRITTEN FROM READLINE'S OWN FILES (go-zpkg/packages#431), at 8.3 patch 6.
# Eighth of the twenty-two in go-zpkg/recipes#143, after openssl.org (#145),
# zstd (#146), bzip2 (#147), libexpat (#148), libxml2 (#149, corrected by #150),
# pcre.org/v2 (#151) and invisible-island.net/ncurses (#152).
#
# ⭐ IT COULD NOT BE WRITTEN BEFORE #152. readline's one dependency is ncurses,
# so until ncurses was a whole recipe this project would have RAISED the
# closure's skip count instead of lowering it. That is why it waited, and why
# it is worth twelve.

summary = "GNU readline: command-line editing and history for interactive programs"

# Read from `COPYING`: the GNU GPL version 3, 29 June 2007, which readline ships
# whole. ⚠ readline is GPL and not LGPL, deliberately and famously — linking it
# carries that obligation to the twelve consumers, which is a fact about this
# dependency rather than a defect in it.
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/readline/"
  match = "/readline-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^readline-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/readline/readline-{{version.raw}}.tar.gz"
  strip-components = 1

  # 3419642 bytes, recorded with `zpkb sourcepin -version 8.3`.
  sha256 = {
    "8.3" = "fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc"
  }

  # ⭐ SIGNED BY THE MAINTAINER, AND THE KEY COMES FROM HIS OWN PAGE.
  # https://tiswww.case.edu/php/chet/ links `gpgkey.asc` as "GPG Key"; that key
  # is 7C0135FB088AAF6C66C650B9BB5869F064EA74AB, Chet Ramey <chet@cwru.edu>, and
  # it is exactly what signed this tarball. `zpkb sourcepin` verified it and
  # reported "no keyserver was asked".
  #
  # ⚠ A RUNG BELOW ncurses (#152), AND THE DIFFERENCE IS SAID RATHER THAN
  # GLOSSED: there the fingerprint is PRINTED on the author's page and the page
  # itself is signed. Here the page links the key but does not print the
  # fingerprint, so the anchor is the page, not an independently published
  # value.
  #
  # ⭐ What raises it again is CONTINUITY, measured rather than assumed. The same
  # fingerprint signed:
  #   readline-8.0.tar.gz.sig   2019-01-04
  #   readline-8.2.tar.gz.sig   2022-09-26
  #   readline-8.3.tar.gz.sig   2025-07-02
  # — six and a half years of releases from one key, and the same key signs each
  # of the six patches below.
}

dependencies = {
  "invisible-island.net/ncurses" = "^6"
}

build {
  dependencies = {
    "gnu.org/make"  = "*"
    "gnu.org/patch" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ WITHOUT THIS, READLINE LINKS ITS OWN BUNDLED TERMCAP. configure:3029
      # sets `opt_curses=no`, and :7406-7409 then uses
      # `./lib/termcap/libtermcap.a` — a copy of termcap vendored inside the
      # readline tarball — whenever the probe lands on `gnutermcap` and nothing
      # asked for curses. That would make the ncurses dependency declared above
      # a lie: it would be installed and not linked.
      "--with-curses",

      # ⛔⛔ AND THIS IS THE FLAG THE PANTRY'S RECIPE REPLACES WITH A GUESS.
      # Upstream's recipe sets `LDFLAGS: $LDFLAGS -lncursesw` on linux under the
      # comment "otherwise it weirdly omits the linkage", citing a StackOverflow
      # answer. The cause is in readline's own configure, and it is not weird:
      #
      #   :7141-7378  `bash_cv_termcap_lib` is a PROBE over seven candidates —
      #               libc, libtermcap, libtinfo, libcurses, libncursesw,
      #               libncurses, gnutermcap — and whichever answers first wins.
      #   :7425-7427  if that answer is `libc`, TERMCAP_LIB is set to the EMPTY
      #               STRING. Nothing is linked, and nothing says so.
      #   :7983-7987  SHLIB_LIBS is then taken from support/shobj-conf, and
      #               `$SHARED_TERMCAP` is appended ONLY when SHLIB_LIBS mentions
      #               no curses/tinfo/termcap/termlib token already.
      #
      # So the omission is a branch, and `--with-shared-termcap-library` is the
      # escape hatch the project provides for it (:1405, :3040-3043, default
      # `no` at :3030). Naming it fills the gap where the probe found nothing
      # and is INERT where the probe found something, because of the guard at
      # :7984-7985 — which is why it is passed on both platforms rather than
      # linux only. Pushing `-lncursesw` into LDFLAGS instead reaches the link
      # line without reaching SHLIB_LIBS, and leaves the probe's answer
      # unexamined.
      "--with-shared-termcap-library=-lncursesw",
    ]
  }

  script = [
    # ⛔⛔ THE SIX OFFICIAL PATCHES, APPLIED IN ORDER, AND TWO OF THEM FIX
    # CRASHES. GNU publishes them at
    # ftp.gnu.org/gnu/readline/readline-8.3-patches/, each with its own
    # signature by the same key that signed the tarball, and the pantry's recipe
    # applies NONE of them — it carries `#TODO brew has a couple patches we
    # should apply` instead. Twelve recipes here link the result.
    #
    #   001  rl_save_prompt without rl_set_prompt leaves rl_prompt NULL and
    #        redisplay dereferences it
    #   002  ⛔ a SIGINT during a reverse i-search can SEGFAULT, by accessing
    #        data freed inside a signal handler — reachable by pressing Ctrl-C
    #        during Ctrl-R
    #   003  the input-wait function mishandles the application's event hook
    #   004  multibyte prompts misrender when the cursor is not at column 0
    #   005  SIGWINCH resize fails to recompute where the prompt wraps
    #   006  ⛔ a CRASH when the initial prompt has more than 256 wrapped lines
    #
    # ⭐ The patch level is not cosmetic: `rl_readline_version` encodes it, and
    # a consumer asking readline what it is gets the answer this build gives.
    #
    # ⚠ Each file is committed BESIDE this recipe with its digest recorded in
    # `provenance` below, rather than fetched during the build: a build that
    # reaches the network is a build whose result depends on when it ran. The
    # project states the level itself — every patch header reads
    # "Patch (apply with `patch -p0')".
    #
    # ⚠ `props/` IS THE BUILDER'S NAME FOR THIS RECIPE'S OWN DIRECTORY, not a
    # subdirectory of it — read from the one precedent in this tree,
    # projects/ruby-lang.org, whose script says `patch -p1 -F5 <
    # props/mkconfig.rb.diff` while the file sits beside its recipe. Written as
    # a `props/` subdirectory first, which would have failed at build time.
    {
      run = <<EOT
set -eu
for p in 001 002 003 004 005 006; do
  patch -p0 --batch --forward < "props/readline83-$${p}"
done
EOT
    },

    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`, AND THAT IS NOT AN OMISSION. readline installs no programs:
# its Makefile has no bin_PROGRAMS, only the libraries, the headers and the
# documentation. A `provides` naming anything here would be a promise about a
# file this build does not create.

test {
  dependencies = {
    "gnu.org/grep" = "*"
  }

  script = [
    "test -f \"{{prefix}}/include/readline/readline.h\"",

    # ⛔⛔ THE REGRESSION TEST FOR THE TERMCAP LINKAGE, and it asserts the thing
    # the pantry's LDFLAGS guess was reaching for. If the probe lands on `libc`
    # and nothing fills the gap, libreadline links no terminal library at all —
    # a build that succeeds and a library that fails at runtime on the first
    # terminal operation.
    {
      run = <<EOT
set -eu
ldd "{{prefix}}/lib/libreadline.so" > linkage.txt
grep -q -E 'ncurses|tinfo' linkage.txt || {
  echo "libreadline links no terminal library — the termcap probe found nothing and nothing filled the gap" >&2
  cat linkage.txt >&2
  exit 1
}
EOT
      if  = "linux"
    },
    {
      run = <<EOT
set -eu
otool -L "{{prefix}}/lib/libreadline.dylib" > linkage.txt
grep -q -E 'ncurses|tinfo' linkage.txt || {
  echo "libreadline links no terminal library" >&2
  cat linkage.txt >&2
  exit 1
}
EOT
      if  = "darwin"
    },

    # ⛔⛔ THE REGRESSION TEST FOR THE PATCH LEVEL. readline reports it in
    # `rl_readline_version`'s low byte and in the `RL_READLINE_VERSION` macro;
    # this reads the installed header, so dropping a patch from the script
    # turns this red rather than shipping a known segfault quietly.
    {
      run = <<EOT
set -eu
grep -q 'RL_VERSION_MAJOR[[:space:]]*8' "{{prefix}}/include/readline/readline.h"
grep -q 'RL_VERSION_MINOR[[:space:]]*3' "{{prefix}}/include/readline/readline.h"
grep -q 'readline-8.3-patchlevel[[:space:]]*6\|PATCHLEVEL[[:space:]]*6' "{{prefix}}/include/readline/readline.h" \
  || grep -q '^#define RL_READLINE_VERSION[[:space:]]*0x0803' "{{prefix}}/include/readline/readline.h"
EOT
    },

    # ⭐ AND IT HAS TO EDIT A LINE. readline's whole purpose is reading one, so
    # the test links against it and drives it with piped input rather than
    # asserting that a file exists.
    {
      run = <<EOT
set -eu
cat > probe.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <readline/readline.h>
int main(void) {
  char *line = readline("test> ");
  if (!line) return 1;
  printf("%s\n", line);
  free(line);
  return 0;
}
CEOF
cc probe.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lreadline -o probe
echo "Hello, World!" | ./probe > out.txt
grep -q 'Hello, World!' out.txt
EOT
    },
  ]
}

provenance {
  read = [
    "COPYING",                # the GNU GPL v3 readline ships whole
    "configure",              # the GENERATED script: :1405 and :3040-3043 --with-shared-termcap-library, default `no` at :3030; :3029 opt_curses defaults no; :7141-7378 the seven-candidate termcap probe; :7406-7409 the BUNDLED termcap fallback; :7425-7427 the libc branch that sets TERMCAP_LIB to the EMPTY STRING; :7983-7987 SHARED_TERMCAP appended only when SHLIB_LIBS names no terminal library
    "readline83-001",         # Patch-ID header; "Patch (apply with `patch -p0')"; rl_save_prompt leaves rl_prompt NULL
    "readline83-002",         # a SIGINT during reverse i-search segfaults on data freed in a signal handler
    "readline83-003",         # the input-wait function mishandles the application's event hook
    "readline83-004",         # multibyte prompts misrender away from column 0
    "readline83-005",         # SIGWINCH resize fails to recompute the prompt's wrap columns
    "readline83-006",         # a crash when the initial prompt exceeds 256 wrapped lines
  ]

  consulted = [
    "pkgxdev/pantry projects/gnu.org/readline/package.yml", # read deliberately: this recipe differs from it in applying the six official patches and in replacing an LDFLAGS workaround with the switch the project provides, and a difference cannot be stated without reading what it differs from
    "https://tiswww.case.edu/php/chet/",                    # the maintainer's page, which links the signing key
    "https://ftp.gnu.org/gnu/readline/readline-8.3-patches/", # the six official patches and their signatures
  ]

  note = <<EOT
⛔⛔ SIX OFFICIAL PATCHES EXIST FOR 8.3 AND THE PANTRY APPLIES NONE OF THEM.
GNU publishes readline83-001 through -006 at
ftp.gnu.org/gnu/readline/readline-8.3-patches/, each with its own detached
signature by the SAME key that signed the tarball
(7C0135FB088AAF6C66C650B9BB5869F064EA74AB), all six verified here with `zpkb
sourcepin` and no keyserver asked. Upstream's recipe carries `#TODO brew has a
couple patches we should apply` in their place.

Two of the six fix crashes. 002: "A SIGINT during a reverse i-search can cause a
segmentation fault due to accessing data freed by a signal handler" — a
use-after-free reachable by pressing Ctrl-C during Ctrl-R. 006: "a crash that
results if the initial prompt contains more than 256 wrapped" lines. TWELVE
recipes in this tree link readline, which is the largest consumer count of the
twenty-two.

The patches are COMMITTED beside this recipe rather than fetched during the
build: a build that reaches the network is a build whose result depends on when
it ran. Their digests are below, and the project states the application level
itself — every header reads "Patch (apply with `patch -p0')".

⚠ `props/` is the BUILDER'S name for a recipe's own directory, not a
subdirectory of it. Read from the one precedent in this tree, ruby-lang.org,
whose script says `patch -p1 -F5 < props/mkconfig.rb.diff` while the file sits
beside its recipe in the pantry. Written as a props/ subdirectory first, which
would have failed at build time and which no lint gate here would have caught.

  readline83-001 21f0a03106dbe697337cd25c70eb0edbaa2bdb6d595b45f83285cdd35bac84de
  readline83-002 e27364396ba9f6debf7cbaaf1a669e2b2854241ae07f7eca74ca8a8ba0c97472
  readline83-003 72dee13601ce38f6746eb15239999a7c56f8e1ff5eb1ec8153a1f213e4acdb29
  readline83-004 1f189c4566aa35950964647b9ec3be1a821e42b86048129c63eb7f9d4d2f5a74
  readline83-005 5481adbe161c9f6ba972c74db9e18c7aa351d3df3035cc4a673a1aa06247d1c6
  readline83-006 4ebd261a608287796e171af0ea9af5a1e3122e46672accda2484b6698c47c1a4

⛔⛔ "IT WEIRDLY OMITS THE LINKAGE" IS A BRANCH, NOT A MYSTERY. The pantry sets
`LDFLAGS: $LDFLAGS -lncursesw` on linux under that comment and a StackOverflow
link. readline's own configure says what happens: :7141-7378 probe seven
candidate libraries for the termcap functions; :7425-7427 set TERMCAP_LIB to the
EMPTY STRING when the answer is `libc`; and :7983-7987 append $SHARED_TERMCAP to
SHLIB_LIBS only when no terminal library is named there already. So the omission
is the libc branch, and `--with-shared-termcap-library` (:1405, :3040-3043,
default `no` at :3030) is the switch the project provides for it. It fills the
gap where the probe found nothing and is INERT where the probe found something,
which is why it is passed on both platforms rather than linux only. The LDFLAGS
form reaches the link line without reaching SHLIB_LIBS, and leaves the probe's
answer unexamined.

⛔ AND `--with-curses` IS NOT OPTIONAL EITHER. configure:3029 defaults
`opt_curses=no`, and :7406-7409 then link `./lib/termcap/libtermcap.a` — a
termcap vendored inside the readline tarball — whenever the probe lands on
`gnutermcap`. Without the flag, the ncurses dependency this recipe declares
would be installed and not linked.

⭐ IT COULD NOT BE WRITTEN BEFORE go-zpkg/recipes#152. readline's one dependency
is ncurses; until ncurses was a whole recipe here, writing readline would have
RAISED the closure's skip count. It waited for that reason and is worth twelve.

⚠ NO `provides`, AND THAT IS NOT AN OMISSION: readline installs no programs, only
libraries, headers and documentation.

⚠ THE SIGNATURE IS A RUNG BELOW ncurses', and the difference is stated rather
than glossed. There the author PRINTS the fingerprint on his page and signs the
page with the key. Here the page links `gpgkey.asc` without printing the
fingerprint, so the anchor is the page. What raises it again is continuity,
measured: the same fingerprint signed 8.0 (2019-01-04), 8.2 (2022-09-26) and 8.3
(2025-07-02), and each of the six patches.

⚠ NOT BUILT. Measured here: the digest and its signature, the six patch digests
and their signatures, the switch census against the generated configure, and
`zpkb lint`. The scripts are a claim about readline's build system read from
that build system, and they stay a claim until a factory runs them.
EOT
}
