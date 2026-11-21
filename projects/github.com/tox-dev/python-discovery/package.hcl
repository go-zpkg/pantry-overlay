# github.com/tox-dev/python-discovery — python-discovery: Python interpreter
# discovery.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of virtualenv.pypa.io (`python-discovery>=1.6.1`, its pyproject.toml:60).

summary = "python-discovery: Python interpreter discovery"

# pyproject.toml:20 `license = "MIT"`; the sdist carries LICENSE.
license = "MIT"

versions {
  github = "tox-dev/python-discovery/tags"
}

dependencies = {
  "python.org"                    = "^3"
  "github.com/tox-dev/filelock"   = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/python-discovery/python_discovery-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/python-discovery/) records for the sdist.
  sha256 = {
    "1.9.6" = "383aa67858d73a9585a843a37a4383c6be98e4d86a981a031328e393a6eb2632"
  }
}

build {
  dependencies = {
    "pypa.io/hatchling"                        = "*"
    "github.com/ofek/hatch-vcs"                = "*"
    "github.com/hynek/hatch-fancy-pypi-readme" = "*"
    "github.com/tox-dev/python-sbom"           = "*"
  }

  script = [
    {
      # pyproject.toml:3-9 requires hatch-fancy-pypi-readme, hatch-vcs, hatchling
      # and python-sbom[hatch] (the latter on Python 3.11 and later), backend
      # hatchling.build; :108 names hatch_build.py as a custom build hook, which
      # imports python_sbom.hatch on Python 3.11 and later. The version is
      # VCS-derived (:105) and the sdist is not a checkout, so it is pinned from
      # the resolved one. The sdist carries README.md, so no stand-in is made.
      run = <<EOT
set -eu
SETUPTOOLS_SCM_PRETEND_VERSION="{{version.raw}}" python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
EOT
    },
  ]
}

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
cat > probe.py <<'PYEOF'
import importlib.metadata, python_discovery
assert importlib.metadata.version("python-discovery") == "{{version.raw}}"
print(python_discovery.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "python_discovery was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :3-9 build-system; :20 license MIT; :25 requires-python >=3.9; :44-50 dynamic readme, version, dependencies; :104-108 Hatch config
    "hatch_build.py", # imports python_sbom.hatch on Python 3.11 and later
    "LICENSE",        # present in the sdist
  ]

  consulted = [
    "pypi.org/simple/python-discovery/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

python-discovery itself declares Python >=3.9, but its filelock dependency
needs 3.11 or later, so in this tree it is only usable there.
EOT
}
