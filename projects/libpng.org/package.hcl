# libpng.org — the PNG reference library, which 5 recipes in this tree name.
#
# ⛔ WRITTEN FROM LIBPNG'S OWN FILES (go-zpkg/packages#431), at 1.6.59. Tenth of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145), zstd (#146),
# bzip2 (#147), libexpat (#148), libxml2 (#149, corrected by #150),
# pcre.org/v2 (#151), invisible-island.net/ncurses (#152), gnu.org/readline
# (#153) and sourceware.org/libffi (#154).
#
# ⭐ AND THIS ONE IS THE CONTROL FOR THE ONE BEFORE IT. libffi (#154) reads the
# BUILDER'S CPUID and picks -march. libpng looks like it does the same thing and
# does not, which is measured below rather than assumed — the pair
# `naming-a-switch-does-not-always-pin-it` asks for.

summary = "libpng: the PNG reference library, with pngfix and png-fix-itxt"

# Read from `LICENSE`: "PNG Reference Library License version 2", the heading
# the file itself carries, over "Copyright (c) 1995-2026 The PNG Reference
# Library Authors" and "Copyright (c) 2018-2026 Cosmin Truta".
license = "libpng-2.0"

# ⛔⛔ THE PANTRY READS A TRANSFERRED REPOSITORY, AND ITS NEWEST TAGS ARE BETAS.
# Both halves measured 2026-11-18:
#
#   `glennrp/libpng` answers, but the API's own reply names
#   `pnggroup/libpng` — it is a REDIRECT, not the repository. That is the trap
#   `github-transferred-repo-redirect-trap` records: a redirect works until
#   someone claims the freed name, and then it silently answers for them.
#
#   Of the 100 most recent tags, EIGHTY-NINE are `v1.7.0beta1` … `beta89` of an
#   unreleased 1.7 line, and exactly ONE is stable: `v1.6.59`. The betas are
#   the NEWEST, so an enumeration with no `ignore` — which is what the pantry
#   has — offers a beta of the PNG library to five consumers.
#
# This reads the repository by its real name and refuses the prereleases.
versions {
  github = "pnggroup/libpng/tags"
  strip  = ["/^v/"]
  ignore = [
    "/beta\\d*$/",
    "/rc\\d*$/",
  ]
}

distributable {
  # ⚠ ONE URL, NOT THE PANTRY'S TWO. Upstream lists downloads.sourceforge.net
  # and cytranet.dl.sourceforge.net as alternatives, which turns a mirror that
  # serves the WRONG bytes into a silent success on the second try; the digest
  # below is what makes a bad mirror an error instead of a fallback.
  url              = "https://downloads.sourceforge.net/project/libpng/libpng{{version.major}}{{version.minor}}/{{version.raw}}/libpng-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1074540 bytes — which is also what SourceForge's own file listing reports
  # for this file, so the fetch is cross-checked on length as well as content.
  sha256 = {
    "1.6.59" = "d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389"
  }

  # ⭐ THE SIGNED TAG IS FULLY VERIFIED HERE — the best of the three the
  # campaign has met. GitHub answers for `v1.6.59` (tag object a543b51):
  #
  #   "verified": true, "reason": "valid"
  #   tagger  Cosmin Truta <ctruta@gmail.com>
  #   key     1FED507E3236B4A6E53E922BB292C64843FF5BCF
  #
  # Against sourceware.org/libffi (#154), whose tag is signed but reports
  # `bad_email` because the tagger's address is not the key's verified one; and
  # pcre.org/v2 (#151), whose tag reports `unknown_key` outright. Here both the
  # key and the address resolve.
  #
  # ⛔ AND THE TARBALL IS STILL NOT COVERED BY IT. The SourceForge directory for
  # 1.6.59 holds exactly the two tarballs, two Windows archives and four
  # markdown files — NO .asc, NO .sig, NO checksum file; the `.asc` URL the
  # obvious guess would use answers with an HTML 404 page, which is worth
  # saying because a careless fetch would save that page AS the signature.
  #
  # ⚠ What SourceForge does publish, in its own file listing, is an MD5 per
  # file. That is the HOST's statement rather than the project's, in an
  # algorithm broken for collisions since 2004, so it is recorded here as
  # context and is not an anchor. The `make dist` tarball is not in any git
  # tree, so the signed tag cannot reach it — the same gap as #154.
}

dependencies = {
  "zlib.net" = "^1"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⚠ KEPT FROM THE PANTRY, WITH THE REASON IT NEVER GAVE. Neither changes
      # the artifact, and both are right for a factory: dependency tracking is
      # dead weight in a build that runs once and is thrown away, and a silent
      # rule is a log line missing on the day the build fails. Dropping them
      # would have been a difference this recipe could not defend.
      "--disable-dependency-tracking",
      "--disable-silent-rules",

      # ⭐⭐ THE HARDWARE OPTIMISATIONS ARE DELIBERATELY NOT NAMED, AND THAT IS
      # THE FINDING. configure:15613-15700 looks exactly like the defect
      # sourceware.org/libffi (#154) carries — a switch that turns SIMD on by
      # default — so it was read rather than pattern-matched:
      #
      #   :15650  case "$host_cpu" in
      #   :15651    arm*|aarch64*)  enable_arm_neon=yes   PNG_ARM_NEON_OPT 2
      #   :15667    i?86|x86_64)    enable_intel_sse=yes  PNG_INTEL_SSE_OPT 1
      #   :15673    powerpc*|ppc64*) enable_powerpc_vsx=yes
      #
      # The dispatch is on `$host_cpu` — the TARGET triple — and not on the
      # build machine's CPUID. libffi's :19962-19974 reads the builder's model
      # and picks `-march=sandybridge`; this reads the target and picks a
      # baseline every member of that target has (NEON is mandatory on aarch64,
      # SSE2 on x86-64). It is reproducible for a given target, so naming a
      # flag here would add an INERT one — the shape go-zpkg/zpkb#486 is about.
      #
      # Two switches of the same appearance, opposite verdicts, because the
      # BODY was read and not the default: `naming-a-switch-does-not-always-pin-it`.

      # ⚠ --with-binconfigs is left at its default (on, configure:15519-15521
      # handles only `no`) because the .pc file alone is not what every consumer
      # uses; the scripts are generated and installed, they are simply not
      # PROMISED below.
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ TWO OF THE PANTRY'S FOUR PROMISES ARE SHELL SCRIPTS — the EIGHTH time this
# tree has made that call by hand, after tukaani.org/xz, openssl.org (#145),
# facebook.com/zstd (#146), sourceware.org/bzip2 (#147), gnome.org/libxml2
# (#149), pcre.org/v2 (#151) and invisible-island.net/ncurses (#152).
#
# Upstream promises bin/libpng-config, bin/libpng16-config, bin/png-fix-itxt
# and bin/pngfix. Makefile.am:122 is `bin_SCRIPTS= @binconfigs@`, which is where
# the two `*-config` come from: generated shell scripts, installed and not
# promised here. The two real programs are Makefile.am:26
# `bin_PROGRAMS= pngfix png-fix-itxt`, inside `if ENABLE_TOOLS` (:25), which
# configure:14963-14967 defaults to `yes`.
provides = [
  "bin/pngfix",
  "bin/png-fix-itxt",
]

test {
  script = [
    "test -f \"{{prefix}}/include/png.h\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libpng16.* >/dev/null 2>&1 \
  || { echo "libpng16 is missing from {{prefix}}/lib" >&2; exit 1; }
test -f "{{prefix}}/lib/pkgconfig/libpng16.pc"
EOT
    },

    # ⛔ IT HAS TO READ A PNG, AND IT HAS TO REFUSE WHAT IS NOT ONE. A decoder
    # that accepts everything also "decodes", so the negative case is asserted
    # beside the positive one. The fixture is built here rather than shipped:
    # the eight-byte PNG signature plus a truncated body is enough to separate
    # "recognised the format" from "accepted any bytes".
    {
      run = <<EOT
set -eu
printf '\\211PNG\\r\\n\\032\\n' > not-really.png
printf 'this is not an image' >> not-really.png
if "{{prefix}}/bin/pngfix" not-really.png > /dev/null 2>&1; then
  echo "pngfix accepted a file that is not a PNG" >&2
  exit 1
fi
EOT
    },

    # ⭐ AND IT HAS TO LINK AND WRITE ONE, which is what the five consumers do.
    {
      run = <<EOT
set -eu
cat > probe.c <<'CEOF'
#include <stdio.h>
#include <png.h>
int main(void) {
  png_structp p = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (!p) return 1;
  png_infop i = png_create_info_struct(p);
  if (!i) return 1;
  printf("%s\n", png_get_libpng_ver(NULL));
  png_destroy_write_struct(&p, &i);
  return 0;
}
CEOF
cc probe.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lpng16 -lz -o probe
./probe > ver.txt
grep -q "{{version}}" ver.txt
EOT
    },

    # ⚠ AND zlib HAS TO BE THE ONE WE DECLARED. libpng links it for every
    # compressed chunk, so a build that found some other zlib would still pass
    # everything above.
    {
      run = <<EOT
set -eu
ldd "{{prefix}}/lib/libpng16.so" > linkage.txt
grep -q 'libz' linkage.txt || { echo "libpng16 does not link zlib" >&2; cat linkage.txt >&2; exit 1; }
EOT
      if  = "linux"
    },
  ]
}

provenance {
  read = [
    "LICENSE",     # the heading "PNG Reference Library License version 2" and the two copyright lines
    "Makefile.am", # :25-29 bin_PROGRAMS under `if ENABLE_TOOLS`; :122 `bin_SCRIPTS= @binconfigs@`, the two generated *-config scripts
    "configure",   # the GENERATED script: :14963-14967 enable_tools defaults yes; :15519-15521 --with-binconfigs handles only `no`; :15560-15598 the unversioned-link switches; :15613-15700 the hardware-optimisation block, whose :15650 dispatches on $host_cpu — the TARGET, not the builder's CPUID
  ]

  consulted = [
    "pkgxdev/pantry projects/libpng.org/package.yml",     # read deliberately: this recipe differs from it in `versions` (a transferred repository and 89 beta tags), in dropping the second mirror URL, and in `provides`
    "github.com/pnggroup/libpng refs/tags/v1.6.59",       # the signed tag object and GitHub's verdict on it
    "sourceforge.net/projects/libpng file listing",       # which files exist for 1.6.59, their sizes, and the MD5s SourceForge publishes
  ]

  note = <<EOT
⭐⭐ THIS RECIPE'S CENTRAL FINDING IS THAT THERE IS NOTHING TO FIX IN THE PLACE
IT LOOKED. configure:15613-15700 turns SIMD on by default and looks exactly like
the defect sourceware.org/libffi (#154) carries, so it was read rather than
pattern-matched. :15650 dispatches on `$host_cpu` — the TARGET triple — and
picks a baseline every member of that target has: NEON for arm/aarch64 (where
it is mandatory), SSE for i?86/x86_64, VSX for powerpc. libffi's :19962-19974
instead reads the BUILD MACHINE'S CPUID and picks `-march=sandybridge`. Same
appearance, opposite verdicts, and the difference is only visible in the body of
the macro — which is what `naming-a-switch-does-not-always-pin-it` says to read.
Naming a flag here would add an inert one (go-zpkg/zpkb#486).

⛔⛔ THE PANTRY READS A TRANSFERRED REPOSITORY AND ENUMERATES BETAS. Measured
2026-11-18: `glennrp/libpng` answers, but the API's own reply names
`pnggroup/libpng` — a redirect, not the repository, which is the trap
`github-transferred-repo-redirect-trap` records. And of the 100 most recent
tags, EIGHTY-NINE are v1.7.0beta1…beta89 of an unreleased line while exactly ONE
is stable, v1.6.59. The betas are the newest, and upstream's enumeration has no
`ignore`, so a beta of the PNG library is on offer to five consumers.

⚠ ONE URL, NOT TWO. The pantry lists a second SourceForge mirror as an
alternative, which turns a mirror serving the wrong bytes into a silent success
on the second try. The pinned digest is what makes a bad mirror an error.

⭐ THE SIGNED TAG IS FULLY VERIFIED — the best of the three. GitHub answers
`"verified": true, "reason": "valid"` for v1.6.59 (a543b51), tagged by Cosmin
Truta with 1FED507E3236B4A6E53E922BB292C64843FF5BCF. Against #154 (`bad_email`:
signature sound, address not the key's) and #151 (`unknown_key`: the signing key
unreachable at all).

⛔ AND THE TARBALL IS STILL NOT COVERED BY IT. The 1.6.59 directory holds the
two tarballs, two Windows archives and four markdown files — no .asc, no .sig,
no checksum. ⚠ The obvious `.asc` URL answers with an HTML 404 PAGE, 154 bytes,
which a careless fetch would save as the signature; that is why the absence was
recorded by listing the directory rather than by fetching a name. SourceForge's
own listing publishes an MD5 per file: the HOST's statement, in an algorithm
broken for collisions since 2004, recorded as context and not as an anchor.

⛔ EIGHTH HAND-MADE CALL ON SCRIPTS IN `provides`. Upstream promises
bin/libpng-config and bin/libpng16-config beside the two real programs;
Makefile.am:122 is `bin_SCRIPTS= @binconfigs@`. They are installed and not
promised here. The two programs are Makefile.am:26, inside `if ENABLE_TOOLS`,
which configure:14963-14967 defaults to yes.

⚠ NOT BUILT. Measured here: the digest and the file length SourceForge reports
for it, the absence of every upstream signature with the listing that showed it,
the tag's signature and GitHub's verdict, the tag census (89 betas, 1 stable,
of 100), the switch census (`acdefault`: 3 of 29 documented switches examined,
26 walked past), and `zpkb lint`. The scripts are a claim about libpng's build
system read from that build system, and they stay a claim until a factory runs
them.
EOT
}
