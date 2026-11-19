# help2man — generates a man page from a program's --help output.
#
# ⛔ WRITTEN FROM HELP2MAN'S OWN FILES at 1.49.3, continuing #88 after m4,
# make, sed and gawk (go-zpkg/packages#440, go-zpkg/packages#431). It was a
# three-line fragment declaring two dependencies, and reading the source
# changed BOTH of them.
#
# ⭐ IT IS ALSO THE MEMBER THE THREE RECIPES BEFORE IT HAD TO PROVE THEY DID
# NOT NEED: m4, make and sed each ship their man pages prebuilt, which is why
# none of them declares help2man and why a seed does not deadlock on it. This
# one is here because the base toolchain stages it for the packages that are
# NOT so considerate.

summary = "GNU help2man: generate a man page from --help output"

# COPYING is the GPLv3 text; help2man.PL:70 carries "either version 3, or (at
# your option)".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/help2man/"
  match = "/help2man-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^help2man-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/help2man/help2man-{{version.raw}}.tar.xz"
  strip-components = 1

  # 228 472 bytes, fetched and hashed with the builder's own fetcher.
  sha256 = {
    "1.49.3" = "4d7e4fdef2eca6afe07a2682151cea78781e0a4e8f9622142d9f70c083a2fd4f"
  }

  # ⛔⛔ A FIFTH SHAPE OF TRUST CHAIN, AND THE FIRST OUR OWN TOOL CANNOT CHECK.
  #
  #   signature  help2man-1.49.3.tar.xz.sig — 95 bytes, algo 17 (DSA),
  #              digest algo 2 (SHA-1), two 160-bit MPIs, signed 2022-12-15
  #   key        87EA44D150D89615E39A3FEEF0DC8E00B28C5995
  #   identity   Brendan O'Dea <bod@debian.org>
  #
  # `zpkb sourcepin --fingerprint 87EA…5995` REFUSES it:
  #
  #   sourcepin: … is not vouched for by the key you passed:
  #   openpgp: signature made by unknown entity — the bytes downloaded fine
  #   and hash to 4d7e4f…; what failed is WHO signed them
  #
  # and that message sent me looking for a missing key. It is not missing.
  # gpg, with the same keyring imported, verifies it:
  #
  #   gpg: Signature made Thu Dec 15 11:41:10 2022 CET
  #   gpg:                using DSA key 87EA44D150D89615E39A3FEEF0DC8E00B28C5995
  #   gpg: Good signature from "Brendan O'Dea <bod@debian.org>"
  #
  # Two implementations, one key, opposite answers. ⛔⛔ AND THE DISCRIMINATOR
  # WRITTEN HERE FIRST WAS WRONG: "the ALGORITHM: ProtonMail/go-crypto declines
  # DSA-with-SHA-1 and reports it as unknown entity". It does not. That came
  # from reading the packet dump above — algo 17 and digest algo 2 really are
  # there — and inferring the rest. Measured 2026-11-19 against this exact
  # keyring and this exact 95-byte signature (go-zpkg/zpkb#482, fixed in
  # go-zpkg/zpkb#508):
  #
  #   KeysById                              1
  #   KeysByIdUsage(KeyFlagSign)            0     <- the refusal, and all of it
  #   SelfSignature.FlagsValid              false, made 2001-06-19
  #   PublicKey.VerifySignature by hand     nil   <- GOOD, SHA-1 and all
  #   CheckDetachedSignature, flags patched nil   <- one variable, and it passes
  #
  # The key's self-signature is from 2001 and carries NO key-flags subpacket,
  # so nothing in the key states that it may sign data; openpgp/keys.go:343
  # skips it, the candidate list empties, and openpgp/read.go:493 answers
  # ErrUnknownIssuer. ⭐ A KEY OLDER THAN THE FLAG, NOT A WEAK ALGORITHM — the
  # data signature's hash is never judged, because the lookup fails before any
  # cryptography runs. go-zpkg/zpkb#508 makes the refusal itself say this,
  # instead of "what failed is WHO signed them"; released as v0.86.0.
  #
  # ⚠ AND THE VERDICT STILL STANDS, which is why this recipe has not moved.
  # Accepting a flagless key as sign-capable is what gpg does and would make
  # this verify, but RFC 9580 §5.2.3.29 does not say what an absent subpacket
  # implies and its nearest statement goes the other way — "If a list is
  # shorter than an implementation expects, the unstated flags are considered
  # to be zero." So the open question is not "how much is a SHA-1 signature
  # worth" but "does this pantry pin on a key whose self-signature predates key
  # flags?", and that is the owner's to answer.
  #
  # ⛔ SO WHAT THIS DIGEST RESTS ON, said plainly: our own fetch-and-hash, plus
  # a signature verified by a SECOND implementation against GNU's keyring —
  # weaker than gnu.org/sed's RSA/SHA-256 chain with an independently published
  # fingerprint, and weaker than gnu.org/gawk's RSA, because SHA-1 collisions
  # are practical and a 2022 DSA signature is not evidence against a prepared
  # file. It is stronger than gnu.org/make's, whose key is absent from that
  # keyring entirely (#113).
  #
  # ⭐ THAT STRENGTH JUDGEMENT IS A DIFFERENT CLAIM FROM THE REFUSAL ABOVE, AND
  # KEEPING THEM APART IS THE WHOLE LESSON OF go-zpkg/zpkb#482. The warrant IS
  # weak, for the reason stated: SHA-1. Our verifier refuses it for an
  # unrelated reason: the key flags. Both are true, neither implies the other,
  # and treating the refusal as evidence for the weakness is what produced the
  # wrong sentence this note used to carry.
  #
  # Nothing here waits on the upstream maintainer to re-sign; what changes the
  # recipe is a stronger signature, if one appears.
}

build {
  # ⛔⛔ BOTH DECLARED DEPENDENCIES CHANGED, and the fragment this replaces had
  # them as `gnu.org/gettext *` and `perl.org ~5.44`.
  #
  # 1. GETTEXT IS GONE. `configure.ac:49` errors "gettext required" only when
  #    NLS is requested, and `:22`/`:30` show the shape: it probes the perl
  #    module Locale::gettext and sets `nls_default=no` when it is absent. So
  #    with NLS off there is nothing to find and nothing to declare.
  #
  # 2. PERL IS `^5`, NOT `~5.44`. `configure.ac:19-20` is
  #    `LOCAL_PROG_PERL(5.008)` then `AC_MSG_ERROR([perl 5.8 required])` —
  #    the project asks for 5.8 and nothing narrower. `~5.44` is zpkb's
  #    `build.ToolchainPerl`, copied into a recipe, and seedpins' own note
  #    says why that is wrong: "a second copy of \"~5.3\" in this repository
  #    would be right until zpkb moved, and then wrong silently."
  #
  #    ⭐ THE COPY WAS NOT BASELESS, THOUGH, AND THAT IS WORTH KNOWING: zpkb
  #    requires base-toolchain members that ship compiled perl XS modules to
  #    match ToolchainPerl exactly. help2man ships none of its own — it IS a
  #    perl script — but with NLS ON it needs `Locale::gettext`, which is XS,
  #    and then a perl pin would be a real requirement. `--disable-nls` is
  #    what makes `^5` honest rather than lax.
  dependencies = {
    "perl.org" = "^5"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ EXPLICIT BECAUSE THE DEFAULT IS AUTO-DETECTION. `configure.ac:30` is
      # `test "x$ac_cv_module_Locale__gettext" = xno && nls_default=no`: with
      # no flag, whether this artifact has translations depends on whether the
      # perl that happened to be staged can load an XS module. Same class as
      # gawk's mpfr probe and sed's SELinux probe, and the fourth time this
      # fleet has met it.
      #
      # ⛔ AND IT COSTS SOMETHING REAL, unlike the other three. The tarball
      # ships 24 translated man pages and 10 translated .info files, and
      # `Makefile.in:60` installs them only through `@extra_make_install@` →
      # `install_l10n` (:81-101), which NLS enables. So this artifact carries
      # `man/man1/help2man.1` and `info/help2man.info` in English and nothing
      # else.
      #
      # Accepted, and the reason is what this member is FOR: it runs inside
      # builds to generate other packages' man pages, where its own
      # localisation is never read. Buying it back would mean an XS module in
      # the seed's perl and a gettext dependency on a tool the seed needs
      # early.
      "--disable-nls",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  # ⛔⛔ THE BUILD GENERATES ITS OWN MAN PAGE BY RUNNING ITSELF.
  # `Makefile.in:151-154`:
  #
  #   man: $(target).1
  #   $(target).1: $(srcdir)/$(target).PL $(srcdir)/$(target).h2m.PL
  #       $(MAKE) $(target) $(target).h2m
  #       ./$(target) --include=$(target).h2m --output=$@ ./$(target)
  #
  # So no external help2man is needed to build help2man — the just-built
  # script documents itself. That is the opposite of the grep trap (a package
  # that needed its own artifact to build) and needs no declaration at all.
  #
  # ⭐⭐ AND `all: $(target) man info` WOULD NEED makeinfo, WHICH THIS RECIPE
  # DOES NOT DECLARE — because of a measurement, not an assumption.
  # `Makefile.in:184-186` rebuilds help2man.info from help2man.texi with
  # `$(MAKEINFO)`, and `configure.ac:63` is `LOCAL_PROG_OR_MISSING(makeinfo)`,
  # so an absent makeinfo becomes `build-aux/missing makeinfo`. That script
  # does NOT touch the target and let make continue: it runs the program,
  # prints advice, and `exit $st` (build-aux/missing:84-102, :207) — 127 when
  # the program is missing, which FAILS the build.
  #
  # What saves it is the tarball's own timestamps:
  #
  #   help2man.texi  2021-08-22 13:06:45
  #   help2man.info  2022-12-13 01:48:03   ← 16 months NEWER
  #
  # so make considers the shipped .info up to date and never calls makeinfo.
  #
  # ⛔ That holds only if extraction PRESERVES those times, and it does, on
  # purpose: `fetch/fetch.go:332` restores each entry's mtime, and
  # `TestExtractRestoresModTimes` exists because of this exact trap — "a
  # release tarball ships a GENERATED file (a man page) recorded as NEWER than
  # the source it derives from, so make leaves it alone. … stamping every file
  # with 'now' re-orders them by archive position and make tries to
  # regenerate, which killed libexpat 2.8.3 (no docbook2x-man)."
  #
  # So gnu.org/texinfo is not a dependency of this recipe, and the reason is a
  # guard in the builder rather than a property of the project. Stated here
  # because the next reader deserves to know which of the two is holding.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# `Makefile.in:62-69`, `install_base` — the script, its man page and its info
# manual. One executable; `install_preload` (:77-79) and `install_l10n`
# (:81-101) are reached only through `@extra_make_install@`, which NLS sets.
provides = [
  "bin/help2man",
]

test {
  script = [
    "help2man --version | grep {{version.raw}}",

    # ⛔ THE ONE ASSERTION THAT MATTERS: help2man doing its job on a program
    # whose --help is known. `echo --help` is not it; `help2man` itself is,
    # and it is the same self-application the build uses.
    "help2man --no-discard-stderr --output=/tmp/h2m-selftest.1 help2man",
    "grep -q 'HELP2MAN' /tmp/h2m-selftest.1",
    "grep -q '.TH' /tmp/h2m-selftest.1",

    # ⛔ A perl script with no perl is a file. This asserts the shebang
    # resolves — which is what `perl.org ^5` is there for, and what the fixup
    # pass rewrites when the artifact moves.
    "head -1 \"$(command -v help2man)\" | grep -q perl",
  ]
}

provenance {
  read = [
    "configure.ac",       # :12 AC_INIT takes the version by RUNNING ./help2man.PL --version; :19-20 LOCAL_PROG_PERL(5.008) and "perl 5.8 required"; :22 LOCAL_PERL_MODULE(Locale::gettext); :30 nls_default=no when that module is absent; :46-49 the NLS-only errors, including "gettext required"; :63-68 LOCAL_PROG_OR_MISSING for makeinfo, install-info, msgmerge, xgettext, po4a-*
    "Makefile.in",        # :58 all = target man info; :60 install = install_base @extra_make_install@; :62-69 what install_base installs; :77-79 install_preload; :81-101 install_l10n, the translated pages and .mo files; :141-142 the script is generated by perl; :151-154 the man page is generated BY RUNNING THE JUST-BUILT help2man; :184-186 the info rule calls $(MAKEINFO)
    "build-aux/missing",  # :81-102 and :207 — it runs the program and exits with its status (127 when absent); it does NOT touch the target, so an absent makeinfo FAILS rather than degrades
    "aclocal.m4",         # :64-65 LOCAL_PROG_OR_MISSING's definition
    "COPYING",            # the GPLv3 text, and help2man.PL:70 "either version 3, or (at your option)"
  ]

  consulted = [
    "go-zpkg/zpkb fetch/fetch.go",      # :332 extraction restores each entry's mtime
    "go-zpkg/zpkb fetch/fetch_test.go", # :742-746 TestExtractRestoresModTimes, and the libexpat 2.8.3 failure that caused it
    "go-zpkg/zpkb build/build.go",      # :232 ToolchainPerl = "~5.44", which the fragment had copied
    "go-zpkg/packages seedpins/main.go", # :21-22 why a copy of a toolchain constraint is wrong
    "gnu.org/gawk/package.hcl",         # the same auto-detection class, and the trust-chain comparison
  ]

  note = <<EOT
Fifth of the base-toolchain members written from the project's own files (#88).
Nothing was converted. Both declared dependencies changed: gettext went away
and perl went from a copied `~5.44` to the `^5` the project actually asks for.

⭐⭐ THE MEASUREMENT I EXPECTED TO GO THE OTHER WAY. I assumed `missing` would
touch the target and let the build continue without makeinfo — that is the
behaviour sed's `doc/dummy-man` has, and I had just read it. This `missing`
does not: it exits with the program's status, 127. So the build WOULD fail
without makeinfo, and what actually saves it is the tarball shipping
help2man.info sixteen months newer than help2man.texi, plus our fetcher
restoring mtimes on purpose. Reading the script beat assuming the convention.

⛔ AND THE HAZARD HAS A NAME AND A CORPSE: zpkb's own
`TestExtractRestoresModTimes` was written because libexpat 2.8.3 died of
exactly this — a generated man page re-ordered by extraction, make trying to
regenerate it, and no docbook2x-man to do so. help2man is the same shape with
makeinfo in place of docbook2x-man. If that fetcher guard were ever relaxed,
this recipe would need gnu.org/texinfo, which is itself a base-toolchain
member with no standalone recipe — i.e. the seed would deadlock. Worth
knowing before touching the guard.

The signature, and why it is the weakest of the five:

  https://ftp.gnu.org/gnu/help2man/help2man-1.49.3.tar.xz.sig  (95 bytes)
  algo         17 (DSA), digest algo 2 (SHA-1), signed 2022-12-15
  key          87EA44D150D89615E39A3FEEF0DC8E00B28C5995
  identity     Brendan O'Dea <bod@debian.org>
  verified by  gpg against GNU's keyring, and by this pantry's own verifier
               when its key-flags check is bypassed — but NOT by `zpkb
               sourcepin` as it stands
  refused      because the key's self-signature is from 2001-06-19 and carries
               NO key-flags subpacket, so nothing in the key states that it may
               sign data: KeysById 1, KeysByIdUsage(KeyFlagSign) 0, and
               VerifySignature by hand nil. ⭐ A KEY OLDER THAN THE FLAG. This
               line used to say "declines DSA-with-SHA-1", which was inferred
               from the algo/digest numbers above and is wrong — SHA-1 is never
               judged, the lookup fails first (go-zpkg/zpkb#482, measured and
               corrected in go-zpkg/zpkb#508, merged)
  weak because SHA-1, which is a SEPARATE claim from the refusal and stays
               true: a 2022 DSA/SHA-1 signature is not evidence against a
               prepared file. The two were conflated here, and that is what
               produced the wrong sentence
  checked      when the digest was recorded, not at every build

No keyserver was asked. Five recipes, five shapes: sed has an independent
fingerprint and a published digest; m4 has both from its announcement; gawk
has a key in the keyring and nothing published; help2man has a key in the
keyring whose self-signature predates key flags, so our verifier will not treat
it as a signing key; make's key is not in that keyring at all.
EOT
}
