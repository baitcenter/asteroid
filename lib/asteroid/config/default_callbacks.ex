defmodule Asteroid.Config.DefaultCallbacks do
  alias Asteroid.Subject

  @spec issuer(Asteroid.Context.t()) :: String.t()
  def issuer(_) do
    AsteroidWeb.Endpoint.url()
  end

  @spec test_ropc_username_password_callback(Plug.Conn.t(), String.t(), String.t())
    :: {:ok, Asteroid.Subject.t()} | {:error, atom()}
  def test_ropc_username_password_callback(_conn, _username, _password) do
    {:ok,
      %Subject{id: "11dcfa0a-80b4-4e82-9218-055f3fbcd6f0",
        claims: %{
          :name =>"John Doe",
          :given_name => "John",
          :family_name => "Smith"
        }}}
  end

  @spec refresh_token_lifetime_callback(Asteroid.Context.t()) :: non_neg_integer()
  def refresh_token_lifetime_callback(%Asteroid.Context{request: %{:flow => :ropc}}),
    do: Application.get_env(:asteroid, :refresh_token_lifetime_ropc)

  @spec access_token_lifetime_callback(Asteroid.Context.t()) :: non_neg_integer()
  def access_token_lifetime_callback(%Asteroid.Context{request: %{:flow => :ropc}}),
    do: Application.get_env(:asteroid, :access_token_lifetime_ropc)

  @spec id(any()) :: any()
  def id(param), do: param

  @spec id_first_param(any(), any()) :: any()
  def id_first_param(param, _), do: param
end
