# mesonbuild.com — Meson, the build system, written in Python. It reads
# meson.build and writes build.ninja; ninja does the building.
#
# ⛔ WRITTEN FROM MESON'S OWN FILES (go-zpkg/packages#440), at 1.12.1. This
# recipe did not exist: systemd.io, and any other meson project, had no way to
# get a `meson` command from this tree.

summary = "Meson: a fast, Python-based build system that generates ninja files"

# PKG-INFO:8 `License: Apache License, Version 2.0`; COPYING is the Apache 2.0 text.
license = "Apache-2.0"

versions {
  github = "mesonbuild/meson"
}

dependencies = {
  # PKG-INFO:27 `Requires-Python: >=3.10`.
  "python.org" = "^3"
  # Meson only writes build.ninja; `meson compile` and `meson setup` then
  # call ninja, found on PATH. setup.cfg:45-46 offers it as the optional
  # `ninja` extra (a PyPI wheel), which an offline build cannot use, so the
  # tree's own ninja is the dependency.
  "ninja-build.org" = "*"
}

distributable {
  # THE STORED RELEASE ASSET: a setuptools sdist (it carries setup.py,
  # setup.cfg and PKG-INFO), published beside a detached signature
  # meson-1.12.1.tar.gz.asc.
  url              = "https://github.com/mesonbuild/meson/releases/download/{{version.raw}}/meson-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2524665 bytes, fetched with `zpkb sourcepin`; a second, independent fetch
  # (curl, then shasum -a 256) gave the same digest. 1.12.1 is the newest
  # release `zpkb versions` resolves.
  #
  # ⚠ THE .asc IS NOT VERIFIED: no key for it was obtained from anything but a
  # keyserver, which this tree never uses, so the signature is not the witness.
  sha256 = {
    "1.12.1" = "ab0a6ca09f8ef70c564c8241fb5a23957886a0b53fb58412b5e07eaf07dba743"
  }
}

build {
  dependencies = {
    # pyproject.toml:2 `requires = ["setuptools>=42"]`. With build isolation OFF
    # (below) the backend must already be installed.
    "pypa.io/setuptools" = "*"
  }

  script = [
    {
      # ⛔ --no-build-isolation, --no-index AND --no-deps, as in pypa.io/setuptools:
      # isolation would download a build environment, and the extras
      # (ninja, progress, typing; PKG-INFO:30-35) are not wanted.
      run = <<EOT
set -eu
python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
EOT
    },
  ]
}

# setup.cfg:40-42 console_scripts `meson = mesonbuild.mesonmain:main`.
provides = [
  "bin/meson",
]

runtime {
  env = {
    # Chained, so a caller's own PYTHONPATH survives.
    PYTHONPATH = "{{prefix}}/lib/python{{deps.python.org.version.major}}.{{deps.python.org.version.minor}}/site-packages:$PYTHONPATH"
  }
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test \"$(meson --version)\" = \"{{version.raw}}\"",
    # A real project: configure, compile and run one C program, which is what
    # every consumer asks of meson. Needs a C compiler and ninja.
    {
      run = <<EOT
set -eu
mkdir -p proj && cd proj
cat > meson.build <<'MESONEOF'
project('zprobe', 'c', version : '1.0')
executable('zprobe', 'main.c')
MESONEOF
cat > main.c <<'CEOF'
#include <stdio.h>
int main(void) { puts("meson built this"); return 0; }
CEOF
meson setup build
meson compile -C build
./build/zprobe
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-3 build-system requires setuptools>=42, backend setuptools.build_meta
    "PKG-INFO",       # :3 Version 1.12.1; :8 License Apache 2.0; :27 Requires-Python >=3.10; :30-35 the extras
    "setup.cfg",      # :3 version from mesonbuild.coredata.version; :38 python_requires; :40-42 console_scripts meson; :44-46 ninja extra
  ]

  consulted = [
    "pkgxdev/pantry projects/mesonbuild.com/package.yml",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the build and test blocks have
not been run, on either platform. The install command is the one
pypa.io/setuptools runs (measured there on darwin/arm64), applied to this sdist.

⛔ NOT SIGNED. The release carries meson-1.12.1.tar.gz.asc, but the key was not
fetched (no keyserver), so the digest is witnessed by a second independent fetch.

meson needs ninja at run time but does not link it: the dependency is on PATH
only. The test's C compiler is gnu.org/gcc, named in the test dependencies.
EOT
}
