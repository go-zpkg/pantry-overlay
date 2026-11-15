# sed — GNU sed, the stream editor.
#
# ⛔ WRITTEN FROM SED'S OWN FILES at 4.10, continuing #88 after gnu.org/m4 and
# gnu.org/make (go-zpkg/packages#440, go-zpkg/packages#431). It was five lines.
#
# ⭐ AND IT IS THE FIRST OF THESE WHERE THE OVERRIDE IN go-zpkg/packages HAD TO
# BE READ FIRST, because `overrides/gnu.org-sed.hcl` patches UPSTREAM's recipe
# as it is read, and the overlay's copy is what a consumer resolves and what
# zpkb builds. A standalone recipe written without the override's two
# corrections would RE-ACQUIRE both defects, in the half the override cannot
# reach. Both are carried here natively, from sed's own files rather than from
# the override's word for it — and one of the two turned out to need no
# dependency at all.

summary = "GNU sed: a stream editor for filtering and transforming text"

# COPYING is the GPLv3 text ("GNU GENERAL PUBLIC LICENSE / Version 3,
# 29 June 2007"); sed/sed.c:6 carries "either version 3, or (at your option)".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/sed/"
  match = "/sed-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^sed-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/sed/sed-{{version.raw}}.tar.xz"
  strip-components = 1

  # ⭐⭐ THE STRONGEST CHAIN OF THE THREE SO FAR, and every leg was measured.
  # 1 732 800 bytes, fetched and hashed with the builder's own fetcher.
  #
  #   signature    https://ftp.gnu.org/gnu/sed/sed-4.10.tar.xz.sig
  #   signed       2026-04-22 (the release is dated 2026-04-21)
  #   identity     Jim Meyering <jim@meyering.net>
  #   fingerprint  155D3FC500C834486D1EEA677FD9FCCB000BEEEE
  #   verified     when the digest was recorded, not at every build
  #
  # ⛔ AND THE FINGERPRINT CAME FROM A DIFFERENT HOST THAN THE TARBALL, which
  # is the leg that makes "verified" mean something. The release announcement
  # (info-gnu 2026-04/msg00009, on lists.gnu.org) prints
  #
  #   The signature should match the fingerprint of the following key:
  #   pub rsa4096/0x7FD9FCCB000BEEEE 2010-06-14 [SCEA]
  #   Key fingerprint = 155D 3FC5 00C8 3448 6D1E  EA67 7FD9 FCCB 000B EEEE
  #
  # and that is the same fingerprint the detached signature names as its issuer
  # (`gpg --list-packets`: "hashed subpkt 33 len 21 (issuer fpr v4
  # 155D3FC500C834486D1EEA677FD9FCCB000BEEEE)"). The signature naming its own
  # key would be circular; an announcement on another host naming it is not.
  #
  # ⭐ A SECOND WITNESS TO THE BYTES TOO, and in base64 rather than hex: the
  # same announcement publishes
  #
  #   SHA256 (sed-4.10.tar.xz) = uOchgrLslqNXTimYxHt6qmTMIM4ADY6awxPMB87PKMc=
  #
  # with the algorithm NAMED (unlike gnu.org/make's, whose announcement gives
  # two unlabelled 32-hex-digit strings — MD5). Decoded and compared by a
  # program rather than by eye, because "those look like the same digest" is
  # not a measurement: 32 bytes each, identical, byte for byte.
  sha256 = {
    "4.10" = "b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7"
  }

  # ⛔ NO `sha` FIELD: `sha` means "where the expected SHA-256 is PUBLISHED", a
  # file the build fetches and compares, so a `.sig` there fails every build
  # (#89). The signature URL lives in `provenance` below (go-zpkg/zpkb#282).
}

build {
  # ⛔⛔ NO DEPENDENCIES, AND THE ONE THAT LOOKED NECESSARY IS NOT.
  #
  # `doc/local.mk:45` regenerates `doc/sed.1` from the freshly built binary, so
  # the rule DOES fire in every build, and `:30-43` chooses how:
  #
  #   if CROSS_COMPILING  → $(SHELL) doc/dummy-man
  #   else if HAVE_PERL   → $(PERL) -- $(top_srcdir)/build-aux/help2man
  #   else                → $(SHELL) doc/dummy-man
  #
  # So help2man is VENDORED (`:20`, build-aux/help2man) and gnu.org/help2man is
  # never needed — which matters, because it is another base-toolchain member
  # with no standalone recipe. And perl is optional: upstream's own comment is
  # "Graceful degradation for systems lacking perl".
  #
  # ⛔ The degradation path runs `doc/dummy-man`, WHICH CALLS `sed` — twice,
  # `sed 's,.*/,,'` and `sed 's/\.x$$/.1/'`. Building sed with sed looks like
  # the trap gnu.org/grep hit, where the recipe named itself as a build
  # dependency. It is not one, and the reason is in the overlay's own grep
  # recipe (`projects/gnu.org/grep/package.hcl:65-71`): the base toolchain
  # stages `gnu.org/sed` beside grep and gawk, and THAT package is what builds
  # the image, so the sandbox already has a sed on PATH. Naming itself was
  # removed from grep as wrong, and 15 of the 16 recipes here that run
  # `./configure` declare no such thing.
  #
  # ⭐ And `dummy-man` does not produce a stub: it COPIES the distributed man
  # page (`dist_man=…; test -f "$$dist_man" && cp "$$dist_man" "$$output"`),
  # which ships in the tarball as `doc/sed.1`, 434 lines. The stub branch is
  # reached only if that file is missing. `doc/sed.info` ships pre-built too,
  # so gnu.org/texinfo is not needed either.
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ LOAD-BEARING, and it is ALSO half of what the override exists for.
      # `configure.ac:114` is `AM_GNU_GETTEXT([external])` — sed bundles no
      # libintl — and `overrides/gnu.org-sed.hcl` adds
      # `dependencies.darwin: gnu.org/gettext` because "sed links libintl on
      # darwin and never said so".
      #
      # ⭐ With NLS off there is nothing to link, so this recipe needs no
      # gettext dependency on any platform: the flag removes the coupling the
      # override had to declare. That is a better fix than carrying the
      # dependency forward, and it is why this recipe's `dependencies` is
      # absent rather than copied from the override.
      "--disable-nls",

      # ⛔⛔ THE OTHER HALF OF THE OVERRIDE, AND IT IS STILL LIVE AT 4.10 —
      # checked in sed's own files, not taken on the override's word.
      # `m4/selinux-selinux-h.m4:75-77` is
      #
      #     AC_ARG_WITH([selinux], …, [], [with_selinux=maybe])
      #
      # and `:84` is `AC_SEARCH_LIBS([getfilecon_raw], [android-selinux
      # selinux], …)`. `maybe` is AUTO-DETECTION: on a builder that has
      # libselinux — every Ubuntu one does — the artifact comes out linked
      # against a library nothing in this factory provides.
      #
      # Measured by `zpkb builder`'s soname census over the staged s390x rootfs
      # (go-zpkg/zpkb#276), which named this very package:
      #
      #   libselinux.so.1 ← gnu.org/sed/v4.10/bin/sed
      #
      # The override's note allowed that a release whose gnulib import lacked
      # the module would make the flag a harmless warning. 4.10 is not such a
      # release: m4/ carries selinux-selinux-h.m4, selinux-context-h.m4 and
      # selinux-label-h.m4, and lib/ carries se-selinux.c and getfilecon.c.
      "--without-selinux",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  # ⛔ `--disable-i18n` IS NOT PASSED, AND IT IS NOT `--disable-nls` BY ANOTHER
  # NAME. `configure.ac:122-127` defaults it to ENABLED, and switching it off
  # sets `ac_cv_func_wcscoll=no` — it changes how sed COLLATES multibyte text,
  # which is behaviour a consumer sees, not a build-time dependency. NLS is
  # message translation; i18n here is character handling. Disabling it to match
  # the other flag would produce a sed that mishandles UTF-8 input.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# `sed/local.mk:16` — `bin_PROGRAMS += sed/sed`, appended to the empty
# `bin_PROGRAMS =` at `Makefile.am:35` (a non-recursive build assembled from
# per-directory local.mk files). One binary; no `gsed` alias is invented.
provides = [
  "bin/sed",
]

test {
  script = [
    "sed --version | grep {{version.raw}}",

    # The substitution every build script in this factory depends on.
    "test \"$(echo hello | sed 's/hello/world/')\" = world",

    # A BRE back-reference and a character class: the parts of sed that
    # `./configure` scripts lean on hardest.
    "test \"$(echo aXb | sed 's/a\\([A-Z]\\)b/\\1/')\" = X",

    # ⛔ IN-PLACE EDITING, which is what `fixup`'s staging-script repair and
    # half the recipes here actually call sed FOR (`sed -i.bak` appears in
    # overrides/unbound.net and in zpkb's own stagingscripts pass). It
    # exercises file creation, renaming and the backup suffix in one line, and
    # it is the one mode that fails differently on a BSD sed.
    "cd /tmp && printf 'one\\ntwo\\n' > sed-selftest.txt && sed -i.bak 's/two/three/' sed-selftest.txt && test \"$(cat sed-selftest.txt)\" = \"$(printf 'one\\nthree')\"",

    # ⛔⛔ THE ASSERTION FOR THE FLAG THAT IS LEFT ON. i18n enabled is what
    # makes a multibyte character ONE character rather than its bytes: `.`
    # must match the whole of é, so the result is the two surrounding letters.
    # A sed built with --disable-i18n would leave a stray byte here and pass
    # every assertion above.
    "test \"$(printf 'aéb' | sed 's/./X/2')\" = aXb",
  ]
}

provenance {
  read = [
    "configure.ac",              # :17-19 AC_INIT from git-version-gen; :114 AM_GNU_GETTEXT external; :122-127 --disable-i18n defaults to enabled and only sets ac_cv_func_wcscoll=no
    "m4/selinux-selinux-h.m4",   # :75-77 with_selinux=maybe is AUTO-DETECTION; :84 AC_SEARCH_LIBS getfilecon_raw in -lselinux
    "Makefile.am",               # :18 SUBDIRS = po . gnulib-tests; :35 bin_PROGRAMS = (empty, appended from local.mk)
    "sed/local.mk",              # :16 bin_PROGRAMS += sed/sed
    "doc/local.mk",              # :16 info_TEXINFOS; :18 dist_man_MANS = doc/sed.1; :20 HELP2MAN is VENDORED in build-aux; :30-43 the three run_help2man branches; :45-54 the rule fires on every build
    "doc/dummy-man",             # it COPIES the distributed man page, and it calls `sed` to do it
    "COPYING",                   # the GPLv3 text that ships
    "sed/sed.c",                 # :6 "either version 3, or (at your option)"
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/info-gnu/2026-04/msg00009.html",
    "go-zpkg/packages overrides/gnu.org-sed.hcl", # the two corrections this recipe had to carry natively
    "gnu.org/grep/package.hcl",                   # :65-71, why a recipe here does not name itself
    "gnu.org/m4/package.hcl",                     # the shape these follow
  ]

  note = <<EOT
Third of the base-toolchain members written from the project's own files (#88,
after gnu.org/m4 and gnu.org/make). Nothing was converted.

⭐⭐ WHAT WRITING IT FOUND, which is the point of writing rather than
converting:

  - the override's darwin `gnu.org/gettext` dependency is UNNECESSARY here.
    It existed because sed links libintl without declaring it; with
    `--disable-nls` there is nothing to link, on any platform. The override
    could not do that — it patches a recipe whose build.script it must not
    rewrite wholesale — and a standalone recipe can.
  - the override's `--without-selinux` IS still necessary at 4.10, and that
    was checked rather than assumed: the override's own note allowed that a
    newer gnulib import might not carry the module, which would make the flag
    a warning. It carries it.
  - `doc/dummy-man` calling `sed` looked like gnu.org/grep's
    self-dependency trap and is not one: the base toolchain stages
    `gnu.org/sed`, so the sandbox has a sed. The grep recipe had to have that
    note REMOVED as wrong; reading it first is what kept this recipe from
    reintroducing it.

⛔ AND THE KEYRING'S UNREADABILITY IS POSITIONAL, NOT ABSOLUTE — a measurement
that sharpens gnu.org/make's recipe, which could only state it as a
hypothesis. `gnu-keyring.gpg` cannot be read whole (one entity has multiple
embedded signatures and the OpenPGP reader then returns nothing), and
`sourcepin` reports how far it got before giving up. For make's key it said
"no key matching … among the 402 primary key(s) that could be read". Here the
same file, the same binary, the same flag:

  the named key, found after walking 326 primary key(s) in the file

So the file is readable up to the broken entity, and whether a key is
reachable depends on WHERE IT SITS. Jim Meyering's is before it; Paul Smith's
is beyond it. make's note should be read with that in mind: its signature is
not unverifiable in principle, it is unverifiable from THIS copy of this
keyring, and a per-key published source would settle it.

The chain, for the record:

  signature    https://ftp.gnu.org/gnu/sed/sed-4.10.tar.xz.sig
  key          ftp.gnu.org/gnu/gnu-keyring.gpg, local copy
  identity     Jim Meyering <jim@meyering.net>
  fingerprint  155D3FC500C834486D1EEA677FD9FCCB000BEEEE, from the release
               announcement on lists.gnu.org — a different host from the one
               serving the tarball, which is what the other GNU recipes here
               could not all claim
  digest       announced in base64 by the same message, decoded and compared
               to ours by a program: identical, 32 bytes
  checked      when the digest was recorded, not at every build

No keyserver was asked. An unknown key is a refusal here, not a download.
EOT
}
