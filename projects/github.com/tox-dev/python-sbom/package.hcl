# github.com/tox-dev/python-sbom — python-sbom: PEP 770 CycloneDX SBOMs written
# into Python wheels.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as the build
# requirement `python-sbom[hatch]` of virtualenv, filelock, platformdirs and
# python-discovery, whose Hatch configuration names its hook
# (`build.hooks.python-sbom = {}` in filelock and platformdirs, and
# hatch_build.py importing python_sbom.hatch in virtualenv and python-discovery).

summary = "python-sbom: write PEP 770 CycloneDX SBOMs into Python wheels"

# pyproject.toml:28 `license = "MIT AND Apache-2.0"` (the Apache part is the
# bundled schemas, src/python_sbom/_validate/schemas/LICENSE, :29).
license = "MIT AND Apache-2.0"

versions {
  github = "tox-dev/python-sbom/tags"
}

dependencies = {
  "python.org"                              = "^3"
  "pypa.io/installer"                       = "*"
  "github.com/package-url/packageurl-python" = "*"
  "pypa.io/packaging"                       = "*"
  "github.com/danny0838/zipremove"          = "*"
  "pypa.io/hatchling"                       = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/python-sbom/python_sbom-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/python-sbom/) records for the sdist.
  sha256 = {
    "0.5.0" = "fc7b2c46fa40f52e587ac59cada775e83dcac231fafa90b7a71c3554527ddfb6"
  }
}

build {
  dependencies = {
    "pypa.io/hatchling"                       = "*"
    "github.com/ofek/hatch-vcs"               = "*"
    "github.com/hynek/hatch-fancy-pypi-readme" = "*"
    "pypa.io/installer"                       = "*"
    "github.com/package-url/packageurl-python" = "*"
    "pypa.io/packaging"                       = "*"
    "github.com/danny0838/zipremove"          = "*"
  }

  script = [
    {
      # pyproject.toml:3-10 requires hatch-fancy-pypi-readme, hatch-vcs,
      # hatchling, installer, packageurl-python and zipremove, backend
      # hatchling.build. hatch_build.py (:191) loads python-sbom's own hook from
      # src/, because python-sbom cannot be its own build requirement; that is
      # why installer, packageurl-python, packaging and zipremove are build
      # dependencies. The version is VCS-derived (:182), the sdist is not a
      # checkout, so it is pinned from the resolved one.
      run = <<EOT
set -eu
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
import importlib.metadata, python_sbom, python_sbom.hatch
assert importlib.metadata.version("python-sbom") == "{{version.raw}}"
print(python_sbom.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "python_sbom was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml",  # :3-10 build-system; :28-29 license; :33 requires-python >=3.11; :56-61 dependencies; :62-64 hatch extra; :181-191 Hatch config
    "hatch_build.py",  # the self-hosting hook: sys.path gets src/, then python_sbom.hatch is imported
    "LICENSE",         # present in the sdist
  ]

  consulted = [
    "pypi.org/simple/python-sbom/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

Only the `hatch` extra is relevant to this tree; the `validate` extra
(jsonschema-rs, license-expression, spdx-tools) is not written, so SBOM
validation is unavailable. The SBOM hook reads a revision
(src/python_sbom/_collect/_revision.py:27 names `.python-sbom-revision`), and
the sdist carries that file, so a build outside a git checkout is expected to
work; that has not been measured.
EOT
}
