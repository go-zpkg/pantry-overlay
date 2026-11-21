# rabbitmq.com — RabbitMQ, the message broker. go-zpkg/packages#440.
#
# ⛔ WRITTEN FROM THE GENERIC-UNIX RELEASE ARCHIVE, at 4.4.1, by reading the
# unpacked tree. That archive is what the coordinator asked for ("from its
# generic-unix source"): Erlang beam files under plugins/, the Erlang-escript
# CLI tools under escript/ and shell scripts under sbin/. Nothing in it is
# compiled for a CPU, so nothing here needs a C or C++ toolchain; the previous
# fragment's gcc 14 and libstdcxx 14 dependencies and its openssl dependency
# were dropped for that reason (openssl is Erlang's concern: the crypto
# application links it, and erlang.org's recipe takes it).

summary = "RabbitMQ: a message broker implementing AMQP 0-9-1, AMQP 1.0, MQTT, STOMP and streams, on the Erlang VM"

# LICENSE:1 "This package, the RabbitMQ server is licensed under the MPL2.0."
# (LICENSE-MPL-2.0 is in the tree; the bundled plugins carry their own, listed
# in the LICENSE-* files beside it.)
license = "MPL-2.0"

versions {
  # Tags are v4.4.1. The project also tags rolling and release-candidate names;
  # prereleases are left to zpkb's own ordering.
  github = "rabbitmq/rabbitmq-server"
  strip  = "/^v/"
}

dependencies = {
  # deps/rabbitmq_prelaunch/src/rabbit_prelaunch_erlang_compat.erl:10-12
  # (read at tag v4.4.1): OTP_MINIMUM "27.0", ERTS_MINIMUM "15.0"; :27-56 refuse
  # to start below it. The file states a minimum only, no maximum.
  "erlang.org" = ">=27"
}

distributable {
  # The project's own release asset, with a detached .asc beside it.
  # Two witnesses, both done on 2026-11-21:
  #   1. sha256 of a local download, 24412464 bytes.
  #   2. The detached signature rabbitmq-server-generic-unix-4.4.1.tar.xz.asc
  #      verified with gpg against the project's own signing key
  #      (github.com/rabbitmq/signing-keys, release 3.0,
  #      rabbitmq-release-signing-key.asc, no keyserver asked): "Good
  #      signature from RabbitMQ Release Signing Key <info@rabbitmq.com>", key
  #      0A9AF2115F4687BD29803A206B73A36E6026DFCA, made 2026-11-16.
  url              = "https://github.com/rabbitmq/rabbitmq-server/releases/download/v{{version}}/rabbitmq-server-generic-unix-{{version}}.tar.xz"
  strip-components = 1

  sha256 = {
    "4.4.1" = "667c652c1cb272c02f8a25b1ef32e981661f358b399a9d5c227982cc2101390f"
  }
}

build {
  script = [
    # The tree is relocatable: sbin/rabbitmq-env:85 derives RABBITMQ_HOME from
    # the script's own real path, and :171-175 puts $RABBITMQ_HOME/plugins on
    # ERL_LIBS, so the whole tree is copied under the prefix as it is.
    "mkdir -p \"{{prefix}}\"",
    "cp -R escript etc plugins sbin share \"{{prefix}}/\"",
  ]
}

provides = [
  "sbin/rabbitmq-server",
  "sbin/rabbitmqctl",
  "sbin/rabbitmq-plugins",
  "sbin/rabbitmq-diagnostics",
  "sbin/rabbitmq-queues",
  "sbin/rabbitmq-streams",
  "sbin/rabbitmq-upgrade",
]

test {
  script = [
    "test -x \"{{prefix}}/sbin/rabbitmq-server\"",
    "test -d \"{{prefix}}/plugins/rabbit-{{version}}\"",
    "test -x \"{{prefix}}/escript/rabbitmqctl\"",
    # `rabbitmqctl version` is answered by the escript itself, without a node.
    "test \"$(\"{{prefix}}/sbin/rabbitmqctl\" version)\" = \"{{version}}\"",
  ]
}

provenance {
  read = [
    "https://github.com/rabbitmq/rabbitmq-server/releases/expanded_assets/v4.4.1",  # the asset list: generic-unix tar.xz with .asc beside it
    "rabbitmq_server-4.4.1/INSTALL",  # :1-2 points at the online installation guide only
    "rabbitmq_server-4.4.1/LICENSE",  # :1 MPL 2.0
    "rabbitmq_server-4.4.1/sbin/rabbitmq-env",  # :85 RABBITMQ_HOME from the script's real path; :86 ESCRIPT_DIR; :171-175 ERL_LIBS; :189-196 escript launch
    "rabbitmq_server-4.4.1/sbin/rabbitmq-defaults",  # :10 SYS_PREFIX=${RABBITMQ_HOME}; :17 CONF_ENV_FILE
    "https://raw.githubusercontent.com/rabbitmq/rabbitmq-server/v4.4.1/deps/rabbitmq_prelaunch/src/rabbit_prelaunch_erlang_compat.erl",  # :10 OTP_MINIMUM 27.0, :12 ERTS_MINIMUM 15.0, :27-56 the refusal
  ]

  note = <<EOT
NOT BUILT. NOT RUN. The archive was downloaded, its signature checked and its
tree read; the recipe's script and test have not been run on either platform.

Open points, stated rather than hidden:
  - `rabbitmqctl version` answering without a running node was not run; if it
    needs one, the version line of the test must change.
  - Erlang is found through PATH by the scripts; the recipe adds nothing to the
    environment of its own.
  - Whether the escripts embed Elixir (the tree ships no Elixir) was not
    checked; no elixir-lang.org dependency is declared because the tree has no
    reference to one.
  - The `-latest-toolchain` generic-unix variant exists and was not chosen.
  - Runtime state (mnesia dir, logs) goes where RabbitMQ's own defaults put it
    (under RABBITMQ_HOME/var unless the environment says otherwise); no
    configuration is shipped.
EOT
}
