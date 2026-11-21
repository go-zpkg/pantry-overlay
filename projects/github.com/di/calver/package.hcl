# github.com/di/calver — calver: the setuptools extension that gives a package a
# calendar version.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440). trove-classifiers
# lists it in `setup_requires` (setup.py) and in [build-system] (pyproject.toml:2),
# and hatchling needs trove-classifiers.

summary = "calver: setuptools extension for CalVer package versions"

# pyproject.toml:11 `license = "Apache-2.0"`; the sdist carries LICENSE.
license = "Apache-2.0"

versions {
  github = "di/calver/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/c/calver/calver-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/calver/) records for the sdist.
  sha256 = {
    "2025.10.20" = "c98b376c2424642224d456b2f70c51402343e008c63d204634665e1a2a2835f5"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools" = "*"
  }

  script = [
    {
      # pyproject.toml:2-3 requires ["setuptools>=77.0.1"], backend
      # setuptools.build_meta. setup.py takes the version from the sdist's
      # PKG-INFO (src/calver/integration.py `pkginfo_version`), so no clock or
      # VCS is read.
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
import importlib.metadata, calver
assert importlib.metadata.version("calver") == "{{version.raw}}"
print(calver.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "calver was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml",             # :2-3 build-system setuptools>=77.0.1; :10 requires-python >=3.9; :11 license Apache-2.0
    "setup.py",                   # the version comes from calver.integration._get_version(True)
    "src/calver/integration.py",  # :14-24 pkginfo_version; :31-33 a PKG-INFO Version wins over the build date
    "LICENSE",                    # the Apache-2.0 text
  ]

  consulted = [
    "pypi.org/simple/calver/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.
EOT
}
