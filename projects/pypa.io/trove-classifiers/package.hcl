# pypa.io/trove-classifiers — trove-classifiers: the canonical list of the
# classifiers PyPI accepts.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of hatchling, which virtualenv's build backend needs.

summary = "trove-classifiers: the canonical source of PyPI classifiers"

# setup.py's classifiers list "License :: OSI Approved :: Apache Software
# License"; the sdist carries LICENSE (Apache-2.0).
license = "Apache-2.0"

versions {
  github = "pypa/trove-classifiers/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/t/trove-classifiers/trove_classifiers-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/trove-classifiers/) records for the sdist.
  sha256 = {
    "2026.9.21.13" = "0a9ebc8d4e2f3e8a22848c5258033035bec17a3012ac3fea16dbaa764489eb71"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools"   = "*"
    "github.com/di/calver" = "*"
  }

  script = [
    {
      # pyproject.toml:2-3 requires ["setuptools", "calver"], backend
      # setuptools.build_meta; setup.py:31-32 `use_calver="%Y.%m.%d.%H"` with
      # setup_requires calver. calver reads the version from the sdist's PKG-INFO,
      # so the clock is not used. The project declares no dependencies.
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
import importlib.metadata, trove_classifiers
assert importlib.metadata.version("trove-classifiers") == "{{version.raw}}"
assert "License :: OSI Approved :: MIT License" in trove_classifiers.classifiers
print(trove_classifiers.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "trove_classifiers was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :2-3 build-system setuptools + calver, backend setuptools.build_meta
    "setup.py",       # :23 Apache classifier; :31-32 use_calver / setup_requires calver; :34 console script
    "LICENSE",        # the Apache-2.0 text
  ]

  consulted = [
    "pypi.org/simple/trove-classifiers/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The version is a calendar version, so `versions` is the GitHub tag list of
pypa/trove-classifiers, whose tags are the sdist versions.
EOT
}
