# pcre.org/v2 — PCRE2, the Perl-compatible regular expression library, which 9
# recipes in this tree name.
#
# ⛔ WRITTEN FROM PCRE2'S OWN FILES (go-zpkg/packages#431), at 10.49. Sixth of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145), zstd (#146),
# bzip2 (#147), libexpat (#148) and libxml2 (#149, corrected by #150).
#
# ⚠ pkgxdev/pantry's recipe WAS opened this time, and `consulted` says so: two
# of the findings below are differences from it, and a difference cannot be
# stated without reading what it differs from.

summary = "PCRE2: Perl-compatible regular expressions, with pcre2grep and pcre2test"

# ⭐ THE PROJECT STATES ITS OWN SPDX EXPRESSION, exception included.
# LICENCE.md:4 is a table row reading
# `| SPDX-License-Identifier: | BSD-3-Clause WITH PCRE2-exception |`
# so this is quoted rather than inferred from the licence text — the first of
# the six where upstream did the classification itself, and the first carrying
# a WITH clause.
license = "BSD-3-Clause WITH PCRE2-exception"

# ⛔⛔ THE RELEASE NAMES CHANGED SPELLING MID-SERIES; THE TAGS DID NOT.
# Measured 2026-11-18 over the eight most recent releases:
#
#   name=PCRE2 10.49   tag=pcre2-10.49     ← space, 10.47 onwards
#   name=PCRE2-10.46   tag=pcre2-10.46     ← hyphen, 10.45 and 10.46
#
# So an enumeration over RELEASE NAMES needs two strips and silently drops half
# the series if it carries one — the shape facebook.com/zstd (#146) was written
# around, where a `" - "` written as an `ignore` removed release 1.5.6 entirely.
# The tags are uniform, so the tags are what this reads.
#
# ⛔ AND UPSTREAM'S ENUMERATION OFFERS RELEASE CANDIDATES. pkgxdev/pantry reads
# the same tags with the same strip and no `ignore`, so `pcre2-10.48-RC1` and
# `pcre2-10.45-RC1` enter the list as 10.48-RC1 and 10.45-RC1. A prerelease of
# a regular-expression library that 9 recipes link is not a thing to be offered
# by accident.
versions {
  github = "PCRE2Project/pcre2/tags"
  strip  = ["/^pcre2-/"]
  ignore = ["/-RC\\d+$/"]
}

distributable {
  url              = "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-{{version.raw}}/pcre2-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 2185271 bytes.
  sha256 = {
    "10.49" = "53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384"
  }

  # ⛔⛔ THE SIGNATURE IS PUBLISHED AND ITS KEY IS NOT REACHABLE — a FIFTH anchor
  # shape, and the first that is a gap rather than a rung.
  #
  # The release ships `pcre2-10.49.tar.bz2.sig`, and the project publishes a
  # fingerprint in its own repository, at the release tag:
  #
  #   SECURITY.md:15-17  "Releases from 10.45 onwards will be signed by
  #                      Nicholas Wilson (GPG key:
  #                      A95536204A3BB489715231282A98E77EB6F24CA8, cross-signed
  #                      by Philip Hazel's key for release continuity)"
  #
  # That is the best provenance any of the six has offered: the PRIMARY
  # fingerprint, published by the project, in the versioned tree. ⚠ But the
  # signature was not made by it, and this was measured rather than assumed
  # after a stale document cost this campaign a false headline the day before
  # (go-zpkg/recipes#150):
  #
  #   gpg --list-packets pcre2-10.49.tar.bz2.sig
  #     hashed subpkt 33 (issuer fpr v4 BACF71F10404D5761C09D392021DE40BFB63B406)
  #
  # BACF71F1… is neither the documented primary nor a subkey of the key material
  # the project's own account publishes: `users/NWilson/gpg_keys` serves exactly
  # one primary, A955362…B6F24CA8 — matching SECURITY.md to the character — with
  # ONE subkey, 4BB779713D7BE921. And GitHub itself cannot resolve the signer:
  # the release's signed tag, 388ef3c, reports
  # `"verified": false, "reason": "unknown_key"`.
  #
  # ⛔ So the key that signed this release is reachable only from a keyserver,
  # which this tree never asks. `zpkb sourcepin --sig` therefore cannot be run
  # here, and saying so is the point: a signature nobody can check is weaker
  # than libxml2's published checksum (#149), not stronger, because it LOOKS
  # like proof.
  #
  # ⭐ WHAT DOES BIND THESE BYTES IS THE PROJECT'S OWN ATTESTATION, which the
  # release body names. `gh attestation verify pcre2-10.49.tar.bz2 --repo
  # PCRE2Project/pcre2` exits 0 and resolves to
  #
  #   sourceRepositoryURI  https://github.com/PCRE2Project/pcre2
  #   buildSignerURI       …/.github/workflows/build.yml@refs/heads/release/pcre2-10.49
  #   sourceRepositoryDigest 6f9d7c1373262c541324a16a358785b33ef116cf
  #
  # ⚠ Measured with a control, because an exit 0 that printed nothing is not a
  # verdict: appending ONE byte to the tarball turns it into
  # `HTTP 404` and exit 1, so the check binds these bytes and not merely this
  # repository's name.
}

# ⚠ BOTH DEPENDENCIES EXIST IN THIS TREE AS WHOLE RECIPES, which is what makes
# this project a clean −1 rather than a trade: zlib.net and sourceware.org/bzip2
# (#147) both state a distributable and a build. They are here because
# pcre2grep is linked against them, and only because the two switches below ask
# for it.
dependencies = {
  "zlib.net"             = "^1"
  "sourceware.org/bzip2" = "^1"
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ JIT IS OFF BY DEFAULT, THIS TURNS IT ON, AND 10.49 EXISTS BECAUSE OF
      # A JIT DEFECT. The three facts belong together or none of them is safe:
      #
      #   configure:15950-15956  "# Handle --enable-jit (disabled by default)",
      #                          and `enable_jit=no` in the else branch.
      #   This recipe, and pkgxdev/pantry's, pass `--enable-jit`.
      #   The 10.49 release is SECURITY-ONLY, for GHSA-r9hj-j2rw-4q3m: an
      #   out-of-bounds write with attacker-controlled data, reachable through
      #   `pcre2_jit_stack_create()` + `pcre2_jit_stack_assign()` and a pattern
      #   with unusually high JIT stack usage, with arbitrary code execution
      #   among the implications. It affects 10.48 and EARLIER.
      #
      # So the flag that makes pcre2 fast is the flag that made that advisory
      # reachable, and 9 recipes in this tree link the result. JIT is kept —
      # it is why consumers want PCRE2 — and the version floor is what makes
      # keeping it defensible, which is why the digest above is pinned to 10.49
      # and not to whatever the enumeration offers.
      #
      # ⛔ AND `--enable-jit=auto` IS A HARDWARE PROBE, not a third opinion:
      # configure:15961-15987 compiles against `deps/sljit/.../sljitConfigCPU.h`
      # with SLJIT_CONFIG_AUTO and takes the answer from the machine that ran
      # configure, printing "checking for JIT support on this hardware...". A
      # recipe that passed `auto` would publish a different artifact per builder
      # — the defect class this campaign is about. The bare flag is `=yes` and
      # is deterministic.
      "--enable-jit",

      # The 16- and 32-bit libraries are `no` by default (configure:16387,
      # :16393, resolved from `unset`), and consumers in this tree expect all
      # three widths, as upstream's recipe does.
      "--enable-pcre2-16",
      "--enable-pcre2-32",

      # ⭐ THESE TWO ARE SAFE TO NAME BECAUSE PCRE2 REFUSES RATHER THAN
      # DOWNGRADING — the accepting side of the pattern libexpat (#148) and
      # zstd (#146) were written around. configure:18430-18440 and :18443-18453:
      #
      #   if test "$enable_pcre2grep_libz" = "yes"; then
      #     if test "$HAVE_ZLIB_H" != "1"; then
      #       echo "** Cannot --enable-pcre2grep-libz because zlib.h was not found"
      #       exit 1
      #
      # An `exit 1`, not a warning and not a quiet skip. So if the sandbox fails
      # to stage zlib or bzip2, this build FAILS instead of publishing a
      # pcre2grep that silently cannot read .gz or .bz2 — which is exactly what
      # zstd's three link probes did. Both default to `no` (configure:16153,
      # :16163), so naming them is what asks for the feature at all.
      "--enable-pcre2grep-libz",
      "--enable-pcre2grep-libbz2",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",

    # ⛔ `pcre2-config` BAKES THE BUILD PREFIX IN, and the store path it would
    # carry is a versioned directory that `zpkb bakedpaths` refuses — the same
    # shape as openssl's `HASHBANGPERL` (#145), one file down. pcre2-config.in:3
    # is literally `prefix=@prefix@`, substituted at configure time.
    #
    # ⚠ It is rewritten even though it is NOT in `provides` below: a file this
    # build installs is published whether or not it is promised, and a promise
    # is not what bakedpaths reads.
    {
      run              = <<EOT
sed -i.bak -e 's|^prefix=.*|prefix=$(cd "$(dirname "$0")/.." \&\& pwd)|' pcre2-config
rm -f pcre2-config.bak
EOT
      working-directory = "{{prefix}}/bin"
    },
  ]
}

# ⛔ `pcre2-config` IS INSTALLED AND IS NOT PROMISED — the SIXTH time this tree
# has made that call by hand, after tukaani.org/xz, openssl.org (#145),
# facebook.com/zstd (#146), sourceware.org/bzip2 (#147) and gnome.org/libxml2
# (#149). Makefile.am:390 is `bin_SCRIPTS = pcre2-config` and pcre2-config.in:1
# is `#!/bin/sh`; a script cannot run where there is no interpreter.
#
# ⚠ pkgxdev/pantry's recipe DOES promise it, which is the difference to read:
# `provides: [bin/pcre2-config, bin/pcre2grep, bin/pcre2test]`. Ours is the
# same build with one promise withdrawn. The convention is filed as a check in
# go-zpkg/zpkb#500 so a seventh recipe need not remember it.
#
# The two binaries are Makefile.am:615 `bin_PROGRAMS += pcre2grep` and :720
# `bin_PROGRAMS += pcre2test`, both inside `if WITH_PCRE2_8` (:614), which is on
# by default (configure:16381).
provides = [
  "bin/pcre2grep",
  "bin/pcre2test",
]

test {
  script = [
    "test -f \"{{prefix}}/include/pcre2.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libpcre2-8.* >/dev/null
test -f "{{prefix}}/lib/pkgconfig/libpcre2-8.pc"
EOT
    },

    # ⛔ THE THREE WIDTHS ARE ASSERTED SEPARATELY. --enable-pcre2-16 and
    # --enable-pcre2-32 are OFF by default, so dropping either flag leaves a
    # build that succeeds, installs, and is missing a library a consumer links.
    {
      run = <<EOT
ls "{{prefix}}"/lib/libpcre2-16.* >/dev/null || { echo "libpcre2-16 missing — --enable-pcre2-16 was dropped" >&2; exit 1; }
ls "{{prefix}}"/lib/libpcre2-32.* >/dev/null || { echo "libpcre2-32 missing — --enable-pcre2-32 was dropped" >&2; exit 1; }
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR `--enable-jit`, ASSERTED ON BEHAVIOUR RATHER
    # THAN ON A FLAG. pcre2test reports its build options, and `Just-in-time
    # compiler support` is the line that moves. Without this, dropping the flag
    # leaves a build that passes every other test here and is several times
    # slower for every one of the 9 consumers — a silent regression, which is
    # the only kind this tree keeps finding.
    {
      run = <<EOT
"{{prefix}}/bin/pcre2test" -C > cfg.txt 2>&1
grep -q "Just-in-time compiler support: yes" cfg.txt || {
  echo "JIT is not compiled in — --enable-jit was dropped or the hardware probe ran" >&2
  cat cfg.txt >&2
  exit 1
}
EOT
    },

    # ⛔ IT HAS TO MATCH AND IT HAS TO REFUSE. A pattern that matches everything
    # also "matches", so the negative case is asserted beside the positive one.
    {
      run = <<EOT
printf 'the quick brown fox\n' > subject.txt
"{{prefix}}/bin/pcre2grep" 'qu\\w+k' subject.txt > /dev/null
if "{{prefix}}/bin/pcre2grep" 'zzz\\d+' subject.txt > /dev/null 2>&1; then
  echo "pcre2grep matched a pattern that is not there" >&2
  exit 1
fi
EOT
    },

    # ⚠ AND UNICODE IS NOT OPTIONAL FOR THE CONSUMERS. configure:16405 resolves
    # `enable_unicode=yes` from `unset`, so it is on without being named — which
    # means nothing in ARGS protects it. A property escape is the cheapest
    # assertion that it survived.
    {
      run = <<EOT
printf 'héllo\n' > utf.txt
"{{prefix}}/bin/pcre2grep" -u '\\p{L}+' utf.txt > /dev/null || {
  echo "\\p{L} did not match — the build lost Unicode property support" >&2
  exit 1
}
EOT
    },
  ]
}

provenance {
  read = [
    "LICENCE.md",      # :4 the project's own SPDX expression, BSD-3-Clause WITH PCRE2-exception
    "SECURITY.md",     # :13-17 the two signing keys and which releases each covers; the primary fingerprint for 10.45 onwards
    "configure",       # the GENERATED script: :15950-15957 jit defaults no; :15961-15987 --enable-jit=auto is a HARDWARE probe; :16381-16405 the 8/16/32/unicode defaults resolved from `unset`; :16153,:16163 the two pcre2grep switches default no; :18430-18453 both of them exit 1 rather than downgrade
    "Makefile.am",     # :390 bin_SCRIPTS = pcre2-config; :615 pcre2grep and :720 pcre2test, both inside `if WITH_PCRE2_8` (:614)
    "pcre2-config.in", # :1 #!/bin/sh — why it is not in `provides`; :3 prefix=@prefix@ — why it is rewritten
  ]

  consulted = [
    "pkgxdev/pantry projects/pcre.org/v2/package.yml", # read deliberately: this recipe differs from it in `provides` and in `versions.ignore`, and a difference cannot be stated without reading what it differs from
    "github.com/PCRE2Project/pcre2 releases/tag/pcre2-10.49", # the release body, which names the advisory and the attestation
  ]

  note = <<EOT
⛔⛔ THE FLAG THAT MAKES PCRE2 FAST IS THE FLAG THAT MADE ITS LATEST ADVISORY
REACHABLE. configure:15950-15956 has `--enable-jit` disabled by default; this
recipe and the pantry's both turn it on; and 10.49 is a SECURITY-ONLY release
for GHSA-r9hj-j2rw-4q3m — an out-of-bounds write with attacker-controlled data
through `pcre2_jit_stack_create()`/`pcre2_jit_stack_assign()`, arbitrary code
execution among the implications, affecting 10.48 and earlier. Nine recipes in
this tree link the result. JIT stays, because it is why consumers want PCRE2;
the version floor is what makes keeping it defensible, and the test asserts the
BEHAVIOUR (pcre2test -C) rather than the flag.

⛔ AND `--enable-jit=auto` IS A HARDWARE PROBE. configure:15961-15987 compiles
against sljit's CPU header with SLJIT_CONFIG_AUTO and takes the answer from the
machine that ran configure. Passing `auto` would publish a different artifact
per builder; the bare flag is deterministic.

⭐ PCRE2 REFUSES RATHER THAN DOWNGRADING, which is the first time in these six
that a project got this right. configure:18430-18453 makes
`--enable-pcre2grep-libz` and `--enable-pcre2grep-libbz2` fail with `exit 1`
when the header or the library is missing, instead of quietly building a
pcre2grep that cannot read .gz — the exact failure facebook.com/zstd (#146) was
written around, where three link probes let the sandbox decide what the binary
contained. Naming a switch is only safe when the project enforces it, and here
it is.

⛔⛔ THE SIGNATURE'S KEY IS NOT REACHABLE, AND THAT IS WORSE THAN NO SIGNATURE.
SECURITY.md:15-17 publishes the PRIMARY fingerprint
A95536204A3BB489715231282A98E77EB6F24CA8 for releases from 10.45 — the best
provenance statement of the six. The signature on this tarball was made by
BACF71F10404D5761C09D392021DE40BFB63B406, which is not that key and not a
subkey of the key material the project's own account publishes (one primary
matching SECURITY.md, one subkey 4BB779713D7BE921). GitHub cannot resolve the
signer either: the signed release tag 388ef3c reports `unknown_key`. So the key
is reachable only from a keyserver, which this tree never asks, and
`zpkb sourcepin --sig` cannot be run. A signature that cannot be checked is
weaker than libxml2's published checksum (#149) because it LOOKS like proof.

⭐ What binds these bytes is the project's own attestation, named in the release
body: `gh attestation verify --repo PCRE2Project/pcre2` resolves to this
repository, its `.github/workflows/build.yml` on `refs/heads/release/pcre2-10.49`,
at commit 6f9d7c1. ⚠ Measured WITH A CONTROL, because its exit 0 prints nothing:
one byte appended to the tarball turns it into HTTP 404 and exit 1.

⚠ THE RELEASE NAMES CHANGED SPELLING AND THE TAGS DID NOT — `PCRE2 10.49` with a
space from 10.47, `PCRE2-10.46` with a hyphen before it — so the enumeration
reads tags. And upstream's, which reads the same tags with the same strip and no
`ignore`, offers `10.48-RC1` and `10.45-RC1` as versions.

⚠ NOT BUILT. Measured here: the digest, the attestation with its control, the
switch census against the GENERATED configure (the oracle go-zpkg/recipes#150
established, and the first recipe written with `acdefault`), the release-name
spelling change, and `zpkb lint`. The scripts are a claim about pcre2's build
system read from that build system, and they stay a claim until a factory runs
them.
EOT
}
