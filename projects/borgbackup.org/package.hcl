# borgbackup.org — BorgBackup: a deduplicating, compressing, encrypting backup
# program.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), replacing a
# fragment that carried only a build block (zpkvenv commands, five library
# prefixes) and no source, no version, no license.
#
# ⛔ 1.4.5, NOT 2.0.0b25. PyPI's newest sdist is 2.0.0b25, a beta of the 2.x
# line, which is a different program (it needs borgstore and borghash, and its
# repositories are not compatible). The 1.4 line is the stable one, so it is
# the one this recipe carries and the one `versions` is held to.

summary = "BorgBackup: deduplicating, compressing, authenticated-encrypted backups"

# pyproject.toml:30 `license = "BSD-3-Clause"`, :31 license-files LICENSE and
# AUTHORS; both ship in the sdist.
license = "BSD-3-Clause"

versions {
  github = "borgbackup/borg/tags"
  strip  = "/^v/"

  # The 2.x line, betas and release candidates, which are another program.
  ignore = [
    "/^2\\./",
    "/(a|b|rc)\\d+$/",
  ]
}

# pyproject.toml:9 requires-python >=3.10; :32-39 dependencies msgpack
# `>=1.0.3, <=1.2.1` and packaging. The five libraries are linked by the
# extensions (setup.py:130-161) and found through the BORG_*_PREFIX variables
# below, so they are run-time dependencies too. libacl is Linux's
# (setup.py:156-161 asks pkg-config for it on Linux and links -lacl elsewhere,
# which was not followed up), as the fragment this replaces had it.
dependencies = {
  "python.org"                         = "^3.10"
  "github.com/msgpack/msgpack-python"  = "^1.0.3"
  "pypa.io/packaging"                  = "*"
  "openssl.org"                        = "^3"
  "lz4.org"                            = "*"
  "facebook.com/zstd"                  = "*"
  "github.com/Cyan4973/xxHash"         = "*"
  linux = {
    "savannah.nongnu.org/acl" = "*"
  }
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/b/borgbackup/borgbackup-{{version.raw}}.tar.gz"
  strip-components = 1

  # 4034652 bytes, recorded with `zpkb sourcepin --version 1.4.5`; PyPI's simple
  # index (pypi.org/simple/borgbackup/) was not read for this release, since its
  # newest six entries are all 2.0.0 betas.
  sha256 = {
    "1.4.5" = "4f9a5fe584c504b15485841236750dea16aa7cd2ddbc4a594e9d2ce5c49c4508"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools"           = "*"
    "pypa.io/setuptools-scm"       = "*"
    "github.com/matze/pkgconfig"   = "*"
    "pypa.io/packaging"            = "*"
    "freedesktop.org/pkg-config"   = "*"
  }

  # setup.py:112-128 uses `<prefix>/include` and `<prefix>/lib` of each
  # BORG_*_PREFIX when it is set, and only otherwise asks pkg-config; so the
  # tree's own libraries are named, and a host's are never picked up.
  # BORG_OPENSSL_PREFIX is read at :134. BORG_LIBACL_PREFIX is read only on
  # Linux (:156-159).
  env = {
    BORG_OPENSSL_PREFIX   = "{{deps.openssl.org.prefix}}"
    BORG_LIBLZ4_PREFIX    = "{{deps.lz4.org.prefix}}"
    BORG_LIBZSTD_PREFIX   = "{{deps.facebook.com/zstd.prefix}}"
    BORG_LIBXXHASH_PREFIX = "{{deps.github.com/Cyan4973/xxHash.prefix}}"
    BORG_LIBACL_PREFIX    = "{{deps.savannah.nongnu.org/acl.prefix}}"
  }

  script = [
    {
      # pyproject.toml:75 requires setuptools>=78.1.1, setuptools_scm>=8, wheel,
      # pkgconfig and Cython>=3.0.3; backend setuptools.build_meta. Cython is not
      # supplied: the sdist ships the generated .c beside every .pyx
      # (setup.py:62-89 raises only when one is missing), and `wheel` is not
      # needed by a setuptools that builds wheels itself. The version comes from
      # setuptools_scm (:78-83) and the sdist is not a checkout, so it is pinned
      # from the resolved one.
      run = <<EOT
set -eu
SETUPTOOLS_SCM_PRETEND_VERSION="{{version.raw}}" python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
EOT
    },
  ]
}

# pyproject.toml:58-60: `borg` and `borgfs`, both borg.archiver:main.
provides = [
  "bin/borg",
  "bin/borgfs",
]

runtime {
  env = {
    PYTHONPATH = "{{prefix}}/lib/python{{deps.python.org.version.major}}.{{deps.python.org.version.minor}}/site-packages:$PYTHONPATH"
  }
}

test {
  script = [
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
export PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages"
"{{prefix}}/bin/borg" --version > version.txt
grep "{{version.raw}}" version.txt >/dev/null || { echo "borg --version did not report {{version.raw}}" >&2; cat version.txt >&2; exit 1; }
EOT
    },

    # A round trip, because "the program starts" is not "the extensions work":
    # init, create, extract and compare exercise the crypto, compression and
    # chunker extensions.
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
export PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages"
mkdir data out
printf 'the quick brown fox jumps over the lazy dog\n' > data/f.txt
"{{prefix}}/bin/borg" init --encryption=none repo
"{{prefix}}/bin/borg" create --compression zstd repo::a data
(cd out && "{{prefix}}/bin/borg" extract ../repo::a)
cmp data/f.txt out/data/f.txt
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml",   # :9 requires-python; :30-31 license; :32-39 dependencies; :58-60 scripts; :75 build requires; :78-83 setuptools_scm
    "setup.py",         # :36-40 the BORG_*_PREFIX contract; :62-89 Cython optional when the .c files ship; :112-161 the library lookups
    "LICENSE",          # present in the sdist
    "AUTHORS",          # present in the sdist
  ]

  consulted = [
    "pypi.org/simple/borgbackup/", # the list of releases: 2.0.0b25 newest, the 1.4 line below it
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is the bytes `zpkb sourcepin` fetched; no second
witness was read for this release.

The recipe this replaces ran `zpkvenv stage`, pip-installed
requirements.d/development.txt and sealed a venv; none of that is in the sdist's
own build, which needs only the backend and the five libraries. The dependencies
it named are kept, with libacl for Linux only, and msgpack, packaging,
pkgconfig and setuptools_scm are new. `TMPDIR = $(mktemp -d)` is dropped.

Skipped on purpose: Cython (the sdist ships generated C), borghash and
borgstore (2.x only), libb2 (not used by 1.4.5).

Unmeasured, and the main risks: that the extension modules find the tree's
shared libraries at run time (they are linked with -L only; no RUNPATH is set
by this recipe), that SETUPTOOLS_SCM_PRETEND_VERSION is honoured, and what
setup.py:163-165 does on darwin (it links -lacl there). `zpkb versions` resolves
1.4.5, 1.4.4, 1.4.3 newest first, so the ignore list does hold the 2.x line off.
EOT
}
