# github.com/cpburnz/python-pathspec — pathspec: gitignore-style pattern
# matching of file paths.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of hatchling (`pathspec>=0.10.1`, its pyproject.toml:40).

summary = "pathspec: gitignore-style pattern matching of file paths for Python"

# pyproject.toml:29 `license = {text = "MPL 2.0"}`; the sdist carries LICENSE.
license = "MPL-2.0"

versions {
  github = "cpburnz/python-pathspec/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/pathspec/pathspec-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/pathspec/) records for the sdist.
  sha256 = {
    "1.1.1" = "17db5ecd524104a120e173814c90367a96a98d07c45b2e10c2f3919fff91bf5a"
  }
}

build {
  dependencies = {
    "pypa.io/flit-core" = "*"
  }

  script = [
    {
      # pyproject.toml:3-4 requires ["flit_core >=3.2,<5"], backend
      # flit_core.buildapi (pypa.io/flit-core supplies a 3.x). The project
      # declares no run-time dependencies.
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
import importlib.metadata, pathspec
assert importlib.metadata.version("pathspec") == "{{version.raw}}"
spec = pathspec.PathSpec.from_lines("gitwildmatch", ["*.pyc", "build/"])
assert spec.match_file("a/b.pyc") and not spec.match_file("a/b.py")
print(pathspec.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "pathspec was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :3-4 build-system flit_core >=3.2,<5; :29 license MPL 2.0; :32 requires-python >=3.9
    "LICENSE",        # the MPL-2.0 text
  ]

  consulted = [
    "pypi.org/simple/pathspec/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The probe uses the "gitwildmatch" pattern factory name, which pathspec 1.x
still accepts; if the build is ever run and 1.x rejects it, the probe is wrong,
not the package.
EOT
}
