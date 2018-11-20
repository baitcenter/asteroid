defmodule Asteroid.Store.AccessToken.Mnesia do
  @behaviour Asteroid.Store.AccessToken
  alias Asteroid.Token.AccessToken

  @impl Asteroid.Store.AccessToken
  def install() do
    :mnesia.create_table(:access_token, [
      attributes: [:id, :claims]
    ])
  end

  @impl Asteroid.Store.AccessToken
  def get(id) do
    {:atomic, [{:access_token, ^id, claims}]} =
      :mnesia.transaction(fn -> :mnesia.read(:access_token, id) end)

    %AccessToken{
      id: id,
      claims: claims
    }
  end

  @impl Asteroid.Store.AccessToken
  def put(access_token) do
    :mnesia.transaction(fn ->
      :mnesia.write({:access_token, access_token.id, access_token.claims})
    end)

    access_token
  end

  @impl Asteroid.Store.AccessToken
  def delete(id) do
    {:atomic, :ok} = :mnesia.transaction(fn -> :mnesia.delete({:access_token, id}) end)
  end
end
