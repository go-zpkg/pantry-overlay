# openssl.org — the TLS and crypto library, and the single most depended-on
# project in this tree: 141 of our recipes name it.
#
# ⛔ WRITTEN FROM OPENSSL'S OWN FILES (go-zpkg/packages#431), at 3.5.9. First of
# the twenty-two that go-zpkg/recipes#143 measured as reachable from
# go-zpkg/base-toolchain's members but having no recipe at all — and the one
# needed whichever way the `_tkinter` question in that issue is decided, because
# `curl.se`, `python.org` and `tcl-lang.org` each reach it independently.
#
# ⚠ pkgxdev/pantry's recipe for this project was NOT opened. That tree carries
# no licence (see go-zpkg/packages#431), so it may not be copied or translated,
# and every fact below is cited to a file inside the OpenSSL release tarball or
# to this builder's own source. `consulted` is empty on purpose rather than
# empty by omission.

summary = "OpenSSL: the TLS/SSL and general-purpose cryptography library, and the `openssl` command"

# Read from LICENSE.txt, which is the Apache License 2.0 text and nothing else.
# ⛔ The historical OpenSSL/SSLeay dual licence ended with the 3.0 series; this
# tarball carries no trace of it, so the expression is a single identifier
# rather than the `OpenSSL AND SSLeay` an older recipe would need.
license = "Apache-2.0"

# ⛔⛔ THIS BLOCK WAS WRONG WHEN FIRST WRITTEN, AND RUNNING IT IS WHAT SAID SO.
# `strip = "/^openssl-/"` was taken from the TAG names (`openssl-3.5.9`), and
# `zpkb versions` answered `no candidate version matched`: the GitHub source
# reads release NAMES, which are `OpenSSL 3.5.9` — a different capitalisation
# and a space. Measured from https://github.com/openssl/openssl/releases.atom.
versions {
  github = "openssl/openssl/releases"
  strip  = "/^OpenSSL /"

  # ⛔⛔ THE ENUMERATION IS NARROWER THAN THE FEED, ON PURPOSE — but NOT because
  # everything it offers is pinned. Measured after writing it: this block
  # resolves ten versions, 3.5.0 through 3.5.9, and exactly ONE of them (3.5.9,
  # the newest, which is what `^3` picks) carries a digest above. An explicit
  # `=3.5.4` would resolve and fetch UNPINNED. That is the same shape as every
  # other recipe in this tree — gnu.org/gzip enumerates every gzip ever
  # published and pins one — and it is stated here rather than implied, because
  # the first version of this comment claimed the offered set was exactly the
  # vouched-for set and that was simply false.
  #
  # What the ignores below are actually for is the SUPPORTED LINE: keeping the
  # resolver inside the series upstream still distributes and our 141 consumers
  # have been built against.
  ignore = [
    # Pre-releases. The feed carries `OpenSSL 4.1.0-beta2`, `-beta1`,
    # `-alpha1`; none of them is a thing to resolve to.
    "/-(alpha|beta|pre)\\d*$/",

    # ⚠ THE 4.x LINE IS DELIBERATELY NOT OFFERED YET, and the reason is already
    # measured in this tree rather than assumed. projects/curl.se/package.hcl:49-56
    # records it: "gnu.org/wget 1.25.0 FAILS to compile against OpenSSL 4.1.0
    # … `src/openssl.c:230` calls `SSLv3_client_method`, which OpenSSL 4
    # removed", and concludes that "an unmeasured widening in a TLS dependency
    # is the last place to guess". All 141 of our consumers pin `^3`. Offering
    # 4.x from a recipe nobody has built against would hand the resolver a
    # major nothing here has tried.
    "/^4\\./",
    "/^[0-2]\\./",

    # ⚠ AND 3.6 IS NOT OURS TO OFFER EITHER, which is NOT the same reason.
    # github.com publishes an `OpenSSL 3.6.5` release, and upstream's own
    # source page does not list the 3.6 series AT ALL — measured 2026-11-17,
    # zero occurrences of "3.6." on https://openssl-library.org/source/, which
    # offers 3.5.9, 4.0.3 and 4.1.0 and nothing else. A GitHub release is not
    # the same statement as a published download, and `^3` resolving to a line
    # upstream has stopped distributing is how a dependency quietly leaves the
    # supported set.
    "/^3\\.6\\./",
    "/^3\\.[0-4]\\./",
  ]
}

distributable {
  url              = "https://github.com/openssl/openssl/releases/download/openssl-{{version.raw}}/openssl-{{version.raw}}.tar.gz"
  strip-components = 1

  # ⭐ SIGNATURE-VERIFIED, AND WITH A BETTER WARRANT THAN THIS TREE HAS HAD SO
  # FAR. Recorded with:
  #
  #   zpkb sourcepin \
  #     --sig https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz.asc \
  #     --key ./pubkeys.asc \
  #     --key-source "https://openssl-library.org/source/pubkeys.asc, fetched 2026-11-17" \
  #     --fingerprint "B146 647E 45A7 B339 47AB 226B 2A2C 87D1 6169 2D40" \
  #     --version 3.5.9 \
  #     https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz
  #
  # 53279637 bytes, signed by B146647E45A7B33947AB226B2A2C87D161692D40,
  # identity `OpenSSL <openssl@openssl.org>`, verified against the published
  # keyring with NO keyserver asked.
  #
  # ⛔ THE PUBLISHED FINGERPRINT IS THE PRIMARY KEY AND THE SIGNATURE IS BY A
  # SUBKEY, and upstream says so in the same breath as publishing it: "the
  # OpenSSL signing certificate whose PRIMARY key has the fingerprint B146 …
  # Signatures are produced by the current signing SUBKEY of this certificate,
  # which is certified by the primary key. This fingerprint is the canonical
  # trust anchor." `sourcepin` compares on the primary, which is why naming the
  # published value works; a tool comparing against the signer would have
  # reported a mismatch on a perfectly good signature.
  sha256 = {
    "3.5.9" = "603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"
  }

  # The signature URL is not a recipe field: `sig` is read by nothing
  # (go-zpkg/zpkb#282) and `sha` means "where the expected SHA-256 is
  # PUBLISHED", which the build fetches — a `.asc` there fails the build by
  # design. It is recorded in `provenance` below instead:
  #   https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz.asc
}

# ⚠ NO RUNTIME DEPENDENCIES, and that is a decision rather than an omission.
# OpenSSL's optional compression back-ends (zlib, brotli, zstd) are all OFF by
# default — INSTALL.md:1148 `zlib`, :1159 `enable-zstd`, :657 `enable-brotli` —
# and none is enabled below, so libssl links none of them. TLS-level compression
# is also the CRIME attack's vector, so leaving it off is the safer reading of a
# default rather than a corner cut: turning it on would ADD a runtime dependency
# AND an attack surface, to compress a stream TLS already protects.

build {
  dependencies = {
    "gnu.org/make" = "*"

    # ⛔ PERL IS A HARD BUILD REQUIREMENT, NOT A CONVENIENCE. INSTALL.md:51-53
    # lists it beside make and the C compiler: "Perl 5 with core modules" and
    # "The Perl module `Text::Template`". `Configure` IS a perl program
    # (Configure:1 `#! /usr/bin/env perl`) and it generates the Makefile.
    #
    # ⭐ AND Text::Template NEEDS NO PACKAGE OF ITS OWN, which was worth
    # checking rather than assuming: NOTES-PERL.md:72-76 says "we include a copy
    # of this module in the source … It will work as a fallback if the module
    # isn't already installed", and the copy is really in this tarball at
    # external/perl/Text-Template-1.56/lib/Text/Template.pm. ⚠ A first `find`
    # with `-maxdepth 3` reported external/ as holding no `.pm` at all, which
    # reads exactly like "not bundled" — the file is five levels down. The
    # project's own note is what contradicted the scan.
    "perl.org" = "*"
  }

  env = {
    ARGS = [
      # INSTALL.md:369 — the default prefix is /usr/local.
      "--prefix={{prefix}}",

      # ⛔⛔ THE DEFAULT OPENSSLDIR IS AN ABSOLUTE PATH OUTSIDE THE ARTIFACT.
      # INSTALL.md:355-362: "Directory for OpenSSL configuration files, and also
      # the default certificate and key store. Defaults are: Unix:
      # /usr/local/ssl". That value is COMPILED INTO libcrypto, so an unnamed
      # default would make every artifact we publish look for its configuration
      # in a directory that does not exist in a FROM-scratch image and belongs
      # to the host everywhere else.
      "--openssldir={{prefix}}/ssl",

      # ⛔⛔ AND THE DEFAULT LIBDIR IS NOT ALWAYS `lib`. INSTALL.md:341-353: "By
      # default this is `lib`. … Some build targets have a MULTILIB POSTFIX set
      # in the build configuration. For these targets the default libdir is
      # `lib<multilib-postfix>`. Please use `--libdir=lib` to override the
      # libdir if adding the postfix is undesirable."
      #
      # ⭐ This is the shape go-zpkg/recipes#88's libstdc++ member already cost
      # us an afternoon on: a switch whose default is DERIVED per target rather
      # than fixed, so the artifact's layout silently depends on which machine
      # built it. `fixup` does move lib64 → lib afterwards, which is exactly why
      # naming this matters — a repair that runs is indistinguishable from a
      # build that never needed one, and only one of those keeps working when
      # the repair is retired.
      "--libdir=lib",

      # Named rather than inherited. `shared` is the default on every unix
      # target in Configurations/, but `no-shared` is one word away and 141
      # recipes link these libraries; the thing 141 consumers depend on should
      # not be a default nobody wrote down.
      "shared",
    ]
  }

  script = [
    # ⛔⛔ THE RPATH IS THE ONE SWITCH THIS ARTIFACT CANNOT BE BUILT WITHOUT, and
    # it took reading BOTH sides to see it.
    #
    # OpenSSL's side, NOTES-UNIX.md:28-32: "For OpenSSL's application (the
    # `openssl` command), our configuration scripts do NOT generally set the
    # runtime shared library search path for you. It's therefore advisable to
    # set it explicitly when configuring".
    #
    # Our side, zpkb fixup/rpath.go: `SetRunpath` OVERWRITES an existing
    # DT_RUNPATH/DT_RPATH string slot in place, and returns ErrNoRunpath when
    # the ELF has neither (:15-17, :62-65). The caller at :274-278 then treats
    # that as tolerable — "tolerant, like patchelf on statically-linked/oddball
    # inputs" — logs a skip and returns nil.
    #
    # So a build with no rpath produces a GREEN artifact whose `openssl` cannot
    # find its own libcrypto.so.3 from a FROM-scratch image: fixup cannot ADD a
    # slot, only rewrite one, and the thing it wants to write is exactly the
    # `$ORIGIN/../lib` entry its own comment at :265-269 says every artifact
    # binary needs. The tolerant skip is correct for a static binary and silent
    # for this one.
    #
    # ⛔ `$(LIBRPATH)` IS UPSTREAM'S VARIABLE AND MUST REACH make, NOT THE SHELL.
    # NOTES-UNIX.md:54-62 is explicit — "Please do not use verbatim directories
    # in your runtime shared library search path! Some OpenSSL config targets
    # add an extra directory level for multilib installations. To help with
    # that, the produced Makefile includes the variable LIBRPATH" — and its own
    # example SINGLE-QUOTES the argument. Unquoted, `$(LIBRPATH)` is shell
    # command substitution: the shell would run `LIBRPATH` as a command, get
    # nothing, and hand Configure an empty `-Wl,-rpath,`. The single quotes
    # below are load-bearing, not decoration.
    #
    # ⭐ And the build-time value is LONGER than what fixup writes back
    # (`<store>/openssl.org/v3.5.9/lib` against `$ORIGIN/../lib`), so the
    # rewrite fits the slot and cannot hit ErrNoSpace (rpath.go:18-21).
    #
    # ⛔⛔ HASHBANGPERL IS SET BECAUSE THE DEFAULT BAKES ANOTHER PROJECT'S STORE
    # PATH INTO AN INSTALLED FILE. Configure:780 defaults
    # `PERL => env('PERL') || $^X` — the ABSOLUTE path of the perl that is
    # running Configure — and :774 derives `HASHBANGPERL => env('HASHBANGPERL')
    # || env('PERL')` from it. In this sandbox that is
    # `<store>/perl.org/v5.x.y/bin/perl`, and tools/c_rehash.in:1 is
    # `#!{- $config{HASHBANGPERL} -}`, so `bin/c_rehash` would ship with a
    # versioned store path of ANOTHER project in its shebang. That is precisely
    # what `zpkb bakedpaths` refuses (go-zpkg/zpkb#397 — "stale the day that
    # project is rebuilt"), so the artifact would not pass our own audit.
    # `VAR=value` on the Configure line is the documented lever
    # (INSTALL.md:1265-1272), and HASHBANGPERL is documented at :1298 as "Perl
    # invocation to be inserted after '#!' in public perl scripts".
    "./Configure $ARGS HASHBANGPERL='/usr/bin/env perl' '-Wl,-rpath,$(LIBRPATH)'",

    "make --jobs {{ hw.concurrency }}",

    # ⛔ `install_sw install_ssldirs`, NOT `install`. Configurations/
    # unix-Makefile.tmpl:665 defines `install: install_sw install_ssldirs
    # {install_docs if !disabled{docs}} {install_fips unless disabled}`, and
    # :707 defines install_ssldirs. Naming the two targets installs the software
    # and creates the configuration directory tree while leaving out the man and
    # HTML pages (INSTALL.md:1741-1751), which is both faster and smaller.
    #
    # ⚠ It is NOT the same as passing `no-docs`: that would ALSO change what
    # `make` builds, and the targets above are a statement about what we
    # INSTALL. One of them is reversible by a reader of this file; the other
    # changes the build.
    "make install_sw install_ssldirs",
  ]
}

# ⚠ `bin/openssl` ONLY, and `bin/c_rehash` is left out ON PURPOSE.
#
# tools/build.info:5-6 installs c_rehash as a SCRIPT, and tools/c_rehash.in:1 is
# `#!{- $config{HASHBANGPERL} -}` — a perl script. A script cannot run in an
# empty image, because the kernel resolves a shebang by ordinary path lookup and
# there is no interpreter there to find. This tree has already settled that
# question once, in projects/tukaani.org/xz/package.hcl, whose shell wrappers
# "are deliberately NOT listed: they are /bin/sh scripts, so they do not run in
# an empty image (go-zpkg/zpkx#151), and naming them here" would promise
# something the artifact cannot keep.
#
# The libraries are not listed either: `provides` names programs, and libcrypto
# and libssl are what 141 recipes link rather than run.
provides = [
  "bin/openssl",
]

test {
  script = [
    # The library a consumer links, and the header it compiles against.
    "test -f \"{{prefix}}/include/openssl/ssl.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libcrypto.* "{{prefix}}"/lib/libssl.* >/dev/null
EOT
    },

    # ⛔ THE VERSION THE BINARY REPORTS, not the one the recipe asked for. This
    # is the cheapest check that the thing which got installed is the thing that
    # was built.
    {
      run = <<EOT
"{{prefix}}/bin/openssl" version | grep -q "^OpenSSL {{version}} "
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR THE SHEBANG DEFECT ABOVE. If HASHBANGPERL is
    # ever dropped from the Configure line, `bin/c_rehash` silently regains a
    # versioned store path of another project and this artifact stops being
    # relocatable. bakedpaths would refuse it later; this fails it here, in the
    # recipe that caused it, which is where the reason is written down.
    #
    # ⚠ Asserted on the INSTALLED file rather than on the build log, for the
    # reason naming-a-switch-does-not-always-pin-it records: a value named on a
    # command line can still be rewritten by the build, so the witness has to be
    # the artifact.
    {
      run = <<EOT
if [ -f "{{prefix}}/bin/c_rehash" ]; then
  head -1 "{{prefix}}/bin/c_rehash" | grep -q '^#!/usr/bin/env perl$'
fi
EOT
    },

    # ⛔ IT HAS TO LINK AND IT HAS TO COMPUTE. A digest over known bytes
    # exercises libcrypto's real paths, so this fails both if openssl was built
    # against headers it cannot link at run time and if the arithmetic is wrong.
    # The expected value is SHA-256 of the three bytes `abc`, which is the
    # constant every SHA-2 test vector in the literature starts from.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <openssl/evp.h>
#include <stdio.h>
#include <string.h>
int main(void)
{
  unsigned char md[EVP_MAX_MD_SIZE];
  unsigned int n = 0, i;
  if (EVP_Digest("abc", 3, md, &n, EVP_sha256(), NULL) != 1)
    return 1;
  for (i = 0; i < n; i++)
    printf("%02x", md[i]);
  printf("\n");
  return 0;
}
SRC
"$CC" conftest.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lcrypto -o conftest
out="$(./conftest)"
want=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
test "$out" = "$want"
EOT
    },
  ]
}

provenance {
  read = [
    "LICENSE.txt",                  # the Apache-2.0 text, and no SSLeay licence beside it
    "VERSION.dat",                  # MAJOR/MINOR/PATCH 3.5.9, RELEASE_DATE "29 Sep 2026", SHLIB_VERSION=3
    "INSTALL.md",                   # :49-59 prerequisites; :341-353 libdir and the multilib postfix; :355-364 openssldir; :369-377 prefix; :1265-1272 VAR=value; :1298-1300 HASHBANGPERL; :1738-1751 the install targets
    "NOTES-UNIX.md",                # :28-32 no rpath is set for you; :54-62 LIBRPATH and the single-quoted example; :64-90 DT_RPATH vs DT_RUNPATH
    "NOTES-PERL.md",                # :72-76 Text::Template is bundled as a fallback
    "Configure",                    # :774 HASHBANGPERL from PERL; :780 PERL defaults to $^X; :805-808 it is a user variable
    "Configurations/unix-Makefile.tmpl", # :665 what `install` expands to; :707 install_ssldirs
    "tools/build.info",             # :5-6 c_rehash is installed as a SCRIPT
    "tools/c_rehash.in",            # :1 its shebang is the configured HASHBANGPERL
    "apps/build.info",              # the `openssl` program is the only one built here
    "external/perl/Text-Template-1.56/lib/Text/Template.pm", # the bundled copy really is in the tarball
  ]

  consulted = []

  note = <<EOT
⛔ pkgxdev/pantry's openssl.org recipe was deliberately NOT opened, which is why
`consulted` is empty rather than absent. That tree carries no licence
(go-zpkg/packages#431), so it may neither be copied nor translated, and a recipe
written beside it is hard to prove independent of it. Every switch above is
cited to a line in this tarball or in this builder's own source.

⭐ THE DIGEST IS VOUCHED FOR, AND BY A KEY FROM A DIFFERENT ORIGIN THAN THE
ARCHIVE. gzip, the first signature-verified pin in this tree, had to record that
its keyring came from the SAME host as the tarball, which establishes continuity
rather than independence. Here the archive is served by github.com and the
keyring by openssl-library.org, which is a genuinely separate origin — and
upstream states which copy wins: "The copy on this website is authoritative:
where the key server and this website disagree, this website takes precedence."

Two limits on that warrant, stated because every other distribution's
documentation is silent on them:

  - naming the fingerprint meant only that key was read out of pubkeys.asc
    ("1 key(s) read from the file"). That is the designed behaviour — it is what
    lets a large keyring be used at all — but it means this run checked the key
    we asked for and did not survey the others the file carries.
  - the digest was confirmed by a second, independent path (`curl` +
    `shasum -a 256`, same 603f5602…). ⚠ That agreement is worth little ON ITS
    OWN: both paths fetch the same URL, so a server serving different bytes
    would satisfy both — the lesson go-zpkg/recipes#117 recorded as "the
    cross-check that AGREED was worthless". It is the SIGNATURE that breaks the
    common cause, and the cross-check only rules out a local fetch bug.

⭐⭐ WRITING THIS FOUND A DEFECT NOTHING WAS LOOKING FOR, and it would not have
failed the build: `bin/c_rehash`'s shebang takes the absolute path of whichever
perl ran Configure (Configure:780, :774), which in this sandbox is another
project's VERSIONED store path. `zpkb bakedpaths` refuses exactly that shape
(go-zpkg/zpkb#397), so the artifact would have been built, installed, tested and
then refused by our own audit — or worse, published by a lane that does not run
that audit and broken the day perl.org is rebuilt. HASHBANGPERL is named on the
Configure line, and the `test` block asserts the INSTALLED shebang so that
dropping it fails here rather than three repositories away.

⚠ NOT BUILT. This recipe has not been through `zpkb build`: writing it needed no
build, and the factory run that would prove it belongs to whoever has a builder.
What IS measured here is the digest and its signature, the switch census against
the project's own documentation, and `zpkb lint` over the tree. The scripts
above are a claim about OpenSSL's build system read from that build system, and
they stay a claim until a factory runs them.
EOT
}
