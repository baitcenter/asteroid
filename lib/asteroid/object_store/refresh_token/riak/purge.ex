defmodule Asteroid.ObjectStore.RefreshToken.Riak.Purge do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    if opts[:purge_interval] != :no_purge do
      Process.send_after(self(), :purge, opts[:purge_interval] * 1000)
    end

    {:ok, opts}
  end

  def handle_info(:purge, opts) do
    purge(opts)

    Process.send_after(self(), :purge, opts[:purge_interval] * 1000)

    {:noreply, opts}
  end

  defp purge(opts) do
    Logger.info("#{__MODULE__}: starting refresh token purge process on #{node()}")

    request = "exp_int_register:[0 TO #{:os.system_time(:second)}]"

    case Asteroid.ObjectStore.RefreshToken.Riak.search(request, opts) do
      {:ok, refresh_token_ids} ->
        for refresh_token_id <- refresh_token_ids do
          # this causes Riak connection exhaustion, to investigate further
          # Task.start(Asteroid.ObjectStore.RefreshToken.Riak,
          #           :delete,
          #           [refresh_token_id, opts, access_object_store_config])
          Asteroid.Token.RefreshToken.delete(refresh_token_id)
        end

        :ok

      {:error, _} = error ->
        Logger.warn(
          "#{__MODULE__}: purge process on #{node()} failed with error #{inspect(error)}"
        )
    end
  end
end
