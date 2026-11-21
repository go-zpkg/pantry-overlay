# pypa.io/packaging — packaging: version, specifier, marker and wheel-tag
# utilities for Python packaging tools.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of hatchling, setuptools-scm, vcs-versioning, wheel, virtualenv and borgbackup.

summary = "packaging: core utilities for Python packages (versions, specifiers, markers)"

# pyproject.toml:10 `license = "Apache-2.0 OR BSD-2-Clause"`; the sdist carries
# LICENSE, LICENSE.APACHE and LICENSE.BSD.
license = "Apache-2.0 OR BSD-2-Clause"

versions {
  github = "pypa/packaging/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/packaging/packaging-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/packaging/) records for the sdist.
  sha256 = {
    "26.3" = "94edc256424af38762eb31306eed28beb9f0efc50a8837492c9d6fd6004aed79"
  }
}

build {
  dependencies = {
    "pypa.io/flit-core" = "*"
  }

  script = [
    {
      # pyproject.toml:1-3 requires ["flit_core >=3.12"], backend
      # flit_core.buildapi, supplied by the build dependency above; :32
      # `dependencies = []`, so --no-deps loses nothing.
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
import packaging
from packaging.version import Version
from packaging.specifiers import SpecifierSet
assert packaging.__version__ == "{{version.raw}}", packaging.__version__
assert Version("1.10") > Version("1.9")
assert "1.5" in SpecifierSet(">=1.0,<2")
print(packaging.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "packaging was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-3 build-system flit_core >=3.12 / flit_core.buildapi; :10 license; :12 requires-python >=3.9; :32 dependencies = []
    "LICENSE",        # the dual-license notice, pointing at LICENSE.APACHE and LICENSE.BSD
  ]

  consulted = [
    "pypi.org/simple/packaging/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform. The install command is the one
pypa.io/flit-core and palletsprojects.com/jinja2 use.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

flit-core is held below 4 by its own recipe, which satisfies ">=3.12" here.
EOT
}
