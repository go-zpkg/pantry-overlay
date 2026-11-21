# github.com/python-poetry/tomlkit — tomlkit: a style-preserving TOML library.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a run-time
# dependency of hatchling (`tomlkit>=0.11.1`, its pyproject.toml:42).

summary = "tomlkit: style-preserving TOML library for Python"

# pyproject.toml:9 `license = "MIT"`; the sdist carries LICENSE.
license = "MIT"

versions {
  github = "python-poetry/tomlkit/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/t/tomlkit/tomlkit-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/tomlkit/) records for the sdist.
  sha256 = {
    "0.15.2" = "83e32755ba1d20d9340bd069ee97e9f6232ba2346b63ffcba425de01f7e327a6"
  }
}

build {
  dependencies = {
    "github.com/python-poetry/poetry-core" = "*"
  }

  script = [
    {
      # pyproject.toml:71-73 requires ["poetry-core>=2.2.0"], backend
      # poetry.core.masonry.api. The project declares no run-time dependencies.
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
import importlib.metadata, tomlkit
assert importlib.metadata.version("tomlkit") == "{{version.raw}}"
doc = tomlkit.parse("a = 1 # keep\n")
assert doc["a"] == 1 and tomlkit.dumps(doc) == "a = 1 # keep\n"
print(tomlkit.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "tomlkit was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :9 license MIT; :12 requires-python >=3.9; :71-73 build-system poetry-core>=2.2.0, poetry.core.masonry.api
    "LICENSE",        # the MIT text
  ]

  consulted = [
    "pypi.org/simple/tomlkit/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.
EOT
}
