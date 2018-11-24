use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :asteroid, AsteroidWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :asteroid, AsteroidWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/asteroid_web/views/.*(ex)$},
      ~r{lib/asteroid_web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :apisex_auth_basic,
  clients: %{
    "Asteroid"=> [{"testclient", "1235813"}]
  }

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Configure your database
config :asteroid, Asteroid.Repo,
  username: "postgres",
  password: "postgres",
  database: "asteroid_dev",
  hostname: "localhost",
  pool_size: 10

config :asteroid, :attribute_repositories,
[
  client: [
    impl: Asteroid.AttributeRepository.Impl.Mnesia,
    autoinstall: true,
    autostart: true,
    attribute_autoload: ["client_id", "client_class"],
    opts:
    [
      table: :client,
      mnesia_create_table:
      [
        disc_copies: [node()]
      ]
    ]
  ],
  subject: [
    impl: Asteroid.AttributeRepository.Impl.Mnesia,
    autoinstall: true,
    autostart: true,
    attribute_autoload: ["sub", "given_name", "family_name", "gender"],
    opts:
    [
      table: :subject,
      mnesia_create_table:
      [
        disc_copies: [node()]
      ]
    ]
  ]
]

config :asteroid, :flow_ropc_enabled, true

config :asteroid, :issuer_callback, &Asteroid.Config.DefaultCallbacks.issuer/1

config :asteroid, :ropc_username_password_verify_callback,
  &Asteroid.Config.DefaultCallbacks.test_ropc_username_password_callback/3

config :asteroid, :refresh_token_lifetime_callback,
  &Asteroid.Config.DefaultCallbacks.refresh_token_lifetime_callback/1

config :asteroid, :refresh_token_lifetime_ropc, 60 * 60 * 24 * 7 # 1 week

config :asteroid, :access_token_lifetime_callback,
  &Asteroid.Config.DefaultCallbacks.access_token_lifetime_callback/1

config :asteroid, :access_token_lifetime_ropc, 60 * 10

config :asteroid, :access_token_store, Asteroid.Store.AccessToken.Mnesia
config :asteroid, :access_token_store_opts, []

config :asteroid, :refresh_token_store, Asteroid.Store.RefreshToken.Mnesia
config :asteroid, :refresh_token_store_opts, []

config :asteroid, :ropc_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :ropc_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2
