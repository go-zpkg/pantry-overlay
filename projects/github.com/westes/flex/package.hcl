# flex — the fast lexical analyser generator, and libfl, its runtime support
# library.
#
# ⛔ WRITTEN FROM FLEX'S OWN FILES at 2.6.15, ninth of the base-toolchain
# members (go-zpkg/packages#440, after m4, make, sed, gawk, help2man, coreutils
# and binutils). It was THREE LINES — two dependency keys.
#
# ⛔⛔ AND IT IS THE FIRST ONE WHERE THE RECIPE WAS ELEVEN RELEASES BEHIND AND
# COULD NOT MOVE. Upstream's `distributable.url` spells v2.6.4 LITERALLY, with
# no `{{version}}` in it, while `versions: github: westes/flex` discovers up to
# 2.6.15. The two halves are different facts about the same recipe and they had
# drifted: a resolver asking for a newer flex gets 2.6.4's bytes under the newer
# number. Measured with `zpkb versions` against the upstream recipe: sixteen
# versions, newest 2.6.15, URL fixed at 2.6.4.
#
# ⭐⭐ AND THIS ONE WAS MEASURED, NOT ONLY READ. Three builds were run on this
# machine (darwin/arm64, macOS 27.2, Xcode clang) to settle a FIXME upstream had
# carried for years; what they found is in `build.env` below. The install
# manifest in `provides` is a real one, from a real `make install`, not an
# inference from a Makefile.

summary = "flex: the fast lexical analyser generator"

# ⛔ NOT GPL, unlike every other base-toolchain member written so far. COPYING's
# own first line is "Flex carries the copyright used for BSD software, slightly
# modified because it originated at the Lawrence Berkeley (not Livermore!)
# Laboratory, which operates under a contract with the Department of Energy",
# and the clause list is `COPYING:21` ("1. Redistributions of source code"),
# `:23` ("2. Redistributions in binary form") and `:27` ("Neither the name of
# the University nor the names of its contributors") — the three-clause form.
# There is NO advertising clause (grepped for, absent), so this is
# BSD-3-Clause and not BSD-4-Clause.
#
# The DOE-contract paragraph is an added notice, not a fourth condition.
# `doc/flex.texi` carries no GFDL grant — grepped, nothing — so the manual
# needs no second id. This states what was read, not a classification of every
# file in the tarball.
license = "BSD-3-Clause"

versions {
  github = "westes/flex"

  # ⚠ MEASURED A/B, because an `ignore` whose effect you cannot show is just
  # decoration. Without it and with it, the same SIXTEEN versions come back,
  # newest 2.6.15: the `v2.6.5-rc1` and `nightlies` tags that
  # `gh api repos/westes/flex/releases` lists are already dropped, the first as
  # a semver prerelease and the second because `nightlies` is not a version at
  # all. It is kept as a STATED intent for the next prerelease rather than as a
  # fix for a present problem, following lz4.org's `ignore` in this tree.
  ignore = ["/rc/"]
}

distributable {
  # The STORED RELEASE ASSET, not the generated tag archive — the distinction
  # lz4.org/package.hcl:24-40 measured over 1932 upstream recipes (1111 of them
  # build from a `archive/refs/tags/…` tarball GitHub generates on request,
  # whose bytes have changed before). flex uploads its own tarballs, so a
  # digest pins them for good.
  url              = "https://github.com/westes/flex/releases/download/v{{version.raw}}/flex-{{version.raw}}.tar.gz"
  strip-components = 1

  # ⭐⭐ THE BEST-SHAPED TRUST CHAIN IN THIS CAMPAIGN SO FAR, and better than
  # every GNU one before it. 1 842 277 bytes, fetched and hashed with the
  # builder's own fetcher.
  #
  #   signature    …/releases/download/v2.6.15/flex-2.6.15.tar.gz.sig
  #   algorithm    EdDSA (ed25519) — and our own `sourcepin` ACCEPTS it, unlike
  #                gnu.org/help2man's DSA/SHA-1, which it refuses
  #   signed       2026-11-15 13:28:19 CET (the release is the same day)
  #   identity     Flex Releases <releases@flexlexer.org>
  #   fingerprint  56D664C70CC2364CF5164914B7DFE8BB6C241FED (primary),
  #                signing subkey 15A2D3E3BEACC2E97D3BCA7294D9D33CD054C8B4
  #   verified     when the digest was recorded, not at every build
  #
  # WHAT MAKES IT BETTER THAN THE GNU ONES, point by point:
  #
  #   - the project SIGNS ITS CHECKSUM LIST. `SHA256SUMS` and `SHA256SUMS.sig`
  #     are release assets, and both verify. No GNU release here does that: for
  #     sed and binutils the digest's second witness was a mailing-list post,
  #     which is a weaker object than a signature.
  #   - THE FINGERPRINT HAS A SECOND HOST. https://flexlexer.org/downloads/
  #     publishes "56D6 64C7 0CC2 364C F516  4914 B7DF E8BB 6C24 1FED" —
  #     a different domain from the one serving the tarball. This is the leg
  #     gnu.org/coreutils and gnu.org/binutils could NOT claim, and the one
  #     gnu.org/sed's recipe explains the value of.
  #   - `README.md:13-15` carries the same fingerprint, but that copy is INSIDE
  #     the signed tarball and so proves nothing on its own. It is named here
  #     to say explicitly that it was NOT counted as a witness.
  #
  # The subkey is not published by flexlexer.org, only the primary that
  # certifies it; the chain from primary to subkey is in the key file.
  sha256 = {
    "2.6.15" = "ba38801d12d38782e36f2ddd66c118aa9ed3cbed9849194c4e68d9894cd739d9"
  }

  # ⛔ NO `sha` FIELD. `sha` means "where the expected SHA-256 is PUBLISHED", a
  # file the build fetches and compares — and flex actually HAS such a file,
  # `SHA256SUMS`, which would be the ideal `sha` target. It is not used because
  # `SHA256SUMS` lists two files (.tar.gz and .tar.lz) and the field expects a
  # digest for the one URL; feeding it a two-line file fails every build, the
  # same way a `.sig` there does (go-zpkg/packages#89). Recorded in
  # `provenance` instead (go-zpkg/zpkb#282).
}

# ⛔⛔ A RUNTIME DEPENDENCY, NOT A BUILD ONE, AND THAT IS THE WHOLE POINT OF
# THIS KEY. flex EXECS m4 every time it generates a scanner — it does not embed
# the macro processor. Established three ways and then proved with a negative
# witness:
#
#   configure.ac:137-142  AC_PATH_PROGS_FEATURE_CHECK([M4], [gm4 gnum4 m4], …)
#                         demands an m4 that answers `-P`, and ERRORS OUT if
#                         none is found. `-P` is GNU m4's prefixed-builtins
#                         mode, so this is gnu.org/m4 specifically and not
#                         "some m4".
#   configure.ac:143-144  AC_DEFINE_UNQUOTED([M4], ["$M4"]) — the ABSOLUTE PATH
#                         of that m4 is COMPILED INTO THE BINARY. Confirmed in
#                         a real build: `src/config.h:168` came out as
#                         `#define M4 "/usr/bin/gm4"` on this machine.
#   src/main.c:322-323    `if (!(m4 = getenv("M4"))) m4 = M4;` — the env var
#                         overrides, the baked path is the fallback.
#   src/filter.c:29       flex's own error text: "Flex requires GNU M4. Set the
#                         PATH or set the M4 environment variable to its path
#                         name."
#
# ⭐ The negative witness, run against a real install: `M4=/nonexistent/m4 flex
# -o out.c probe.l` exits 141 with "fatal internal error, exec of
# /nonexistent/m4 failed". So a flex shipped without m4 beside it is a flex that
# cannot generate a scanner. It is asserted in the test block.
#
# `^1` is upstream's constraint and it is right: GNU m4 1.4.x is the line that
# has `-P`, and nothing here states a tighter floor.
dependencies = {
  "gnu.org/m4" = "^1"
}

build {
  # ⛔⛔ gnu.org/gettext IS GONE, and this is the fourth recipe in the campaign
  # where `--disable-nls` removed a dependency the fragment had to declare.
  #
  # `configure.ac:51` is `AM_GNU_GETTEXT([external])` — flex bundles no libintl
  # — and the fragment pinned `gnu.org/gettext ^1` (upstream's own recipe says
  # `^0`, so the fragment existed partly to move that constraint). With NLS off
  # there is nothing to link on any platform, so the key is unnecessary rather
  # than merely loose.
  #
  # ⭐ NOT TAKEN ON FAITH: three `./configure` runs with `--disable-nls`
  # succeeded with no gettext on the search path, and `otool -L` on the
  # resulting `bin/flex` lists exactly one library:
  #
  #   /usr/lib/libSystem.B.dylib
  #
  # which is the artifact-level measurement the soname census makes. No
  # libintl, no libiconv.
  #
  # ⛔ `AM_GNU_GETTEXT_REQUIRE_VERSION([0.23])` (configure.ac:59) is an
  # AUTOPOINT-time requirement, not a configure-time one: it tells autoreconf
  # which po/ and m4/ infrastructure to import. We build from the released
  # tarball and never run autoreconf, so it is not a dependency of this recipe.

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # See the long note above: this is what deletes the gettext dependency.
      "--disable-nls",

      # ⛔⛔ KEPT, AND NOW IT HAS THE REASON IT NEVER HAD. Upstream's recipe
      # passes this flag with no comment, and flex's own `configure.ac:114-116`
      # says it is "intended only to workaround problems with bootstrap (e.g.
      # when cross-compiling flex or when bootstrapping has bugs)" — which
      # reads, at first, like a flag we should drop.
      #
      # Reading what bootstrap IS settles it the other way.
      # `src/Makefile.am:10-11` builds a `stage1flex` from the DISTRIBUTED
      # `src/scan.c` using CC_FOR_BUILD, `:140-143` has that stage1flex
      # regenerate the scanner from `scan.l`, and `:58-59` then builds the real
      # flex from the regenerated file instead of the distributed one. So
      # bootstrap needs no host flex at all — but it also changes nothing,
      # because `src/Makefile.am:137-139` states the design:
      #
      #   # The input and output file names are fixed for deterministic scanner
      #   # generation. If scan.l is not modified by builders, stage1scan.c
      #   # should be bit-identical to the scan.c pregenerated on release.
      #
      # and `:163-168` is the `dist-hook` that PRODUCED that pregenerated
      # scan.c, with the real flex, at release time. The distributed file is
      # already what a bootstrap would compute.
      #
      # ⭐ So the flag skips a redundant whole-source compile and leaves the
      # artifact unchanged — and it also removes a failure mode:
      # `configure.ac:90-91` ERRORS unless this flag is given when BUILD_OBJEXT
      # comes out empty, which depends on the ax_prog_cc_for_build.m4 serial
      # baked into the shipped `configure`. Keeping it is cheaper AND more
      # robust; the only thing given up is `stage2compare`
      # (src/Makefile.am:151-161), which is a maintainer target and is not
      # reached by `all` or by `install`.
      "--disable-bootstrap",

      # ⚠ KEPT AS INSURANCE, AND LABELLED AS SUCH rather than dressed up as a
      # measurement. `m4/ltoptions.m4:82` shows `pic-only` is NOT among the
      # options flex passes to `LT_INIT` (configure.ac:40 calls it bare), so
      # `--with-pic` has a real effect: PIC objects in the STATIC `libfl.a`.
      # That matters only for a consumer who links libfl.a into a shared
      # object, which nothing in this pantry does today. It is upstream's flag,
      # it costs nothing, and removing it could break such a consumer on
      # linux/x86-64 with no warning — so it stays, as a choice and not as a
      # necessity.
      "--with-pic",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]

    # ⛔⛔ THE FIXME UPSTREAM CARRIED FOR YEARS, NOW MEASURED — and it is real,
    # load-bearing, and NOT what its comment said. Upstream's recipe has
    #
    #   darwin:
    #     MACOSX_DEPLOYMENT_TARGET: 10.6 #FIXME our default (11) breaks the build
    #
    # "breaks the build" with no mechanism. Three builds on darwin/arm64
    # (macOS 27.2, Xcode clang), same tree, same flags, one variable changed:
    #
    #   | configuration                      | `make install` |
    #   |------------------------------------|----------------|
    #   | default (shared libfl), target 11  | FAILS          |
    #   | MACOSX_DEPLOYMENT_TARGET=10.6      | succeeds       |
    #   | --disable-shared, target 11        | succeeds       |
    #
    # The failure is exact and it is not mysterious:
    #
    #   Undefined symbols for architecture arm64:
    #     "_yylex", referenced from:
    #         _main in libmain.o
    #   ld: symbol(s) not found for architecture arm64
    #
    # `libfl` contains `src/libmain.c`, whose `main()` calls `yylex()` — a
    # symbol the USER's scanner supplies. That is fine in an ELF shared object
    # and an error in a Mach-O dylib. So what breaks is building libfl SHARED on
    # a modern deployment target, and the deployment target is the knob that
    # changes the clang driver's tolerance for it.
    #
    # ⭐ AND ONE HYPOTHESIS OF MY OWN WAS REFUTED BY THE MEASUREMENT, which is
    # why it is written down. I expected `10.6` on arm64 to stamp an impossible
    # minimum version into every object — arm64 macOS starts at 11.0 — and was
    # about to say every darwin flex this factory shipped was mislabelled.
    # `vtool -show-build` on the 10.6 build says otherwise:
    #
    #   platform MACOS
    #     minos 11.0
    #       sdk 27.2
    #
    # The toolchain CLAMPS the recorded minimum to the architecture's floor.
    # The flag steers the driver and does not taint the artifact, and that is
    # precisely what makes keeping it safe.
    #
    # ⚠ THE ALTERNATIVE IS NAMED BECAUSE IT IS GENUINELY BETTER-LOOKING AND WAS
    # STILL NOT TAKEN. `--disable-shared` fixes it at target 11 (measured
    # above), with no 2010-era value anywhere — but it also drops
    # `lib/libfl.dylib` and `lib/libfl.2.dylib` from the darwin artifact, which
    # is a visible change for anyone linking `-lfl` shared today, and it would
    # make the installed surface differ between platforms for no stated reason.
    # Keeping the surface and documenting the knob is the smaller change; the
    # defect here was a FIXME with no mechanism, and that is what is fixed.
    darwin = {
      MACOSX_DEPLOYMENT_TARGET = 10.6
    }

    # ⛔⛔ AND THE `linux: CPPFLAGS: -D_GNU_SOURCE` UPSTREAM CARRIES IS GONE,
    # with its comment ("Fix segmentation fault during install on Ubuntu")
    # neither accepted nor contradicted — only its IMPLIED MECHANISM refuted,
    # which is a different claim and the only one the files can settle.
    #
    # Two readings, both checkable:
    #
    #   1. flex already does this, properly. `configure.ac:37` is
    #      `AC_USE_SYSTEM_EXTENSIONS`, which defines `_GNU_SOURCE` in
    #      `config.h`, and `src/flexdef.h:38-44` includes `config.h` BEFORE
    #      `<stdio.h>` at `:46` — so the define lands ahead of every system
    #      header, which is the one thing that makes it work.
    #   2. The flag cannot reach the only compile that lacks it. The ONE
    #      translation unit set built without `_GNU_SOURCE` is stage1flex's,
    #      which uses `src/config_for_build.h` (flexdef.h's `#else` arm) — a
    #      header that defines PACKAGE, VERSION and M4 and `#undef`s
    #      HAVE_REALLOCARRAY, and defines no `_GNU_SOURCE`. And
    #      `src/Makefile.am:44` is
    #
    #        $(stage1flex_OBJECTS): CPPFLAGS=$(CPPFLAGS_FOR_BUILD)
    #
    #      an explicit OVERRIDE, so a `CPPFLAGS` set in the environment never
    #      reaches those objects at all.
    #
    # So the flag was applied to the target that already had the define and
    # could not reach the target that did not. Whatever the Ubuntu segfault
    # was, this was not its cure — and with `--disable-bootstrap` above,
    # stage1flex is not built in the first place. Also grepped: `src/` calls no
    # `asprintf`, `strcasestr` or `program_invocation_*`, so there is no
    # GNU-extension call left to be mis-declared.
    #
    # ⛔ `AC_USE_SYSTEM_EXTENSIONS` is read at 2.6.15. Whether 2.6.4 — the
    # version upstream's URL is frozen at, and the one that comment was
    # presumably written against — also had it was NOT checked, so this note
    # says nothing about why the flag was added back then.
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# ⛔ A REAL INSTALL MANIFEST, not a reading of Makefile.am. `make install` into
# a scratch prefix on darwin/arm64 produced exactly:
#
#   bin/flex                      the program
#   bin/flex++                    a SYMLINK to flex (Makefile.am:92-94,
#                                 `install-exec-hook`: $(LN_S) -f flex flex++)
#   include/FlexLexer.h           src/Makefile.am:98, include_HEADERS
#   lib/libfl.{a,dylib,2.dylib,la}, lib/pkgconfig/libfl.pc
#                                 src/Makefile.am:18-19
#   man/flex.1, info/flex.info{,-1,-2}, share/doc/flex/{AUTHORS,COPYING,NEWS,ONEWS,README.md}
#
# Only the two bin/ entries belong here; `provides` is the commands a consumer
# types. `flex++` is listed although it is a symlink because it is a name on
# PATH, and `src/Makefile.am:9` is `bin_PROGRAMS = flex` — one binary, two
# names, and reading only that line would have missed the second.
provides = [
  "bin/flex",
  "bin/flex++",
]

test {
  script = [
    "flex --version | grep {{version.raw}}",

    # ⛔ The symlink, asserted as a PROGRAM and not as a file: `flex++` is the
    # same binary (Makefile.am:94), so it must answer the same version. A build
    # whose install-exec-hook did not run leaves this name absent.
    "flex++ --version | grep {{version.raw}}",

    # The rest of the installed surface that a consumer compiles against.
    "test -f {{prefix}}/include/FlexLexer.h",
    "test -f {{prefix}}/lib/libfl.a",
    "test -f {{prefix}}/lib/pkgconfig/libfl.pc",

    # ⛔⛔ THE ONLY TEST THAT ACTUALLY EXERCISES flex: generate a scanner,
    # compile it, run it. Upstream's fixture does this too; this one adds
    # `%option noyywrap` and its own `main`, so it needs NO libfl and therefore
    # tests flex alone. A rule, a character class and `yytext` in four lines.
    #
    # ⭐ AND THE m4 NEGATIVE WITNESS IS ON THE SAME LINE, because it needs the
    # same input file. `M4=/nonexistent/m4` overrides the baked path
    # (src/main.c:322-323) and flex must FAIL — proving at test time that this
    # package execs m4 rather than embedding it.
    #
    # ⛔ `test ! -s`, NOT `test ! -f`: measured, flex CREATES the output file
    # and leaves it at ZERO BYTES when the m4 exec fails. An assertion about
    # the file's EXISTENCE passes on a flex that cannot work at all.
    #
    # Both halves were run against a real 2.6.15 install before being written
    # here: the scanner printed `hello-world-`, and the negative probe exited
    # 141 with "fatal internal error, exec of /nonexistent/m4 failed".
    {
      fixture = {
        content  = <<EOT
%option noyywrap
%%
[a-z]+      printf("%s-", yytext);
[ \t\n]+    ;
%%
int main(void) { return yylex(); }
EOT
        extname = "l"
      }
      run = "flex -o scanner.c $FIXTURE && gcc scanner.c -o scanner && ! M4=/nonexistent/m4 flex -o m4probe.c $FIXTURE && test ! -s m4probe.c"
    },
    "test \"$(printf 'hello world\\n' | ./scanner)\" = hello-world-",

    # ⛔ libfl HAS A DIFFERENT SUBJECT and so gets its own fixture: a scanner
    # with NO `main` and NO `%option noyywrap`, which links only because
    # `src/libmain.c` supplies `main()` and `src/libyywrap.c` supplies
    # `yywrap()`. This is the assertion that would have caught the darwin link
    # failure in the note above, and it was run against a real install too.
    {
      fixture = {
        content  = <<EOT
%%
[a-z]+      printf("%s-", yytext);
[ \t\n]+    ;
EOT
        extname = "l"
      }
      run = "flex -o libfl-scan.c $FIXTURE && gcc libfl-scan.c -o libfl-scan -L{{prefix}}/lib -lfl"
    },
    "test \"$(printf 'hello world\\n' | ./libfl-scan)\" = hello-world-",
  ]
}

provenance {
  read = [
    "configure.ac",                # :37 AC_USE_SYSTEM_EXTENSIONS; :40 bare LT_INIT; :51 AM_GNU_GETTEXT external; :59-60 REQUIRE_VERSION 0.23 is an autopoint-time need; :61-71 YACC falls back to build-aux/missing bison; :74-75 AC_PROG_LEX; :90-91 BUILD_OBJEXT empty ERRORS unless --disable-bootstrap; :108-112 libfl built by default; :114-120 --disable-bootstrap is "intended only to workaround problems"; :125-133 help2man and texi2dvi fall back to `missing` with a warning; :137-144 the m4 -P probe and AC_DEFINE_UNQUOTED([M4])
    "Makefile.am",                 # :50-56 SUBDIRS; :92-94 install-exec-hook makes bin/flex++ a symlink
    "src/Makefile.am",             # :9 bin_PROGRAMS = flex; :10-11 stage1flex under ENABLE_BOOTSTRAP; :18-19 libfl.la and libfl.pc; :41-45 the FOR_BUILD overrides, :44 CPPFLAGS among them; :58-59 flex built from stage1scan.c when bootstrapping; :98 include_HEADERS; :137-143 "should be bit-identical to the scan.c pregenerated on release"; :151-161 stage2compare; :163-168 the dist-hook that generated the shipped scan.c
    "src/flexdef.h",               # :38-44 config.h (or config_for_build.h) included BEFORE <stdio.h> at :46 — why AC_USE_SYSTEM_EXTENSIONS works
    "src/config_for_build.h.in",   # the bootstrap header: PACKAGE, VERSION, M4, #undef HAVE_REALLOCARRAY, rpl_malloc — and NO _GNU_SOURCE
    "src/main.c",                  # :322-323 getenv("M4") overrides the baked M4
    "src/filter.c",                # :29 "Flex requires GNU M4. Set the PATH or set the M4 environment variable to its path name."
    "src/libmain.c",               # the main() that calls yylex() — the undefined symbol a darwin dylib refuses
    "m4/ltoptions.m4",             # :80-82 shared/static/pic defaults: --enable-shared is libtool's own default, pic-only is not set
    "README.md",                   # :13-15 the signing fingerprint — INSIDE the signed tarball, so not counted as a witness
    "COPYING",                     # :21,:23,:27 the three BSD clauses; no advertising clause
    "doc/flex.texi",               # grepped: no GFDL grant
    "NEWS",                        # 2.6.15 (2026-11-15): YY_BREAK and yyinput() restored to their 2.6.4 behaviour; a buffer overrun in c99/go scanners
  ]

  consulted = [
    "https://flexlexer.org/downloads/",                       # publishes the primary key fingerprint — a SECOND host, which is the leg that matters
    "https://github.com/westes/flex/releases/download/v2.6.15/announcement.txt", # prints the SHA-256 of both tarballs; prints NO fingerprint
    "https://github.com/westes/flex/releases/download/v2.6.15/SHA256SUMS",       # and SHA256SUMS.sig, both verified
    "pkgxdev/pantry projects/github.com/westes/flex/package.yml",                # the recipe this replaces: url frozen at 2.6.4, four flags, two env workarounds
    "lz4.org/package.hcl",                                    # :24-40, stored asset vs generated archive, and the `ignore` precedent
    "gnu.org/sed/package.hcl",                                # why a fingerprint on a second host is what makes "verified" mean something
    "gnu.org/binutils/package.hcl",                           # the measured-claim discipline this recipe follows
  ]

  note = <<EOT
Ninth of the base-toolchain members written from the project's own files
(go-zpkg/packages#440). `zpkb closure -build` confirms flex is in the
70-project build closure of go-zpkg/base-toolchain before any of this was
written.

⭐⭐ WHAT WRITING IT FOUND. Five things, and three of them were only findable
by BUILDING:

  1. THE RECIPE WAS ELEVEN RELEASES BEHIND AND STRUCTURALLY UNABLE TO MOVE.
     `distributable.url` spells `v2.6.4` with no `{{version}}` in it, while
     `versions: github: westes/flex` discovers up to 2.6.15. Version and bytes
     are two facts in one recipe and they had drifted, so a resolver asking
     for a newer flex would get 2.6.4's bytes under the newer number.

  2. `--enable-shared` IS A NO-OP. `configure.ac:40` calls `LT_INIT` bare and
     `m4/ltoptions.m4:80` shows shared is libtool's default. Dropped.

  3. `linux: CPPFLAGS: -D_GNU_SOURCE` REACHES THE WRONG TARGET.
     `configure.ac:37` + `src/flexdef.h:38-46` already define `_GNU_SOURCE`
     for every real compile; the one compile that lacks it, stage1flex's, has
     its CPPFLAGS explicitly OVERRIDDEN at `src/Makefile.am:44`. The comment's
     observation ("segmentation fault during install on Ubuntu") is neither
     accepted nor denied here — only its implied mechanism is refuted, which
     is all the files can settle. Dropped.

  4. THE DARWIN FIXME IS REAL, AND ITS MECHANISM IS NOT WHAT IT SAID. Three
     builds, one variable: shared libfl at deployment target 11 FAILS with
     `Undefined symbols: "_yylex", referenced from: _main in libmain.o`, and
     both `MACOSX_DEPLOYMENT_TARGET=10.6` and `--disable-shared` fix it.
     `libfl` has an undefined-by-design `yylex`, which ELF allows and Mach-O
     does not. Kept, now with its mechanism and with the alternative named.

  5. gettext WAS NEVER NEEDED. `--disable-nls` and `otool -L bin/flex` lists
     one library, `/usr/lib/libSystem.B.dylib`. Fourth recipe in this campaign
     where that flag deleted a declared dependency rather than loosening it.

⛔ AND ONE OF MY OWN CLAIMS DIED IN THE MEASUREMENT, which is the part most
worth keeping. I expected `MACOSX_DEPLOYMENT_TARGET=10.6` on arm64 to stamp an
impossible minimum version into the artifact — arm64 macOS begins at 11.0 —
and was ready to report that every darwin flex this factory shipped was
mislabelled. `vtool -show-build` says `minos 11.0`: the toolchain clamps it.
The flag steers clang's driver and leaves the recorded version alone. A
plausible consequence of a true observation is still a guess until something
reads the artifact.

⭐ THE TRUST CHAIN IS THE BEST-SHAPED ONE IN THE CAMPAIGN, and for once every
leg is independent of the others:

  signature    …/releases/download/v2.6.15/flex-2.6.15.tar.gz.sig, EdDSA
               (ed25519) — accepted by our own sourcepin, unlike
               gnu.org/help2man's DSA/SHA-1
  key          flex-release-key.asc, published as a release asset
  identity     Flex Releases <releases@flexlexer.org>
  fingerprint  56D664C70CC2364CF5164914B7DFE8BB6C241FED, ALSO published by
               https://flexlexer.org/downloads/ — a different host from the
               one serving the tarball
  digest list  SHA256SUMS, itself SIGNED (SHA256SUMS.sig verifies), and its
               line for the .tar.gz equals what our fetcher computed
  checked      when the digest was recorded, not at every build

⛔ `README.md:13-15` carries the same fingerprint and is deliberately NOT
counted: it ships inside the tarball the signature protects, so using it would
be circular. Saying which witnesses were rejected is part of stating a chain.

No keyserver was asked. An unknown key is a refusal here, not a download.
EOT
}
