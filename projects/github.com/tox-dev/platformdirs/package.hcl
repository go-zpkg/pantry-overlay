# github.com/tox-dev/platformdirs — platformdirs: determine platform-specific
# directories (user data, cache, config).
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of virtualenv.pypa.io (`platformdirs<5,>=4.4`, its pyproject.toml:59).

summary = "platformdirs: determine appropriate platform-specific directories"

# pyproject.toml:22 `license = "MIT"`; the sdist carries LICENSE.
license = "MIT"

versions {
  github = "tox-dev/platformdirs/tags"
}

dependencies = {
  # pyproject.toml:29 `requires-python = ">=3.11"`.
  "python.org" = "^3.11"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/platformdirs/platformdirs-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/platformdirs/) records for the sdist.
  sha256 = {
    "4.14.8" = "96893d686e84e9e6f358a9ea41a8de544df66dbf2ba6cda250e7dc73acf85b9b"
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
      # pyproject.toml:3-8 requires hatch-fancy-pypi-readme, hatch-vcs,
      # hatchling>=1.29 and python-sbom[hatch], backend hatchling.build;
      # :136-137 enable the vcs and python-sbom build hooks. The version is
      # VCS-derived (:133) and the sdist is not a checkout, so it is pinned from
      # the resolved one. The sdist omits the README.md that the readme hook's
      # fragment names (:135), so an empty one stands in and the wheel's long
      # description is empty.
      run = <<EOT
set -eu
test -e README.md || : > README.md
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
import importlib.metadata, platformdirs
assert importlib.metadata.version("platformdirs") == "{{version.raw}}"
print(platformdirs.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "platformdirs was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :3-8 build-system; :22 license MIT; :29 requires-python >=3.11; :45-48 dynamic readme, version (no dependencies table); :132-137 Hatch config
    "LICENSE",        # present in the sdist
  ]

  consulted = [
    "pypi.org/simple/platformdirs/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The empty README.md in the build script is a workaround for an sdist that does
not carry the file its readme hook reads. That the build fails without it has
not been measured; the workaround costs only the long description.
EOT
}
