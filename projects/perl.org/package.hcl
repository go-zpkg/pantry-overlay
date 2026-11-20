# perl.org — now a standalone recipe, written from perl's own files at 5.44.0
# (go-zpkg/packages#431). One of the four fragments `zpkb closure -build
# -require-standalone go-zpkg/base-toolchain` (zpkb v0.87.0) still named on
# 2026-11-20: "states no distributable, no build". The base toolchain needs it
# more than most: OpenSSL's build and the autotools both run perl.
#
# ⭐⭐ WHAT COMPLETING IT FOUND:
#
#   1. Perl compiles its own prefix into the binary as DATA — @INC and %Config
#      — which no rpath rewrite can reach (go-zpkg/zpkb#397's class). Perl has
#      a documented lever for it, -Duserelocatableinc, and it costs a shared
#      libperl. See `build`.
#   2. Configure's library search includes the BUILDER's /usr/local,
#      /opt/local and four more directories by default, so a builder with
#      Homebrew or MacPorts feeds libraries into the build. Both search lists
#      are now set explicitly on every platform.
#   3. Four DBM extensions build only if the builder happens to have the
#      library. Closed.
#
# ⭐ AND THE "ONLY MEASURED" FINDING BELOW RESOLVES ITSELF. Upstream's
# unexplained `llvm.org: <19` build dependency was upstream's; a standalone
# recipe declares only what perl's own build needs, and nothing in perl's
# INSTALL asks for llvm. It is kept below as history because the measurement
# behind it is still true of upstream.
#
# The findings that follow predate this completion and are kept.
#
# ⛔⛔ THREE FINDINGS, ONE FIXED HERE, ONE CORRECTED HERE, ONE ONLY MEASURED —
# and the third is left alone on purpose because refuting it needs a linux
# build this session cannot run.

summary = "Perl 5: a highly capable, feature-rich programming language"

# README:80-86: "either: a. the GNU General Public License … version 1, or (at
# your option) any later version, or b. the "Artistic License" which comes
# with this Kit." Both texts ship: `Copying` (GPL v1) and `Artistic`.
license = "Artistic-1.0-Perl OR GPL-1.0-or-later"

dependencies {
  linux = {
    # ⛔ RESTORED TO UPSTREAM'S `^4`, WHICH THIS FRAGMENT HAD LOOSENED TO `*`.
    #
    # The `*` arrived in 1edc1b2, "recipes: say only what each entry changes"
    # (#50) — a mechanical pass whose whole point was that a fragment states
    # only its differences. `*` where upstream says `^4` IS a difference, and
    # an unstated one: a dependency map merges per key, so this entry replaced
    # upstream's constraint with a looser one rather than repeating it.
    #
    # ⚠ Harmless today and wrong as a statement: libxcrypt has 16 resolvable
    # versions and ALL of them are 4.x, so `*` and `^4` pick the same artifact
    # right now. It becomes a real defect the day libxcrypt 5 ships — and this
    # is the one dependency perl's own build script verifies by hand at the end
    # (see the `ldd`/`objdump` block upstream), so a silent major bump here is
    # the last place to want one.
    "github.com/besser82/libxcrypt" = "^4"
  }
}

# ⛔⛔ THE ODD-MINOR FILTER LETS ONE DEV RELEASE THROUGH, because it assumes a
# three-component tag and perl has a four-component one.
#
# Upstream's block is
#
#   versions:
#     github: perl/perl5/tags
#     ignore: /^v\d+\.\d*[13579]\.\d+$/
#     # ^^ perl considers odd minor versions "dev" releases
#
# which is correctly written for `v5.17.7` and cannot match `v5.17.7.0`: after
# `\d+` consumes the `7` the `$` demands end-of-string and finds `.0`. Measured
# on upstream's recipe: 76 versions resolve and exactly ONE has an odd minor —
#
#   5.17.7.0   v5.17.7.0
#
# 5.17 is a development series, so the pattern means to exclude it, and the
# tarball is not there either: cpan.org/src/5.0/perl-5.17.7.0.tar.xz answers
# **404** (5.44.0 answers 200 from the same directory).
#
# ⭐ The fix is to drop the `$`, and dropping it is safe for a reason worth
# stating rather than assuming: the `[13579]` gate is what selects dev
# releases, and it cannot match an even minor however many components follow.
# `v5.42.1` fails it (`\d*`=4 leaves `2`, and 2 is not in the class), so an
# unanchored tail widens the pattern only over the odd minors it already
# targets. Verified by the A/B in the pull request.
#
# ⚠ `ignore` is carried in full — a scalar here, not a list — together with
# `github`, because an overlay key replaces rather than extends.
#
# ⛔ THIRD INSTANCE OF ONE FAMILY IN TWO DAYS. go-zpkg/recipes#123 found
# the same shape twice in python.org: `.x` as a glob idiom in a regex field,
# and `^0\.` anchored without the `v` the raw tag carries. All three are a
# pattern written for the tag shape the author had in mind, against a corpus
# that has another. The structural answer is the same one #123 reaches:
# `sha256` makes a recipe fail-closed, so an unbuildable version is refused
# rather than resolved.
versions {
  github = "perl/perl5/tags"
  ignore = "/^v\\d+\\.\\d*[13579]\\.\\d+/"
}

# ⚠⚠ MEASURED AND DELIBERATELY NOT CHANGED: upstream's linux build dependency
# is `llvm.org: <19`, with NO stated reason, and it is expensive.
#
# llvm.org resolves to 23.1.5 as its newest, with 41 versions at 19 or above
# and 47 below. So this bound makes the factory stage an llvm five majors old
# to build perl on linux, while everything else in the closure uses 23.x.
#
# ⭐ AND IT IS THE ONLY ONE OF ELEVEN SUCH BOUNDS WITHOUT AN EXPLANATION.
# Measured across the pantry — 11 recipes cap llvm, and the others say why:
#
#   systemd.io:50          llvm.org: <22 # 22 crashes
#   Mbed-TLS/mbedtls:48    llvm.org: <16 # otherwise we get an error from the arm_neon.h include
#   sip:11                 llvm.org: <17 # needs gcc to sip-install
#   wxwidgets.org:24       llvm.org: <17 # still gets unassigned label errors
#   …plus crystal-lang, meson, materialize, Vulkan-Headers, yazi, pyqt-builder
#   perl.org:17            llvm.org: <19      ← no comment
#
# ⛔ It is NOT removed here, and that is the honest position rather than a
# cautious one: refuting a build-dependency bound means building perl on linux
# with clang ≥ 19, which this session cannot do. An upper bound with no reason
# is a defect in the RECORD; removing it on the strength of "nobody wrote down
# why" would be replacing a measurement I do not have with a guess. Reported
# in the pull request so somebody with a linux builder can settle it in one
# run.

distributable {
  url              = "https://www.cpan.org/src/5.0/perl-{{version.raw}}.tar.xz"
  strip-components = 1

  # 14919940 bytes, recorded with `zpkb sourcepin` and equal, character for
  # character, to CPAN's own perl-5.44.0.tar.xz.sha256.txt beside it; then
  # confirmed by a second, independent fetch-and-hash. The provenance rung is
  # in provenance.note: there is a SIGSTORE bundle here and nothing in this
  # pantry can verify one yet.
  sha256 = {
    "5.44.0" = "505cf43912e9480495c344c70260452e32aa2a73c546a026b3f100053b23ce91"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # ⛔⛔ THE PREFIX IS COMPILED INTO THE BINARY AS DATA, and the relocatable
  # form is the only one that survives a different install location.
  #
  # Perl records @INC and every path in %Config at build time. Those are
  # strings inside the perl binary and Config_heavy.pl, not rpaths, so the
  # builder's rpath fixup cannot reach them — go-zpkg/zpkb#397's class ("a
  # store path is compiled into binaries as data … no rpath rewrite reaches
  # it"). INSTALL:1070-1083 is the documented lever:
  #
  #   sh Configure -Duserelocatableinc
  #   Then the paths in @INC (and everything else in %Config) can be
  #   optionally located via the path of the perl executable.
  #
  # ⛔ AND IT HAS A PRICE, stated at INSTALL:1085-1087: "This option is not
  # compatible with the building of a shared libperl ("-Duseshrplib"),
  # because in that case perl is linked with an hard-coded rpath". So libperl
  # is STATIC here. Both platforms' hints already default to that
  # (hints/darwin.sh:362-363 says so; hints/linux.sh does not set it), and
  # Configure:8730-8732 refuses the conflicting pair loudly, so a future
  # -Duseshrplib cannot slip in silently. ⚠ The cost: a program that EMBEDS
  # perl and expects libperl.so will not find one.
  #
  # ⛔ FOUR EXTENSIONS ARE BUILT ONLY IF THE BUILDER HAS THE LIBRARY.
  # INSTALL:1236-1238 says so in as many words — "Configure will offer to build
  # GDBM_File only if it is able to find the gdbm library" — and under -des an
  # offer is a yes. Configure:1523 probes `ndbm gdbm dbm db`. None is declared,
  # so all four are closed with the documented option (INSTALL:1240-1249).
  #
  # ⛔⛔ AND THE SEARCH LIST IS THE BUILDER'S UNLESS NAMED. Configure:1467-1468
  # and :1484-1485 default to
  #
  #   /usr/local/{include,lib} /opt/local/… /usr/gnu/… /opt/gnu/… /usr/GNU/… /opt/GNU/…
  #
  # — Homebrew's and MacPorts' prefixes among them. -Dlocincpth/-Dloclibpth
  # (INSTALL:1327-1337) REPLACE that list, so each platform names one: linux
  # the declared libxcrypt, darwin this build's own prefix, which holds nothing
  # at configure time. ⚠ An empty value was not used, because whether
  # Configure treats empty as "unset, use the default" was not checked.
  script = [
    {
      if = "linux"
      run = [
        "sh Configure -des -Dprefix=\"{{prefix}}\" -Duserelocatableinc -Dnoextensions='GDBM_File DB_File NDBM_File ODBM_File' -Dlocincpth=\"{{deps.github.com/besser82/libxcrypt.prefix}}/include\" -Dloclibpth=\"{{deps.github.com/besser82/libxcrypt.prefix}}/lib\"",
      ]
    },
    {
      if = "darwin"
      run = [
        "sh Configure -des -Dprefix=\"{{prefix}}\" -Duserelocatableinc -Dnoextensions='GDBM_File DB_File NDBM_File ODBM_File' -Dlocincpth=\"{{prefix}}/include\" -Dloclibpth=\"{{prefix}}/lib\"",
      ]
    },
    "make --jobs {{ hw.concurrency }}",
    "make install",

    # ⛔ THE INSTALLED SCRIPTS' FIRST LINE NAMES THIS BUILD'S PERL by absolute
    # path — utils/perldoc.PL:40 writes `$Config{startperl}` — so relocation
    # would leave perldoc, cpan, pod2man and the rest pointing at a prefix that
    # moved. `fix-shebangs.ts` is the builder's own rewrite to `#!/usr/bin/env
    # perl`, used the same way by ruby-lang.org.
    #
    # ⚠ AND IT DOES NOT REACH LINE TWO, stated rather than hidden: :41 writes
    #
    #   eval 'exec $Config{perlpath} -S $0 ${1+"$@"}'
    #       if $running_under_some_shell;
    #
    # which keeps the build prefix. It runs only when a SHELL executes the
    # script; under `#!/usr/bin/env perl` perl parses it as an `if` on a false
    # variable and does nothing. Inert in use — but `zpkb bakedpaths` will
    # count it in its census, and that count is expected rather than a
    # regression.
    "fix-shebangs.ts {{prefix}}/bin/*",
  ]
}

# Only the interpreter. The scripts beside it reach perl through
# `/usr/bin/env perl`, i.e. through PATH, so whether they run depends on the
# consumer's environment — the same reason go-zpkg/zpkb#500 keeps interpreter
# scripts out of `provides`.
provides = [
  "bin/perl",
]

test {
  script = [
    "\"{{prefix}}/bin/perl\" -e 'print \"ok\\n\"'",

    # The version the recipe claims is the version that runs.
    {
      run = <<EOT
set -eu
got=$("{{prefix}}/bin/perl" -e 'printf "%vd", $^V')
test "$got" = "{{version}}" || { echo "perl reports $got, recipe says {{version}}" >&2; exit 1; }
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR -Duserelocatableinc, read from the
    # binary's own Config. Without it, @INC is the build prefix as data and
    # nothing downstream can move it.
    {
      run = <<EOT
set -eu
v=$("{{prefix}}/bin/perl" -V:userelocatableinc)
test "$v" = "userelocatableinc='define';" || { echo "perl is not relocatable: $v" >&2; exit 1; }
EOT
    },

    # ⛔ THE FOUR CLOSED EXTENSIONS, asserted as ABSENCES: a builder with gdbm
    # or Berkeley DB would otherwise build them, and the artifact would vary.
    {
      run = <<EOT
set -eu
for m in GDBM_File DB_File NDBM_File ODBM_File; do
  if "{{prefix}}/bin/perl" -M"$m" -e1 2>/dev/null; then
    echo "perl has $m, which this recipe closed" >&2
    exit 1
  fi
done
EOT
    },

    # ⛔ AND THE SHEBANG REWRITE ACTUALLY RAN, on a script that has one.
    {
      run = <<EOT
set -eu
first=$(head -n 1 "{{prefix}}/bin/perldoc")
test "$first" = "#!/usr/bin/env perl" || { echo "perldoc's shebang is $first" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "INSTALL",          # :1070-1087 -Duserelocatableinc and its incompatibility with -Duseshrplib; :1236-1249 extensions offered by detection, and -Dnoextensions; :1327-1337 -Dlocincpth/-Dloclibpth
    "Configure",        # :1467-1468 and :1484-1485 the default search lists; :1523-1524 libswanted; :8730-8732 the refusal of relocatable + shared libperl
    "hints/darwin.sh",  # :362-363 useshrplib defaults to false
    "hints/linux.sh",   # does not set useshrplib
    "utils/perldoc.PL", # :40-41 startperl on line 1, perlpath in the eval-exec on line 2
    "README",           # :80-86 the licence choice
    "Copying",          # GPL version 1
    "Artistic",         # the Artistic License
    "https://www.cpan.org/src/5.0/", # the release listing, the .sha256.txt and the sigstore bundle beside each archive
  ]

  note = <<EOT
⚠ THE DIGEST RESTS ON A PUBLISHED CHECKSUM, AND A STRONGER WARRANT EXISTS THAT
THIS PANTRY CANNOT YET CHECK.

  archive    https://www.cpan.org/src/5.0/perl-5.44.0.tar.xz   14919940 bytes
  sha256     505cf43912e9480495c344c70260452e32aa2a73c546a026b3f100053b23ce91
  checksum   …/perl-5.44.0.tar.xz.sha256.txt — reproduced character for character
  sigstore   …/perl-5.44.0.tar.xz.sigstore.bundle — PRESENT, NOT VERIFIED

There is no OpenPGP .asc for this release. There IS a sigstore bundle: keyless
signing through an OIDC identity and a transparency log, which
`zpkb sourcepin --sig` cannot read — it verifies OpenPGP only. No signer
identity is recorded here, because one read out of an unverified bundle would
be a label rather than a measurement.

So the rung is the same as gnome.org/libxml2's and nghttp2.org's: the checksum
file establishes that we fetched what CPAN published, not that nobody else
could have published it. The checksum sits on the same host as the archive.

Filed as go-zpkg/zpkb#510: sourcepin verifying a sigstore bundle against a
NAMED identity and issuer would lift this recipe a rung — and python.org's,
whose 3.15.2 publishes a .sigstore and no .asc at all.

⛔ NOT BUILT. No session here can run the factory. What is established is the
inputs, each traced to a line in perl's own files, and a test written to fail
on each choice that could silently go the other way.
EOT
}
