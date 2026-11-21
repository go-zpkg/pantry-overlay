# github.com/package-url/packageurl-python — packageurl-python: a Python parser
# and builder for package URLs (purl).
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of python-sbom (`packageurl-python>=0.11.1`, its pyproject.toml:8 and :58).

summary = "packageurl-python: parse and build package URLs (purl)"

# setup.cfg:4 `license = MIT`; the sdist carries mit.LICENSE.
license = "MIT"

versions {
  github = "package-url/packageurl-python/tags"
  strip  = "/^v/"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/packageurl-python/packageurl_python-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/packageurl-python/) records for the sdist.
  sha256 = {
    "0.17.6" = "1252ce3a102372ca6f86eb968e16f9014c4ba511c5c37d95a7f023e2ca6e5c25"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools" = "*"
  }

  script = [
    {
      # The sdist has no pyproject.toml: setup.py:9 calls setuptools.setup() and
      # setup.cfg holds the metadata, so pip uses its setuptools fallback
      # backend, which --no-build-isolation takes from the build dependencies.
      # setup.cfg:43 `install_requires =` is empty.
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
import importlib.metadata, packageurl
assert importlib.metadata.version("packageurl-python") == "{{version.raw}}"
assert packageurl.PackageURL.from_string("pkg:pypi/django@1.11.1").name == "django"
print(packageurl.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "packageurl was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "setup.py",  # :9 setuptools.setup() with no arguments
    "setup.cfg", # :3 version; :4 license MIT; :38 python_requires >=3.8; :39-40 src layout; :43 install_requires empty
  ]

  consulted = [
    "pypi.org/simple/packageurl-python/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The sdist has no pyproject.toml, so no build requirement is declared by the
project; setuptools is supplied here because setup.py needs it. `setup.cfg`
lists license files (AUTHORS.rst among them) that the sdist does not carry.
EOT
}
