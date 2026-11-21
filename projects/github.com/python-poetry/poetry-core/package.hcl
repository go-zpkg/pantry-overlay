# github.com/python-poetry/poetry-core — poetry-core: the PEP 517 build backend
# of Poetry.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as the build
# backend of tomlkit (`requires = ["poetry-core>=2.2.0"]`, its
# pyproject.toml:72), which hatchling needs, and of pkgconfig, which borgbackup's
# build-system table lists.

summary = "poetry-core: the PEP 517 build backend of Poetry"

# pyproject.toml:17 `license = "MIT"`; the sdist carries LICENSE.
license = "MIT"

versions {
  github = "python-poetry/poetry-core/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/poetry-core/poetry_core-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/poetry-core/) records for the sdist.
  sha256 = {
    "2.5.0" = "81d04c9253b19d0604718268d781867c8f7b2128e5b25bbf1e84141eec6b89c4"
  }
}

build {
  script = [
    {
      # pyproject.toml:161-163 `requires = []`, backend
      # poetry.core.masonry.api, backend-path ["src"]: poetry-core builds itself
      # from the tree, so --no-build-isolation is complete.
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
import importlib.metadata, poetry.core, poetry.core.masonry.api
assert importlib.metadata.version("poetry-core") == "{{version.raw}}"
print(poetry.core.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "poetry.core was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :17 license MIT; :18 requires-python >=3.10,<4.0; :160-163 requires [], backend, backend-path ["src"]
    "LICENSE",        # the MIT text
  ]

  consulted = [
    "pypi.org/simple/poetry-core/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

poetry-core is a namespace-style package (`poetry.core`), so the probe imports
`poetry.core`, not `poetry`.
EOT
}
