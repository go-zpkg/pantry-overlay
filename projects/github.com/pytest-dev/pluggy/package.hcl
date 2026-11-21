# github.com/pytest-dev/pluggy — pluggy: the plugin and hook-calling machinery
# of pytest, tox and hatch.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of hatchling (`pluggy>=1.0.0`, its pyproject.toml:41), which virtualenv's
# build backend needs.

summary = "pluggy: plugin and hook calling mechanisms for Python"

# pyproject.toml:10 `license = {text = "MIT"}`; the sdist carries LICENSE.
license = "MIT"

versions {
  github = "pytest-dev/pluggy/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/pluggy/pluggy-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/pluggy/) records for the sdist.
  sha256 = {
    "1.7.0" = "d1eaa46ebb595891b860ab086b4d09c8588af65ebd4361b8e8f4bb8920b90ba8"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools"     = "*"
    "pypa.io/setuptools-scm" = "*"
  }

  script = [
    {
      # pyproject.toml:2-6 requires setuptools>=65.0 and setuptools-scm[toml]>=8.0,
      # backend setuptools.build_meta; :37 `dynamic = ["version"]`, which
      # setuptools-scm resolves from the sdist's PKG-INFO. The project declares
      # no run-time dependencies.
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
import importlib.metadata, pluggy
assert importlib.metadata.version("pluggy") == "{{version.raw}}"
spec = pluggy.HookspecMarker("probe")
impl = pluggy.HookimplMarker("probe")
class Spec:
    @spec
    def hello(self, arg): ...
class Plugin:
    @impl
    def hello(self, arg): return arg + 1
pm = pluggy.PluginManager("probe")
pm.add_hookspecs(Spec)
pm.register(Plugin())
assert pm.hook.hello(arg=1) == [2]
print(pluggy.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "pluggy was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :2-6 build-system setuptools>=65.0, setuptools-scm[toml]>=8.0; :10 license MIT; :35 requires-python >=3.10; :37 dynamic version
    "LICENSE",        # the MIT text
  ]

  consulted = [
    "pypi.org/simple/pluggy/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.
EOT
}
