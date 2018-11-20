defmodule AsteroidWeb.API.OAuth2.TokenEndpoint do
  use AsteroidWeb, :controller
  import Asteroid.Utils
  alias OAuth2Utils.Scope
  alias Asteroid.Token.{RefreshToken, AccessToken}
  alias Asteroid.{Client, Subject, Context}

  # OAuth2 ROPC flow (resource owner password credentials)
  # https://tools.ietf.org/html/rfc6749#section-4.3.2
  def handle(%Plug.Conn{body_params:
    %{"grant_type" => "password",
      "username" => username,
      "password" => password,
    }} = conn, _params)
  when username != nil and password != nil do
    scope_param = conn.body_params["scope"]

    with {:ok, client} <- client_authenticated?(conn),
         :ok <- grant_type_enabled?(:password),
         :ok <- client_grant_type_authorized?(client, :password),
         {:ok, scope} <- scope_param_valid?(scope_param),
         :ok <- client_scope_authorized?(client, scope),
         {:ok, subject} <-
           astrenv(:ropc_username_password_verify_callback).(conn, username, password)
    do
      ctx = %{
        :request => %{
          :endpoint => :token,
          :flow => :ropc,
          :grant_type => :password,
          :scope => Scope.Set.from_scope_param!(scope_param),
        },
        client: client,
        subject: subject
      }

      refresh_token =
        RefreshToken.new()
        |> RefreshToken.put_claim(:iat, now())
        |> RefreshToken.put_claim(:exp, now() + astrenv(:refresh_token_lifetime_callback).(ctx))
        |> RefreshToken.put_claim(:client_id, client.client_id)
        |> RefreshToken.put_claim(:sub, subject.sub)
        |> RefreshToken.put_claim(:iss, astrenv(:issuer_callback).(ctx))

      access_token =
        AccessToken.new(refresh_token: refresh_token)
        |> AccessToken.put_claim(:iat, now())
        |> AccessToken.put_claim(:exp, now() + astrenv(:access_token_lifetime_callback).(ctx))
        |> AccessToken.put_claim(:client_id, client.client_id)
        |> AccessToken.put_claim(:sub, subject.sub)
        |> AccessToken.put_claim(:iss, astrenv(:issuer_callback).(ctx))

      RefreshToken.store(refresh_token, ctx: ctx)
      AccessToken.store(access_token, ctx: ctx)

      resp =
        %{
          "access_token" => AccessToken.serialize(access_token),
          "refresh_token" => RefreshToken.serialize(refresh_token),
          "expires_in" => access_token.exp - now(),
          "token_type" => "bearer"
        }
        |> astrenv(:ropc_before_send_resp_callback).(ctx)

      conn
      |> astrenv(:ropc_before_send_conn_callback).(ctx)
      |> put_status(200)
      |> json(resp)
    else
      {:error, :unauthenticated_client} ->
        error_resp(conn, 401, error: :invalid_client,
                   error_description: "Client authentication failed")

      {:error, :grant_type_disabled} ->
        error_resp(conn, error: :unsupported_grant_type,
                   error_description: "Grant type password not enabled")

      {:error, :grant_type_not_authorized_for_client} ->
        error_resp(conn, error: :unauthorized_client,
                   error_description: "Client is not authorized to use this grant type")

      {:error, :malformed} ->
        error_resp(conn, error: :invalid_scope,
                   error_description: "Scope param is malformed")
    end
  end

  def handle(%Plug.Conn{body_params: %{"grant_type" => "password"}} = conn, _params) do
    error_resp(conn,
                   error: "invalid_request",
                   error_description: "Missing username or password parameter")
  end

  # unrecognized or unsupported grant

  def handle(%Plug.Conn{body_params: %{"grant_type" => grant}} = conn, _params) do
    error_resp(conn,
                   error: "invalid_grant",
                   error_description: "Invalid grant #{grant}")
  end

  @spec client_authenticated?(Plug.Conn.t()) ::
    {:ok, String.t} | {:error, :unauthenticated_client}
  defp client_authenticated?(conn) do
    case APISex.client(conn) do
      client when is_binary(client) ->
        {:ok, client}

      nil ->
        {:error, :unauthenticated_client}
    end
  end

  defp error_resp(conn, error_status \\ 400, error_data) do
    conn
    |> put_status(error_status)
    |> json(Enum.into(error_data, %{}))
  end

  @spec grant_type_enabled?(Asteroid.GrantType.t()) :: :ok | {:error, :grant_type_disabled}
  defp grant_type_enabled?(:password) do
    Application.get_env(:asteroid, :flow_ropc_enabled, false)
  end

  @spec client_grant_type_authorized?(Asteroid.Client.client_param(), Asteroid.GrantType.t()) ::
    :ok | {:error, :grant_type_not_authorized_for_client}
  defp  client_grant_type_authorized?(client, :password) do
    :ok
  end

  @spec scope_param_valid?(String.t()) :: {:ok, Scope.Set.t()} | {:error, :malformed_scope_param}
  def scope_param_valid?(scope_param) do
    if Scope.oauth2_scope_param?(scope_param) do
      {:ok, Scope.Set.from_scope_param!(scope_param)}
    else
      {:error, :malformed_scope_param}
    end
  end

  @spec client_scope_authorized?(Client.t(), Scope.Set.t())
    :: :ok | {:error, :unauthorized_scope}
  def client_scope_authorized?(_, _), do: :ok
end
