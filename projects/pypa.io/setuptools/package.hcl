# pypa.io/setuptools — setuptools, the Python build backend (`setuptools.build_meta`)
# and `setup.py` library. python-pillow.org's pyproject.toml:2-6 requires
# `setuptools>=77` and names `build-backend = "backend"`, whose first line
# imports `setuptools.build_meta` (_custom_build/backend.py:5), and python.org
# (3.15) ships pip through ensurepip and NO setuptools. python-pillow.org
# (go-zpkg/recipes#122 step 5) is why this recipe exists.
#
# ⛔ WRITTEN FROM SETUPTOOLS'S OWN FILES (go-zpkg/packages#431), at 84.2.1.
#
# ⭐ WHAT WRITING IT FOUND: setuptools builds itself. pyproject.toml:1-9 has
# `requires = []` (every line commented out) and `backend-path = ["."]`, so with
# build isolation OFF there is nothing to fetch from an index: pip imports the
# backend from the source tree and the vendored libraries under
# setuptools/_vendor come with it. Isolation ON would download a build
# environment, which an offline factory cannot do, so it is named off below.

summary = "setuptools: the Python build backend and setup.py library, built from its own source"

# pyproject.toml:30 `license = "MIT"`. The vendored libraries under
# setuptools/_vendor carry their own licences and ship in the same artifact.
license = "MIT"

versions {
  github = "pypa/setuptools/tags"
  strip  = ["/^v/"]
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  # The sdist PyPI serves: it carries setup.py, setup.cfg and PKG-INFO, which
  # the GitHub archive of the tag does not.
  url              = "https://files.pythonhosted.org/packages/source/s/setuptools/setuptools-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1230289 bytes. The digest is the one PyPI's own JSON states for this file
  # (pypi.org/pypi/setuptools/json) and the bytes fetched from
  # files.pythonhosted.org hash to it.
  #
  # ⚠ NOT SIGNED, and says so rather than cite something it did not read:
  # PyPI answers 404 for this file's PEP 740 attestation. The repository's tag
  # v84.2.1 is an annotated tag object, which was not verified here.
  sha256 = {
    "84.2.1" = "3ff8b3b5492a0aa66960f4419365a86b84e013070d4313e4d4a6894f5d64d6bc"
  }
}

build {
  script = [
    {
      # ⛔ --no-build-isolation, --no-index AND --no-deps, all three named. The
      # first is why this works at all (see above); the other two refuse a
      # network fetch if a dependency ever appears.
      run = <<EOT
set -eu
python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
EOT
    },
  ]
}

runtime {
  env = {
    # Chained, so a caller's own PYTHONPATH survives.
    PYTHONPATH = "{{prefix}}/lib/python{{deps.python.org.version.major}}.{{deps.python.org.version.minor}}/site-packages:$PYTHONPATH"
  }
}

test {
  script = [
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
SITE="{{prefix}}/lib/python$PYVER/site-packages"
cat > probe.py <<'PYEOF'
import setuptools, setuptools.build_meta
assert setuptools.__version__ == "{{version.raw}}", setuptools.__version__
print(setuptools.__file__)
PYEOF
PYTHONPATH="$SITE" python3 probe.py > where.txt
grep -q "{{prefix}}" where.txt || { echo "setuptools was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },

    # ⛔ THE BACKEND HAS TO MAKE A WHEEL, which is what its only consumer asks of
    # it. A one-module project, built the way python-pillow.org's recipe builds:
    # no isolation, no index. A backend that imports and cannot build passes the
    # probe above.
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
mkdir -p proj && cd proj
cat > pyproject.toml <<'TOMLEOF'
[build-system]
requires = ["setuptools>=77"]
build-backend = "setuptools.build_meta"

[project]
name = "zprobe"
version = "1.2.3"
TOMLEOF
echo 'VALUE = 42' > zprobe.py
cat > setup.cfg <<'CFGEOF'
[options]
py_modules = zprobe
CFGEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 -m pip wheel --no-build-isolation --no-index --no-deps -w dist .
test -s dist/zprobe-1.2.3-py3-none-any.whl
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-9 `requires = []` and `backend-path = ["."]`, the self-hosting that makes --no-build-isolation sufficient; :13 version; :29 requires-python >=3.10; :30 `license = "MIT"`
    "PKG-INFO",       # that the sdist is the project's own build of the tree
  ]

  consulted = [
    # Read for facts only: the project's name in the pantry, pypa.io/setuptools.
    "pkgxdev/pantry projects/pypa.io/setuptools",
    "pypi.org/pypi/setuptools/json",
  ]

  note = <<EOT
⭐ SETUPTOOLS BUILDS ITSELF. pyproject.toml:1-9 asks for no build-time package
(each line of `requires` is commented out) and points the backend at the
source tree (`backend-path = ["."]`), so --no-build-isolation is complete: no
build environment is fetched from an index, and the libraries it needs are the
ones it vendors under setuptools/_vendor.

⛔ NOT SIGNED. PyPI answers 404 for this file's attestation (PEP 740). The
digest is PyPI's own statement and matches the bytes fetched.

⛔ NOT BUILT BY THE FACTORY. The install command and the wheel step of the test
were run on darwin/arm64 with a host CPython 3.12.12 (pip 25.3): setuptools
84.2.1 built from this sdist, installed under a scratch --prefix, and a
one-module project then built a wheel with it (--no-build-isolation
--no-index). Not run: python.org 3.15 from this tree, nor the factory sandbox.
EOT
}
