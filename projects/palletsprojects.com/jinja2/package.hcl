# palletsprojects.com/jinja2 — Jinja2: the Python template engine.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#431, #440). It exists
# because systemd's meson.build:1735 is
#   python = pymod.find_installation('python3', required : true, modules : ['jinja2'])
# and README:257 lists python-jinja2 as a build requirement.

summary = "Jinja2: a fast and expressive template engine for Python"

# LICENSE.txt: "Copyright 2007 Pallets", the BSD-3-Clause text.
license = "BSD-3-Clause"

versions {
  github = "pallets/jinja/tags"
}

dependencies = {
  "python.org"                    = "^3"
  "palletsprojects.com/markupsafe" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/j/jinja2/jinja2-{{version.raw}}.tar.gz"
  strip-components = 1

  # 245115 bytes, fetched with `zpkb sourcepin`, and byte-identical to the
  # sha256 PyPI's JSON API (pypi.org/pypi/jinja2/3.1.6/json) records for the
  # sdist.
  sha256 = {
    "3.1.6" = "0137fb05990d35f1275a587e9aee6d56da821fc83491a0fb838183be43f66d6d"
  }
}

build {
  dependencies = {
    "pypa.io/flit-core" = "*"
  }

  script = [
    {
      # pyproject.toml [build-system]: requires ["flit_core<4"], backend
      # flit_core.buildapi. flit_core comes from the build dependency above, so
      # nothing is fetched from an index. [project] dependencies = MarkupSafe>=2.0,
      # which is the run-time dependency declared above; --no-deps keeps pip from
      # looking for it.
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
import jinja2
assert jinja2.__version__ == "{{version.raw}}", jinja2.__version__
out = jinja2.Template("{% for x in xs %}<{{ x }}>{% endfor %}", autoescape=True).render(xs=["a", "<b>"])
assert out == "<a><&lt;b&gt;>", out
print(jinja2.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "jinja2 was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # [project] dependencies MarkupSafe>=2.0, requires-python >=3.7; [build-system] flit_core<4, flit_core.buildapi
    "LICENSE.txt",    # "Copyright 2007 Pallets", BSD-3-Clause text
  ]

  consulted = [
    "pypi.org/pypi/jinja2/3.1.6/json", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's JSON API and by the bytes
`zpkb sourcepin` fetched, which agree.

The build backend is flit_core below 4 (pypa.io/flit-core, which holds the 4.x
series out for exactly this bound).
EOT
}
