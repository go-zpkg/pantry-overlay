# bash — the GNU Bourne-Again SHell.
#
# ⛔ WRITTEN FROM BASH'S OWN FILES (go-zpkg/packages#431), at 5.3. Sixth whole
# recipe of the sovereign pantry.
#
# ⭐ AND ITS INHERITED BUILD BLOCK TURNED OUT TO BE SOUND, which is worth saying
# because the two before it were not. go-zpkg/pantry-overlay#85 recorded two
# user-visible defects found in two inherited blocks and said a gate becomes
# worth building at the third. Three suspicions were raised here and the source
# cleared all three — see the notes in `build`. The hit rate is 2 of 3, not 3
# of 3, and the gate stays unbuilt.

summary = "GNU bash: the Bourne-Again SHell"

# COPYING is the GPLv3 text; shell.c:9 has "either version 3 of the License, or"
# — the "-or-later" comes from the source header, not from COPYING.
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/bash/"
  match = "/bash-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^bash-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/bash/bash-{{version.raw}}.tar.gz"
  strip-components = 1

  # Recorded with `zpkb sourcepin --sig auto --key <gnu-keyring.gpg>
  # --fingerprint 7C0135FB088AAF6C66C650B9BB5869F064EA74AB`: 11 355 854 bytes,
  # signed 2025-07-30 by Chet Ramey <chet@cwru.edu>, the named key found after
  # walking 143 primary keys in the GNU keyring. Confirmed by a second,
  # independent fetch-and-hash.
  #
  # ⭐ A DIFFERENT KEY FROM gnu.org/gzip AND gnu.org/grep, which Jim Meyering
  # signs. Two maintainers, two fingerprints, one keyring — which is exactly
  # why the fingerprint has to be named per recipe rather than trusted per
  # keyring. The signature is also 95 bytes where Meyering's are 833: an
  # elliptic-curve key against an RSA-4095 one. Nothing depends on that here;
  # it is noted because "all GNU signatures look alike" is the kind of
  # assumption that holds until it does not.
  sha256 = {
    "5.3" = "0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba"
  }

  # ⛔⛔ THE SIGNATURE URL WAS WRITTEN HERE AS `sha`, AND `sha` MEANS SOMETHING
  # ELSE: "where the expected SHA-256 of the archive is published … the build
  # FETCHES it and refuses a mismatch" (schema/package.schema.json:141,
  # build/runner.go:769-781). Measured with the builder's own reader,
  # fetch.DeclaredSHA256 on a `.sig` returns "no line names <archive> — the
  # server returned text, not an archive: \"-----BEGIN PGP SIGNATURE----- …\"",
  # and an unreadable checksum file is a build failure by design
  # (runner.go:746-749). `zpkb lint` cannot see it, because linting does not
  # fetch.
  #
  # No schema field exists for a detached signature (go-zpkg/zpkb#282), so it is
  # recorded in `provenance` below until there is one:
  #   https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz.sig
}

build {
  # ⭐ THREE SUSPICIONS ABOUT THIS BLOCK, ALL CLEARED BY READING RATHER THAN BY
  # ASSUMING. Recorded because each looked like a defect and the next reader
  # will have the same three thoughts:
  #
  # 1. The `if = "<5"` steps ASSIGN SHELL VARIABLES in what look like separate
  #    commands. If each step ran in its own shell the assignments would be
  #    lost — the shape of a stub that discards. They do not: build/runner.go
  #    :480-490 writes ONE script file and buildscript/wrapper.go:111 starts it
  #    with `set -eo pipefail`, so the whole block is one shell and the
  #    assignments persist.
  #
  # 2. `$LEGACY_ARGS` is defined only under `darwin` yet used in a step that is
  #    NOT platform-guarded. Under `set -u` that would abort a Linux build;
  #    wrapper.go:111 sets `-eo pipefail` and NOT `-u`, so it expands to empty
  #    and the step appends nothing. Harmless, and only harmless by that one
  #    missing flag.
  #
  # 3. `gnu.org/gettext = "^1"` looked unresolvable: every other recipe in the
  #    pantry constrains gettext as `*`, `0.21` or `^0.22`, all 0.x. ⛔ THE
  #    POPULATION WAS NOT THE MECHANISM. `gh api repos/autotools-mirror/gettext
  #    /tags` answers `["v1.0","v0.26","v0.25.1",…]` — gettext HAS shipped 1.0,
  #    and it is the newest tag. The constraint resolves and is ahead of the
  #    rest of the tree, not behind it. The other recipes are simply older.
  #
  # ⛔ ONE THING IS STATED THAT THE BLOCK LEFT SILENT: `--without-bash-malloc`
  # overrides bash's OWN default. configure.ac:55 is `opt_bash_malloc=yes`,
  # with per-platform exceptions at :67-71 for alpha, Cray, OSF/1, DG/UX and
  # SPARC SVR4 — none of which is a target here. So this is a deliberate
  # reversal for every platform we build, and the recipe said nothing about it.
  # It is kept, because bash's bundled allocator is the usual casualty of a
  # sovereign libc and changing it is a build experiment this recipe cannot run;
  # it is now at least visible to whoever runs that experiment.
  script = [
    {
      if  = "<5"
      run = "CFLAGS=\"$CFLAGS -Wno-incompatible-pointer-types -Wno-implicit-int\""
    },
    {
      if  = "<5"
      run = "ARGS=\"$ARGS $LEGACY_ARGS\""
    },
    {
      run = "ARGS=\"$ARGS --without-bash-malloc\""
    },
    "./configure --prefix={{ prefix }} $ARGS",
    "make --jobs {{ hw.concurrency }} install",
  ]

  env {
    CFLAGS = [
      "-DSSH_SOURCE_BASHRC",
      "-Wno-implicit-function-declaration",
    ]

    darwin {
      LDFLAGS = "$LDFLAGS -Wl,-headerpad_max_install_names"
      LEGACY_ARGS = [
        "ac_cv_func_snprintf=yes",
        "ac_cv_func_vsnprintf=yes",
        "--disable-nls",
      ]
    }
  }
}

dependencies {
  darwin = {
    "gnu.org/gettext" = "^1"
  }
}

# Makefile.in:916-918 — `install:` runs exactly two installs:
#
#   :917  $(INSTALL_PROGRAM) … $(Program) …/$(Program)   and :116 is
#                                                        `Program = bash$(EXEEXT)`
#   :918  $(INSTALL_SCRIPT)  … bashbug   …/bashbug
#
# Two names, and notably NOT `sh`: bash's own Makefile installs no such alias,
# whatever a distribution may symlink afterwards. `:989-990`'s `uninstall`
# removes the same two, which is the cross-check.
provides = [
  "bin/bash",
  "bin/bashbug",
]

test {
  script = [
    "bash --version | grep {{version.raw}}",

    # ⛔ THE LESSON FROM gnu.org/grep, APPLIED PROPHYLACTICALLY. There the
    # recipe passed `-with-packager=tea` and `--version` printed `Packaged by
    # tea` one line below what the test asserted. bash's --version carries no
    # packager line today and this recipe passes no such flag; the assertion is
    # here so that adding one cannot go unnoticed.
    "test -z \"$(bash --version | grep -i 'packaged by')\"",

    # The shell actually runs, in the two modes a packaged bash is used in:
    # -c for a command, and a script on stdin.
    "test \"$(bash -c 'echo ok')\" = ok",
    "test \"$(printf 'echo %s\\n' hi | bash)\" = hi",

    # -DSSH_SOURCE_BASHRC is in CFLAGS and changes behaviour rather than
    # performance, so it is asserted: with it, a non-interactive shell started
    # under SSH_CLIENT sources ~/.bashrc. Checked by its OBSERVABLE effect
    # rather than by grepping the binary.
    {
      run = "HOME=$PWD SSH_CLIENT='1 2 3' bash -c 'exit $SOURCED'"
      fixture = {
        content = <<EOT
SOURCED=0
EOT
        extname = "bashrc"
      }
    },

    # The second installed name is a script, not a binary, and it is the one a
    # `provides` list is most likely to be wrong about.
    "test -x {{prefix}}/bin/bashbug",
  ]
}

provenance {
  read = [
    "Makefile.in",  # :116 Program = bash; :916-918 the two installs; :989-990 uninstall
    "configure.ac", # :55 opt_bash_malloc=yes by default, :67-71 its exceptions
    "COPYING",      # the GPLv3 text that ships
    "shell.c",      # :9 "either version 3 of the License, or"
  ]

  consulted = [
    "pkgxdev/pantry projects/gnu.org/bash/package.yml",
  ]

  note = <<EOT
This began as a build block and a darwin dependency, with no versions and no
distributable, so it resolved only because upstream's recipe sat underneath it.

⭐ UNLIKE THE TWO RECIPES BEFORE IT, THE INHERITED BLOCK WAS SOUND. Three things
in it looked wrong and the source cleared all three: the shell-variable
assignments across script steps (one script, one shell), the darwin-only
`$LEGACY_ARGS` used unguarded (no `set -u`), and `gettext = "^1"` against a
pantry that elsewhere says 0.x (gettext has shipped v1.0, and it is the newest
tag).

The third is the one worth remembering. The argument "every other recipe says
0.x, so ^1 cannot resolve" is a POPULATION argument, and it was wrong — the
other recipes are older, not evidence about the project. The same kind of
argument was right an hour earlier for gnu.org/grep's self-dependency, where
the population WAS the mechanism (go-zpkg/base-toolchain:80 puts a grep in every
sandbox). A population tells you what others do; only the thing itself tells you
what is true of it.

What the block left silent and now states: `--without-bash-malloc` reverses
bash's own default (configure.ac:55).

The digest is signature-verified, by Chet Ramey — a DIFFERENT key from the one
signing gnu.org/gzip and gnu.org/grep. The two limits on the warrant are the
same and restated here because a recipe should be readable alone: the key came
from a file served by the SAME HOST as the tarball, which is continuity and not
independence; and that keyring holds every GNU maintainer's key, so the
fingerprint had to be named — here, after walking 143 primary keys.
EOT
}
