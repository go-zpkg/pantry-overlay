# github.com/hynek/hatch-fancy-pypi-readme — hatch-fancy-pypi-readme: the Hatch
# metadata hook that assembles a PyPI readme from fragments.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a build
# dependency of virtualenv.pypa.io, filelock, platformdirs and python-discovery
# (`requires = ["hatch-fancy-pypi-readme>=25.1", ...]`).

summary = "hatch-fancy-pypi-readme: fancy PyPI READMEs with Hatch"

# pyproject.toml:13 `license = "MIT"`; the sdist carries LICENSE.txt.
license = "MIT"

versions {
  github = "hynek/hatch-fancy-pypi-readme/tags"
}

dependencies = {
  "python.org"        = "^3"
  "pypa.io/hatchling" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/h/hatch-fancy-pypi-readme/hatch_fancy_pypi_readme-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/hatch-fancy-pypi-readme/) records for the sdist.
  sha256 = {
    "25.1.0" = "9c58ed3dff90d51f43414ce37009ad1d5b0f08ffc9fc216998a06380f01c0045"
  }
}

build {
  dependencies = {
    "pypa.io/hatchling" = "*"
  }

  script = [
    {
      # pyproject.toml:2-3 requires ["hatchling"], backend hatchling.build. The
      # version is static (pyproject.toml:8).
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
import importlib.metadata, hatch_fancy_pypi_readme
assert importlib.metadata.version("hatch-fancy-pypi-readme") == "{{version.raw}}"
print(hatch_fancy_pypi_readme.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "hatch_fancy_pypi_readme was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :2-3 build-system hatchling, hatchling.build; :8 static version; :10 requires-python >=3.8; :13 license MIT; :28-31 dependencies
    "LICENSE.txt",    # the MIT text
  ]

  consulted = [
    "pypi.org/simple/hatch-fancy-pypi-readme/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

tomli is declared only below Python 3.11 (pyproject.toml:30), so it is not a
dependency of an interpreter this tree ships. The module name
`hatch_fancy_pypi_readme` in the probe is the sdist's import name, taken from
the distribution name; it was not read from the tree.
EOT
}
