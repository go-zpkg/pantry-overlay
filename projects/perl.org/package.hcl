# ⛔⛔ THREE FINDINGS, ONE FIXED HERE, ONE CORRECTED HERE, ONE ONLY MEASURED —
# and the third is left alone on purpose because refuting it needs a linux
# build this session cannot run.

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
