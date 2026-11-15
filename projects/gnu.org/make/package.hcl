# make — GNU Make, the tool every other recipe here is built WITH.
#
# ⛔ WRITTEN FROM MAKE'S OWN FILES at 4.4.1, continuing #88: the base toolchain
# names 25 members, and the ones with no standalone recipe of ours cannot be
# built into the sovereign registry at all (go-zpkg/packages#440,
# go-zpkg/packages#431). Measured 2026-11-15 over the 70-project BUILD closure
# of `go-zpkg/base-toolchain`: 14 fragments, 11 standalone, 45 with no recipe
# of ours — 59 of 70 still to do. Of the 25 named members: 8 standalone,
# 8 fragments, 9 absent.
#
# ⭐ IT IS THE RIGHT ONE AFTER m4 FOR THE SAME REASON m4 WAS FIRST: a seed has
# to be buildable before the things it seeds exist, and this one's only
# external requirement after `--disable-nls --without-guile` is a C compiler
# and a shell. Everything else in the toolchain is built by invoking it.

summary = "GNU Make: a tool which controls the generation of executables"

# COPYING is the GPLv3 text (its first lines: "GNU GENERAL PUBLIC LICENSE /
# Version 3, 29 June 2007"); src/main.c:6-8 carries "either version 3 of the
# License, or (at your option) any later version". Both files, because only the
# second answers the "-or-later".
license = "GPL-3.0-or-later"

# ⛔ `.tar.gz` AND NOT `.tar.lz`, AND THAT IS A MEASUREMENT RATHER THAN A
# PREFERENCE. ftp.gnu.org/gnu/make/ publishes 4.4.1 as `.tar.gz` and `.tar.lz`
# only — there is no `.tar.xz` for this project, unlike m4 — and the builder's
# own fetcher does not know lzip: `fetch/fetch.go:239-256` maps extensions to
# `.tar.gz/.tgz`, `.tar.xz`, `.tar.bz2/.tbz2`, `.zip` and `.tar`, and returns
# "" for anything else. A recipe naming the `.lz` would fail at unpack, after
# the download and after the digest check had passed.
versions {
  url   = "https://ftp.gnu.org/gnu/make/"
  match = "/make-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^make-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/make/make-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2 348 200 bytes, fetched and hashed with the builder's own fetcher
  # (`zpkb sourcepin`), not with `curl | shasum`.
  #
  # ⭐ A SECOND, INDEPENDENT WITNESS TO THE BYTES — and it is NOT a SHA-256.
  # The release announcement (info-gnu, 2023-02-26, on lists.gnu.org rather
  # than ftp.gnu.org) publishes two unlabelled 32-hex-digit checksums:
  #
  #   c8469a3713cbbe04d955d4ae4be23eeb  make-4.4.1.tar.gz
  #   c8b13b7477e812d4213a9b88ff0ff1d6  make-4.4.1.tar.lz
  #
  # Thirty-two hex digits is an MD5 digest, not a SHA-256 one, and the message
  # nowhere names the algorithm. `md5 make-4.4.1.tar.gz` on the bytes we
  # fetched returns exactly `c8469a3713cbbe04d955d4ae4be23eeb`, so a document
  # published years earlier, on a different host, attests THESE bytes.
  #
  # ⛔ What that is worth, stated rather than implied: MD5 is broken for
  # collision resistance, so this witness defends against a corrupted or
  # swapped file and NOT against a prepared one. It is also the same
  # organisation, so it is continuity rather than independence. It is recorded
  # because a weak second witness that is named beats a strong one that is
  # imagined — and because m4's recipe could claim a SHA-256 from its
  # announcement, so the difference between the two would otherwise look like
  # carelessness here.
  sha256 = {
    "4.4.1" = "dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3"
  }

  # ⛔ NO `sha` FIELD. `sha` means "where the expected SHA-256 is PUBLISHED" —
  # a file the build fetches and compares — and no such file exists for this
  # project. Putting the signature URL there would fail every build (#89); it
  # is recorded in `provenance` below instead, where the whole chain is, with
  # the part of it that could not be completed.
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ LOAD-BEARING, NOT HOUSE HABIT. `configure.ac:60` is
      # `AM_GNU_GETTEXT([external])`: make does NOT bundle libintl, so NLS is a
      # real build dependency on gnu.org/gettext — which is itself one of the
      # base-toolchain members with no recipe of ours. Enabled, this recipe
      # could not be built in the generation that has to build it.
      "--disable-nls",

      # ⛔⛔ THE ONE FLAG THAT IS A REFUSAL RATHER THAN A CHOICE.
      # `configure.ac:162-200` wraps the whole Guile probe in
      # `AS_IF([test "x$with_guile" != xno], …)` — so Guile support is
      # AUTO-DETECTED unless it is switched off, and the probe is
      # `PKG_CHECK_EXISTS([guile-3.0]) … [2.2] … [2.0] … [1.8]` followed by a
      # real compile and link.
      #
      # That is the `with_selinux=maybe` shape this fleet has already paid for
      # twice (overrides/gnu.org-coreutils.hcl, overrides/gnu.org-sed.hcl):
      # a build that links whatever happens to be on the builder, producing an
      # artifact whose dependencies depend on the machine. `make` linked
      # against a libguile no consumer installs is a `make` that does not
      # start.
      #
      # It also keeps the recipe honest about pkg-config: `PKG_PROG_PKG_CONFIG`
      # (configure.ac:167) runs OUTSIDE that AS_IF, so configure still looks
      # for pkg-config — but with the probe skipped, not finding it decides
      # nothing. freedesktop.org/pkg-config is another member with no recipe of
      # ours, so a recipe that NEEDED it could not be built yet either.
      "--without-guile",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  # ⛔ `--enable-job-server` AND `--enable-load` ARE LEFT AT THEIR DEFAULTS,
  # WHICH ARE BOTH `yes`, AND THAT IS READ RATHER THAN ASSUMED:
  # `configure.ac:294-297` sets `make_cv_job_server="yes"` when the flag is not
  # given, and `:332-335` sets `make_cv_load="yes"`. Neither needs anything
  # outside the toolchain — the job server is pipes and `waitpid`, and `load`
  # needs `dlopen`, for which `:342` searches `-ldl` and finds it in glibc,
  # which IS a member. Disabling either would make this artifact quietly
  # different from every other `make` a recipe here might expect, and `-jN` is
  # how the whole factory builds.
  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# `Makefile.am:26` — `bin_PROGRAMS = make`, and there is no `bin_SCRIPTS`. One
# binary is the whole of it; upstream ships no `gmake` or `gnumake` alias, and
# this recipe does not invent one.
#
# ⛔ It also installs a HEADER, which `provides` has no way to say:
# `Makefile.am:27` is `include_HEADERS = src/gnumake.h`, the API for the `load`
# feature kept above. A consumer that compiles a make extension needs it, and
# nothing in this recipe's declared surface mentions it — named here so the
# next reader does not conclude the install was incomplete.
provides = [
  "bin/make",
]

test {
  script = [
    "make --version | grep {{version.raw}}",

    # A real makefile, built. `--version` passes on a make that cannot read a
    # file or run a command.
    "mkdir -p /tmp/make-selftest && cd /tmp/make-selftest && printf 'all:\\n\\t@echo built\\n' > Makefile && test \"$(make)\" = built",

    # ⛔⛔ THE ASSERTION THAT ANSWERS THE BUILD'S ONE REAL QUESTION, as m4's
    # `esyscmd` does for m4. `$(shell …)` execs the shell, so this is what
    # proves a shell resolved in the tree this artifact was built in: in the
    # sovereign generation /bin/sh is a symlink into gnu.org/bash
    # (`build/runner.go:303-305`). A make that cannot run a command would pass
    # every assertion above and then fail every `./configure` with a message
    # about something else entirely.
    "cd /tmp/make-selftest && printf 'all:\\n\\t@echo $$(shell echo shell-works)\\n' > Makefile2 && test \"$(make -f Makefile2)\" = shell-works",

    # The job server, kept on by default above: two targets under -j2, which is
    # how every build in this factory runs. A make built without it still
    # accepts -jN and serialises, so the count is what distinguishes them.
    "cd /tmp/make-selftest && printf 'all: a b\\na:\\n\\t@echo a\\nb:\\n\\t@echo b\\n' > Makefile3 && test \"$(make -j2 -f Makefile3 | sort | tr -d '\\n')\" = ab",
  ]
}

provenance {
  read = [
    "configure.ac",    # :19 AC_INIT 4.4.1; :60 AM_GNU_GETTEXT external; :162-200 the Guile auto-detection; :167 PKG_PROG_PKG_CONFIG outside it; :294-297 job-server default yes; :332-343 load default yes, dlopen via -ldl
    "Makefile.am",     # :24 SUBDIRS = lib po doc; :26 bin_PROGRAMS = make; :27 include_HEADERS = src/gnumake.h; :29 man_MANS = doc/make.1; :114 EXTRA_DIST ships it
    "doc/Makefile.am", # :21 info_TEXINFOS = make.texi — and the tarball already carries make.info{,-1,-2,-3} and make.1 built
    "NEWS",            # "26 February 2023", the date the signature was made
    "COPYING",         # the GPLv3 text that ships
    "src/main.c",      # :6-8 "either version 3 of the License, or"
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/info-gnu/2023-02/msg00011.html",
    "go-zpkg/base-toolchain/package.hcl", # :69, which asks for make by name
    "gnu.org/m4/package.hcl",             # the first of these, whose shape this follows
  ]

  note = <<EOT
Second of the base-toolchain members written from the project's own files
(#88, after gnu.org/m4). Nothing was converted: the version, the digest, the
two flags that matter, the two defaults deliberately left alone and the four
assertions all come from make's own files.

⭐ THE DOCUMENTATION NEEDS NO TOOL TO BUILD, as with m4. doc/ ships make.info,
make.info-1, make.info-2, make.info-3 and make.1 pre-built, and `Makefile.am:29`
installs the man page from `doc/make.1` rather than generating it. So
`make install` installs the manual and the man page without makeinfo or
help2man — which matters because gnu.org/texinfo and gnu.org/help2man are also
base-toolchain members without standalone recipes, and declaring either would
have made a cycle out of a seed. The same timestamp-skew hazard m4 names
applies and is not mitigated here either: if `make` decides a shipped .info is
older than make.texi it will call makeinfo, and the builder deliberately does
NOT no-op MAKEINFO (build/build.go:758-763).

⛔⛔ THE SIGNATURE IS GOOD AND `sourcepin` STILL DECLINES IT: THE KEY HAS
EXPIRED. This section said "NOT VERIFIED … key NOT OBTAINED" until
2026-11-15 19:26, which was wrong, and the six steps below keep the whole
reading because the error is more useful than the answer.

  signature    https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz.sig  (833 bytes)
  signed       2023-02-26, matching NEWS and the announcement
  issuer       B2508A90102F8AE3B12A0090DEACCAAEDB78137A — Paul D. Smith's
               SIGNING SUBKEY, whose primary is 6D4EEB02AD834703510B117680CB727A20C79BB2
  key          IN GNU's KEYRING, exportable, and EXPIRED
  gpg says     "Good signature from Paul D. Smith <paul@mad-scientist.net>"
               followed by "Note: This key has expired!"
  sourcepin    refuses: "openpgp: key expired"

What was tried, and what each attempt answered:

  1. `zpkb sourcepin --sig auto --key gnu-keyring.gpg` with no fingerprint:
     refused, because `gnu-keyring.gpg` cannot be read whole — one entity in a
     thirty-year archive has multiple embedded signatures and the OpenPGP
     reader then returns nothing at all. This is the limit m4's recipe records,
     and it is why naming a fingerprint is what rescues the file.
  2. The same with `--fingerprint B2508…137A`: "no key matching … among the
     402 primary key(s) that could be read, and the packet stream stops being
     readable after them". So the key is either beyond the unreadable entity or
     not in this copy of the keyring.
  3. `gpg --no-default-keyring --keyring gnu-keyring.gpg --list-keys B2508…`:
     "Note: Specified keyrings are ignored due to option use-keyboxd", then
     "error reading key: No public key". A second implementation could not read
     it either, on this host, for an unrelated reason.
  4. ⛔⛔ THE ANSWER THIS RECIPE FIRST GAVE HERE WAS WRONG, and the correction
     is the most instructive thing in the file. It said: the keyring holds one
     Paul D. Smith key, `B2508A90…137A` appears nowhere in its listing, so the
     key is ABSENT. All three statements came from one reading of

       gpg --list-keys --with-subkey-fingerprints "Paul D. Smith"

     against the whole keyring imported into a throwaway GNUPGHOME, which
     printed

       pub rsa4096 2016-10-22 [SC] 6D4EEB02AD834703510B117680CB727A20C79BB2
       sub rsa4096 2016-10-22 [E]  C97BE9DA95DD78299B30F4C2609DAAD35F61D607

     — one encryption subkey and no sign of `B2508A90…`. **That listing was
     not a search result.** `B2508A90…137A` is Paul D. Smith's SIGNING SUBKEY
     of exactly that primary key, and gpg omitted it because it has EXPIRED.
     Reading "not shown" as "not there" is the whole of the error.

  5. ⭐ WHAT IS ACTUALLY TRUE, measured 2026-11-15 19:25. `gpg --export` on
     that fingerprint produces 6 287 bytes, `sourcepin` accepts the file as
     holding that exact key, and the refusal changes to the real reason:

       openpgp: key expired

     while gpg, given the same signature and tarball, says:

       gpg: Good signature from "Paul D. Smith <paul@mad-scientist.net>"
       gpg: Note: This key has expired!
             6D4EEB02AD834703510B117680CB727A20C79BB2
             B2508A90102F8AE3B12A0090DEACCAAEDB78137A

     The two fingerprints on the last lines are the primary and the signing
     subkey, which is the fact the first reading missed.

     So the signature IS good, by a key in GNU's own keyring, under the
     maintainer's identity. What stops `sourcepin` is EXPIRY — a statement
     that the owner stopped vouching for the key after a date, not that the
     bytes were signed by somebody else. The signature was made 2023-02-26.

     ⛔ Unlike gnu.org/help2man's case (zpkb#482), the message here names the
     right cause: "key expired" is accurate and actionable. The defect was in
     the reading, not the tool.

  6. And for comparison, the other branch of step 2's disjunction is real too:
     gnu.org/coreutils' key sits BEYOND the 402 the Go reader manages, and
     exporting that one key makes `sourcepin` verify it outright. So the
     keyring yields three different outcomes — reachable (sed, gawk),
     beyond the break but exportable (coreutils), and exportable but expired
     (make).

⛔ AND THE FINGERPRINT THE SIGNATURE CARRIES IS NOT AN INDEPENDENT STATEMENT.
It is the signature naming the key it was made with, which is circular as
trust: it pins WHICH key, it does not attest that the key is the maintainer's.
m4 could close that loop because its release announcement prints the
fingerprint; make's announcement prints no fingerprint and no key id at all —
read, not assumed (info-gnu 2023-02/msg00011). And a keyserver is not an answer
here: this project never asks one, because an unknown key fetched and accepted
degrades "verified" to "somebody signed it".

So the digest stands on:

  - our own fetch-and-hash;
  - the announcement's MD5, from a different host (weak algorithm, same
    organisation);
  - and a signature that is GOOD by the maintainer's key in GNU's keyring,
    which `sourcepin` declines because that key has expired.

That is weaker than gnu.org/sed's (independent fingerprint, live key) and
stronger than what this recipe claimed until now. The chain is checkable at
every link; what it does not have is a key its owner still vouches for.

⭐ WHAT WOULD FINISH IT: a current signature, or a per-key published source
naming `B2508A90…137A` as the right key for this release — the maintainer's
own page, the project's git repository. Not a keyserver: this project never
asks one, because an unknown key fetched and accepted degrades "verified" to
"somebody signed it".

⛔⛔ AND THE LESSON THIS FILE NOW CARRIES IS ABOUT READING, NOT ABOUT KEYS. I
had four measurements, each one real, and assembled them into a false
conclusion — "the key is absent" — because the fourth was a LISTING and I used
it as a SEARCH. An expired subkey is not printed; "not printed" is not "not
present"; and the sentence I wrote was checkable by anybody with the keyring
and one `gpg --export`. The instrument that finally separated the cases is the
one that compares the forty hex digits and says which of three things went
wrong: no such key, key expired, or signature not by it.
EOT
}
