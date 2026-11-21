# pypa.io/hatchling — hatchling: the extensible PEP 517 build backend of Hatch.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as the build
# backend of virtualenv.pypa.io and of hatch-vcs.

summary = "hatchling: modern, extensible Python build backend"

# pyproject.toml:11 `license = "MIT"`; the sdist carries LICENSE.txt.
license = "MIT"

versions {
  # The repository tags two packages: Hatch itself (`hatch-v…`) and this one
  # (`hatchling-v1.33.0`). Keep this one's, and drop the other's.
  github = "pypa/hatch/tags"
  strip  = "/^hatchling-v/"
  ignore = ["/^hatch-v/"]
}

dependencies = {
  "python.org"                     = "^3"
  "pypa.io/packaging"              = "*"
  "github.com/cpburnz/python-pathspec" = "*"
  "github.com/pytest-dev/pluggy"   = "*"
  "github.com/python-poetry/tomlkit" = "*"
  "pypa.io/trove-classifiers"      = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/h/hatchling/hatchling-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/hatchling/) records for the sdist.
  sha256 = {
    "1.33.0" = "4c422bd4d554fcff5de5b73e9596f85e41e9f97f7e553d8f7595ecb31a627bef"
  }
}

build {
  script = [
    {
      # pyproject.toml:1-4 `requires = []`, backend hatchling.ouroboros,
      # backend-path ["src"]: hatchling builds itself from the tree, so
      # --no-build-isolation is complete and no build dependency is needed. The
      # version is dynamic (pyproject.toml:8) and read from the sdist's own
      # source.
      run = <<EOT
set -eu
python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
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
import importlib.metadata, hatchling.build
assert importlib.metadata.version("hatchling") == "{{version.raw}}"
print(hatchling.build.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "hatchling was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-4 requires [], backend hatchling.ouroboros, backend-path ["src"]; :8 dynamic version; :11 license MIT; :13 requires-python >=3.10; :38-45 dependencies
    "LICENSE.txt",    # the MIT text
  ]

  consulted = [
    "pypi.org/simple/hatchling/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

tomli is declared only below Python 3.11 (pyproject.toml:43), so it is not a
dependency of an interpreter this tree ships. The probe imports hatchling.build
without calling the backend, so it does not exercise the plugins.
EOT
}
