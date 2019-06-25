use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
#
config :asteroid, AsteroidWeb.Endpoint,
  http: [port: 4000],
  #url: [scheme: "https", host: "www.example.com", path: "/account/auth", port: 443],
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

config :asteroid, AsteroidWeb.EndpointAPI,
  http: [port: 4001],
  #url: [scheme: "https", host: "www.example.com", path: "/account/auth", port: 443],
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

config :mnesia,
   dir: 'Mnesia.#{node()}-#{Mix.env}'

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Configure your database
config :asteroid, Asteroid.Repo,
  username: "postgres",
  password: "postgres",
  database: "asteroid_dev",
  hostname: "localhost",
  pool_size: 10

######################################################################
######################################################################
################## Asteroid configuration ############################
######################################################################
######################################################################

config :asteroid, :token_store_access_token, [
  #module: Asteroid.TokenStore.AccessToken.Riak,
  #opts: [bucket_type: "ephemeral_token"]
  module: Asteroid.TokenStore.AccessToken.Mnesia
]

config :asteroid, :token_store_refresh_token, [
  #module: Asteroid.TokenStore.RefreshToken.Mnesia
  module: Asteroid.TokenStore.RefreshToken.Riak,
  opts: [bucket_type: "token"]
]

config :asteroid, :token_store_authorization_code, [
  module: Asteroid.TokenStore.AuthorizationCode.Riak,
  opts: [bucket_type: "ephemeral_token"]
]

config :asteroid, :token_store_device_code, [
  module: Asteroid.TokenStore.DeviceCode.Riak,
  opts: [bucket_type: "ephemeral_token"]
]

config :asteroid, :attribute_repositories,
[
  #subject: [
  #  module: AttributeRepositoryLdap,
  #  init_opts: [
  #    name: :slapd,
  #    max_overflow: 10,
  #    ldap_args: [hosts: ['localhost'], base: 'ou=people,dc=example,dc=org']
  #  ],
  #  run_opts: [instance: :slapd, base_dn: 'ou=people,dc=example,dc=org'],
  #  auto_install: false, # AttributeRepositoryLdap has no install callback implemented
  #  default_loaded_attributes: ["cn", "displayName", "givenName", "mail", "manager", "sn"]
  #],
  subject: [
    module: AttributeRepositoryMnesia,
    run_opts: [instance: :subject],
    init_opts: [instance: :subject]
  ],
  client: [
    module: AttributeRepositoryMnesia,
    init_opts: [instance: :client, mnesia_config: [disc_copies: [node()]]],
    run_opts: [instance: :client]
  ],
  device: [
    module: AttributeRepositoryRiak,
    run_opts: [instance: :device, bucket_type: "device"],
    auto_start: false
  ]
]

config :pooler,
  pools: [
    [
      name: :riak,
      group: :riak,
      max_count: 10,
      init_count: 5,
      start_mfa: {Riak.Connection, :start_link, ['127.0.0.1', 8087]}
    ]
  ]

config :asteroid, :api_oauth2_plugs,
  [
    {APIacFilterIPWhitelist, [whitelist: ["127.0.0.1/32"], error_response_verbosity: :debug]},
    {APIacAuthBasic,
      realm: "Asteroid",
      callback: &Asteroid.Config.DefaultCallbacks.get_client_secret/2,
      set_error_response: &APIacAuthBasic.save_authentication_failure_response/3,
      error_response_verbosity: :debug},
    {APIacAuthClientSecretPost,
      realm: "Asteroid",
      callback: &Asteroid.Config.DefaultCallbacks.always_nil/2,
      set_error_response: &APIacAuthBasic.save_authentication_failure_response/3,
      error_response_verbosity: :debug}
  ]

config :asteroid, :api_oauth2_endpoint_token_plugs,
  [
    {Corsica, [origins: "*"]},
    {APIacFilterThrottler,
      key: &APIacFilterThrottler.Functions.throttle_by_ip_path/1,
      scale: 60_000,
      limit: 50,
      exec_cond: &Asteroid.Config.DefaultCallbacks.conn_not_authenticated?/1,
      error_response_verbosity: :debug},
    {APIacAuthBasic,
      realm: "always erroneous client password",
      callback: &Asteroid.Config.DefaultCallbacks.always_nil/2,
      set_error_response: &APIacAuthBasic.save_authentication_failure_response/3,
      error_response_verbosity: :debug},
    {APIacAuthBearer,
      realm: "Asteroid",
      bearer_validator:
        {
          APIacAuthBearer.Validator.Identity,
          [response: {:error, :invalid_token}]
        },
      set_error_response: &APIacAuthBearer.save_authentication_failure_response/3,
      error_response_verbosity: :debug}
  ]

config :asteroid, :api_oauth2_endpoint_revoke_plugs, [{Corsica, [origins: "*"]}]

config :asteroid, :oauth2_grant_types_enabled, [
  :authorization_code, :implicit, :password, :client_credentials, :refresh_token,
  :"urn:ietf:params:oauth:grant-type:device_code"
]

config :asteroid, :oauth2_response_types_enabled, [:code, :token]

config :asteroid, :api_error_response_verbosity, :normal

config :asteroid, :oauth2_flow_ropc_username_password_verify_callback,
  &CustomDev.Callback.test_ropc_username_password_callback/3

config :asteroid, :oauth2_scope_callback,
  &Asteroid.OAuth2.Scope.grant_for_flow/2

config :asteroid, :oauth2_endpoint_token_grant_type_password_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_token_grant_type_password_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_token_grant_type_refresh_token_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_token_grant_type_refresh_token_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

# Endpoint: introspect

config :asteroid, :oauth2_endpoint_introspect_client_authorized,
  &Asteroid.OAuth2.Client.endpoint_introspect_authorized?/1

config :asteroid, :oauth2_endpoint_introspect_claims_resp,
  ["scope", "client_id", "username", "token_type", "exp", "iat", "nbf", "sub", "aud", "iss", "jti"]

config :asteroid, :oauth2_endpoint_introspect_claims_resp_callback,
  &Asteroid.OAuth2.Callback.endpoint_introspect_claims_resp/1

config :asteroid, :oauth2_endpoint_introspect_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_introspect_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

# Endpoint: revoke

config :asteroid, :oauth2_endpoint_revoke_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

# Flow: client credentials

config :asteroid, :oauth2_flow_client_credentials_issue_refresh_token_init, false

config :asteroid, :oauth2_flow_client_credentials_issue_refresh_token_refresh, false

config :asteroid, :oauth2_flow_client_credentials_access_token_lifetime, 60 * 10

config :asteroid, :oauth2_endpoint_token_grant_type_client_credentials_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_token_grant_type_client_credentials_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

# Refresh tokens

config :asteroid, :token_store_refresh_token_before_store_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_issue_refresh_token_callback,
  &Asteroid.Token.RefreshToken.issue_refresh_token?/1

config :asteroid, :oauth2_flow_ropc_issue_refresh_token_init, true

config :asteroid, :oauth2_flow_ropc_issue_refresh_token_refresh, false

config :asteroid, :oauth2_refresh_token_lifetime_callback,
  &Asteroid.Token.RefreshToken.lifetime/1

config :asteroid, :oauth2_flow_ropc_refresh_token_lifetime, 60 * 60 * 24 * 7 # 1 week

# access tokens

config :asteroid, :token_store_access_token_before_store_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_access_token_lifetime_callback,
  &Asteroid.Token.AccessToken.lifetime/1

config :asteroid, :oauth2_flow_ropc_access_token_lifetime, 60 * 10

config :asteroid, :client_credentials_issue_refresh_token, false

config :asteroid, :client_credentials_scope_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

# authorization codes

config :asteroid, :token_store_authorization_code_before_store_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_authorization_code_lifetime_callback,
  &Asteroid.Token.AuthorizationCode.lifetime/1

config :asteroid, :oauth2_flow_authorization_code_authorization_code_lifetime, 60

config :asteroid, :oauth2_endpoint_authorize_response_type_code_before_send_redirect_uri_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_authorize_response_type_code_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_flow_authorization_code_issue_refresh_token_init, true

config :asteroid, :oauth2_flow_authorization_code_issue_refresh_token_refresh, false

config :asteroid, :oauth2_flow_authorization_code_refresh_token_lifetime,
  60 * 60 * 24 * 7 # 1 week

config :asteroid, :oauth2_flow_authorization_code_access_token_lifetime, 60 * 10

config :asteroid, :oauth2_endpoint_token_grant_type_authorization_code_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_token_grant_type_authorization_code_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_flow_authorization_code_pkce_policy, :optional

config :asteroid, :oauth2_flow_authorization_code_pkce_allowed_methods, [:S256]

config :asteroid, :oauth2_flow_authorization_code_pkce_client_callback,
  &Asteroid.OAuth2.Client.must_use_pkce?/1

# implicit flow

config :asteroid, :oauth2_flow_implicit_access_token_lifetime, 60 * 60

config :asteroid, :oauth2_endpoint_authorize_response_type_token_before_send_redirect_uri_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_authorize_response_type_token_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

# client registration

config :asteroid, :oauth2_endpoint_register_authorization_callback,
  &Asteroid.OAuth2.Register.request_authorized?/2

config :asteroid, :oauth2_endpoint_register_authorization_policy, :authorized_clients

config :asteroid, :oauth2_endpoint_register_additional_metadata_field, ["test_field"]

config :asteroid, :oauth2_endpoint_register_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_register_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_register_client_before_save_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_register_gen_client_id_callback,
  &Asteroid.OAuth2.Register.generate_client_id/1

config :asteroid, :oauth2_endpoint_register_client_type_callback,
  &Asteroid.OAuth2.Register.client_type/1

# endpoint token

config :asteroid, :oauth2_endpoint_token_auth_methods_supported_callback,
  &Asteroid.OAuth2.Endpoint.token_endpoint_auth_methods_supported/0

# scope configuration

config :asteroid, :scope_config,
[
  scopes: %{
    "api.access" => [auto: true]
  }
]

config :asteroid, :oauth2_scope_config,
[
  scopes: %{
    "read_balance" => [
      label: %{
        "en" => "Read my account balance",
        "fr" => "Lire mes soldes de compte",
        "ru" => "Читать баланс счета"
      }
    ],
    "read_account_information" => [
      optional: true,
      label: %{
        "en" => "Read my account transactions",
        "fr" => "Consulter la liste de mes transactions bancaires",
        "ru" => "Читать транзакции по счету"
      }
    ]
  }
]

config :asteroid, :oauth2_flow_authorization_code_scope_config,
[
  scopes: %{
    "interbank_transfer" => [
      max_refresh_token_lifetime: 3600 * 24 * 30 * 3,
      max_access_token_lifetime: 3 * 60,
      label: %{
        "en" => "Make bank transfers",
        "fr" => "Réaliser des virements",
        "ru" => "Делать банковские переводы"
      }
    ]
  }
]
config :asteroid, :oauth2_flow_ropc_scope_config,
  %{
    "scope-a" => [auto: true],
    "scope-b" => [auto: true],
    "scope-c" => [auto: false],
    "scope-d" => [],
    "scope-f" => [auto: true],
  }

config :asteroid, :oauth2_flow_client_credentials_scope_config,
  %{
    "scope-a" => [auto: true],
    "scope-b" => [auto: true],
    "scope-c" => [auto: false],
    "scope-d" => [],
    "scope-f" => [auto: true],
  }

# OAuth2 metadata

config :asteroid, :oauth2_endpoint_metadata_service_documentation,
  "https://www.example.com/authentication/documentation/"

config :asteroid, :oauth2_endpoint_metadata_op_policy_uri,
  "https://www.example.com/authentication/policy/"

config :asteroid, :oauth2_endpoint_metadata_signed_fields,
  ["token_endpoint", "token_endpoint_auth_methods_supported", "scopes_supported"]

config :asteroid, :oauth2_endpoint_metadata_signing_key, "key_auto"

config :asteroid, :oauth2_endpoint_metadata_signing_alg, "PS384"

config :asteroid, :oauth2_endpoint_metadata_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id/1

config :asteroid, :oauth2_endpoint_metadata_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id/1

# JWKs URI

config :asteroid, :oauth2_endpoint_discovery_keys_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id/1

config :asteroid, :oauth2_endpoint_discovery_keys_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id/1

# crypto

config :asteroid, :crypto_keys, %{
  "key_from_file_1" => {:pem_file, [path: "priv/keys/ec-secp256r1.pem", use: :sig]},
  "key_from_file_2" => {:pem_file, [path: "priv/keys/ec-secp521r1.pem", use: :sig]},
  "key_from_map" => {:map, [key: {%{kty: :jose_jwk_kty_oct}, %{"k" => "P9dGnU_We5thJOOigUGtl00WmubLVAAr1kYsAUP80Sc", "kty" => "oct"}}, use: :sig]},
  "key_auto" => {:auto_gen, [params: {:rsa, 2048}, use: :sig, advertise: false]}
}

config :asteroid, :crypto_keys_cache, {Asteroid.Crypto.Key.Cache.ETS, []}

# JWS access tokens

config :asteroid, :oauth2_access_token_serialization_format_callback,
  &Asteroid.Token.AccessToken.serialization_format/1

config :asteroid, :oauth2_access_token_signing_key_callback,
  &Asteroid.Token.AccessToken.signing_key/1

config :asteroid, :oauth2_access_token_signing_alg_callback,
  &Asteroid.Token.AccessToken.signing_alg/1

  #config :asteroid, :oauth2_flow_ropc_access_token_serialization_format, :jws

config :asteroid, :oauth2_flow_ropc_access_token_signing_key, "key_auto"

config :asteroid, :oauth2_flow_client_credentials_access_token_serialization_format, :jws

config :asteroid, :oauth2_flow_client_credentials_access_token_signing_key, "key_auto"

config :asteroid, :oauth2_flow_client_credentials_access_token_signing_alg, "RS384"

# device authorization flow

config :asteroid, :oauth2_endpoint_device_authorization_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_device_authorization_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :token_store_device_code_before_store_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_flow_device_authorization_device_code_lifetime, 60 * 15

config :asteroid, :oauth2_flow_device_authorization_user_code_callback,
  &Asteroid.OAuth2.DeviceAuthorization.user_code/1

config :asteroid, :oauth2_flow_device_authorization_issue_refresh_token_init, true

config :asteroid, :oauth2_flow_device_authorization_issue_refresh_token_refresh, false

config :asteroid, :oauth2_flow_device_authorization_refresh_token_lifetime, 10 * 365 * 24 * 3600

config :asteroid, :oauth2_flow_device_authorization_access_token_lifetime, 60 * 10

config :asteroid, :oauth2_endpoint_token_grant_type_device_code_before_send_resp_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_endpoint_token_grant_type_device_code_before_send_conn_callback,
  &Asteroid.Config.DefaultCallbacks.id_first_param/2

config :asteroid, :oauth2_flow_device_authorization_rate_limiter,
  {Asteroid.OAuth2.DeviceAuthorization.RateLimiter.Hammer, []}

config :asteroid, :oauth2_flow_device_authorization_rate_limiter_interval, 5
