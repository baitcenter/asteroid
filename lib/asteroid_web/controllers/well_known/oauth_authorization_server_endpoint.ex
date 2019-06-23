defmodule AsteroidWeb.WellKnown.OauthAuthorizationServerEndpoint do
  @moduledoc false

  use AsteroidWeb, :controller

  import Asteroid.Utils

  alias Asteroid.OAuth2
  alias AsteroidWeb.Router.Helpers, as: Routes

  def handle(conn, _params) do
    metadata =
      %{}
      |> Map.put("issuer", OAuth2.issuer())
      |> maybe_put_authorization_endpoint()
      |> maybe_put_token_endpoint()
      |> put_registration_endpoint()
      |> put_scopes_supported()
      |> put_response_types_supported()
      |> put_grant_types_supported()
      |> put_token_endpoint_auth_method_supported()
      |> put_jwks_uri()
      |> put_revocation_endpoint()
      |> put_revocation_endpoint_auth_method_supported()
      |> put_introspection_endpoint()
      |> put_introspection_endpoint_auth_method_supported()
      |> put_device_authorization_endpoint()
      |> put_code_challenge_methods_supported()
      |> put_if_not_nil("service_documentation",
                        astrenv(:oauth2_endpoint_metadata_service_documentation, nil))
      |> put_if_not_nil("ui_locales_supported",
                        astrenv(:oauth2_endpoint_metadata_ui_locales_supported, nil))
      |> put_if_not_nil("op_policy_uri",
                        astrenv(:oauth2_endpoint_metadata_op_policy_uri, nil))
      |> put_if_not_nil("op_tos_uri",
                        astrenv(:oauth2_endpoint_metadata_op_tos_uri, nil))
      |> astrenv(:oauth2_endpoint_metadata_before_send_resp_callback).()

    conn
    |> astrenv(:oauth2_endpoint_metadata_before_send_conn_callback).()
    |> json(metadata)
  end

  @spec maybe_put_authorization_endpoint(map()) :: map()

  defp maybe_put_authorization_endpoint(metadata) do
    if Enum.any?(
      astrenv(:oauth2_grant_types_enabled, []),
      fn grant_type -> OAuth2Utils.uses_authorization_endpoint?(to_string(grant_type)) end
    ) do
      Map.put(metadata,
              "authorization_endpoint",
              Routes.authorize_url(AsteroidWeb.Endpoint, :pre_authorize))
    else
      metadata
    end
  end

  @spec maybe_put_token_endpoint(map()) :: map()

  defp maybe_put_token_endpoint(metadata) do
    case astrenv(:oauth2_grant_types_enabled, []) do
      [:implicit] ->
        metadata

      _ ->
      Map.put(metadata,
              "token_endpoint",
              Routes.token_endpoint_url(AsteroidWeb.Endpoint, :handle))
    end
  end

  @spec put_registration_endpoint(map()) :: map()

  defp put_registration_endpoint(metadata) do
      Map.put(metadata,
              "registration_endpoint",
              Routes.register_endpoint_url(AsteroidWeb.Endpoint, :handle))
  end

  @spec put_scopes_supported(map()) :: map()

  defp put_scopes_supported(metadata) do
    grant_types_enabled = astrenv(:oauth2_grant_types_enabled, [])

    scopes =
      if :password in grant_types_enabled do
        OAuth2.Scope.configuration_for_flow(:ropc)[:scopes]
      else
        %{}
      end

    scopes =
      if :client_credentials in grant_types_enabled do
        Map.merge(scopes, OAuth2.Scope.configuration_for_flow(:client_credentials)[:scopes])
      else
        scopes
      end

    scopes =
      if :authorization_code in grant_types_enabled do
        Map.merge(scopes, OAuth2.Scope.configuration_for_flow(:authorization_code)[:scopes])
      else
        scopes
      end

    scopes =
      if :implicit in grant_types_enabled do
        Map.merge(scopes, OAuth2.Scope.configuration_for_flow(:authorization_code)[:scopes])
      else
        scopes
      end

    advertised_scopes =
      Enum.reduce(
        scopes,
        [],
        fn
          {scope, scope_opts}, acc ->
            if scope_opts[:advertise] == false do
              acc
            else
              acc ++ [scope]
            end
        end
      )

    case advertised_scopes do
      [_ | _] ->
        Map.put(metadata, "scopes_supported", advertised_scopes)

      [] ->
        metadata
    end
  end

  @spec put_response_types_supported(map()) :: map()

  defp put_response_types_supported(metadata) do
    case astrenv(:oauth2_response_types_enabled, []) do
      [] ->
        metadata

      response_types when is_list(response_types) ->
        Map.put(metadata, "response_types_supported", Enum.map(response_types, &to_string/1))
    end
  end

  @spec put_grant_types_supported(map()) :: map()

  defp put_grant_types_supported(metadata) do
    case astrenv(:oauth2_grant_types_enabled, []) do
      [] ->
        metadata

      grant_types when is_list(grant_types) ->
        Map.put(metadata, "grant_types_supported", Enum.map(grant_types, &to_string/1))
    end
  end

  @spec put_token_endpoint_auth_method_supported(map()) :: map()

  defp put_token_endpoint_auth_method_supported(metadata) do
    token_endpoint_auth_methods_supported =
      OAuth2.Endpoint.token_endpoint_auth_methods_supported()
      |> Enum.map(&to_string/1)

    case token_endpoint_auth_methods_supported do
      [] ->
        metadata

      methods when is_list(methods) ->
        Map.put(metadata, "token_endpoint_auth_methods_supported",methods)
    end
  end

  @spec put_jwks_uri(map()) :: map()

  defp put_jwks_uri(metadata) do
    if astrenv(:crypto_keys) do
      Map.put(metadata,
              "jwks_uri",
              Routes.keys_endpoint_url(AsteroidWeb.Endpoint, :handle))
    else
      metadata
    end
  end

  @spec put_revocation_endpoint(map()) :: map()

  defp put_revocation_endpoint(metadata) do
      Map.put(metadata,
              "revocation_endpoint",
              Routes.revoke_endpoint_url(AsteroidWeb.Endpoint, :handle))
  end

  @spec put_revocation_endpoint_auth_method_supported(map()) :: map()

  defp put_revocation_endpoint_auth_method_supported(metadata) do
    revoke_endpoint_auth_methods_supported =
      OAuth2.Endpoint.revoke_endpoint_auth_methods_supported()
      |> Enum.map(&to_string/1)

    case revoke_endpoint_auth_methods_supported do
      [] ->
        metadata

      methods when is_list(methods) ->
        Map.put(metadata, "revocation_endpoint_auth_methods_supported", methods)
    end
  end

  @spec put_introspection_endpoint(map()) :: map()

  defp put_introspection_endpoint(metadata) do
      Map.put(metadata,
              "introspection_endpoint",
              Routes.introspect_endpoint_url(AsteroidWeb.Endpoint, :handle))
  end

  @spec put_introspection_endpoint_auth_method_supported(map()) :: map()

  defp put_introspection_endpoint_auth_method_supported(metadata) do
    introspect_endpoint_auth_methods_supported =
      OAuth2.Endpoint.introspect_endpoint_auth_methods_supported()
      |> Enum.map(&to_string/1)

    case introspect_endpoint_auth_methods_supported do
      [] ->
        metadata

      methods when is_list(methods) ->
        Map.put(metadata, "introspection_endpoint_auth_methods_supported", methods)
    end
  end

  @spec put_device_authorization_endpoint(map()) :: map()

  defp put_device_authorization_endpoint(metadata) do
    if :"urn:ietf:params:oauth:grant-type:device_code" in astrenv(:oauth2_grant_types_enabled, [])
    do
      Map.put(metadata,
              "device_authorization_endpoint",
              Routes.device_authorization_endpoint_url(AsteroidWeb.Endpoint, :handle))
    else
      metadata
    end
  end

  @spec put_code_challenge_methods_supported(map()) :: map()

  defp put_code_challenge_methods_supported(metadata) do
    case astrenv(:oauth2_flow_authorization_code_pkce_policy, []) do
      :disabled->
        metadata

      _ ->
        methods =
          astrenv(:oauth2_flow_authorization_code_pkce_allowed_methods, [])
          |> Enum.map(&to_string/1)

        Map.put(metadata, "code_challenge_methods_supported", methods)
    end
  end
end