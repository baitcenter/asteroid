defmodule Asteroid.ObjectStore.RefreshToken.Riak do
  @moduledoc """
  Riak implementation of the `Asteroid.ObjectStore.RefreshToken` behaviour

  ## Initializing a Riak bucket type

  ```console
  $ sudo riak-admin bucket-type create token '{"props":{"datatype":"map", "backend":"bitcask_mult"}}'
  token created

  $ sudo riak-admin bucket-type activate token
  token has been activated
  ```

  ## Options
  The options (`Asteroid.ObjectStore.RefreshToken.opts()`) are:
  - `:bucket_type`: an `String.t()` for the bucket type that must be created beforehand in
  Riak. No defaults, **mandatory**
  - `bucket_name`: a `String.t()` for the bucket name. Defaults to `"refresh_token"`
  - `:purge_interval`: the `integer()` interval in seconds the purge process will be triggered,
  or `:no_purge` to disable purge. Defaults to `1200` (20 minutes)
  - `:rows`: the maximum number of results that a search will return. Defaults to `1_000_000`.
  Search is used by the purge process.

  ## Installation function

  The `install/1` function executes the following actions:
  - it installs a custom schema (`asteroid_object_store_refresh_token_riak_schema`)
  - it creates a new index (`asteroid_object_store_refresh_token_riak_index`) on the bucket
  (and not the bucket type - so as to avoid collisions)

  This is necessary to:
  1. Efficiently index expiration timestamp
  2. Disable indexing of raw refresh token data

  ## Purge process
  The purge process uses the `Singleton` library. Therefore the purge process will be unique
  per cluster (and that's probably what you want if you use Riak).

  """

  require Logger

  @behaviour Asteroid.ObjectStore.RefreshToken

  @impl true

  def install(opts) do
    bucket_type = opts[:bucket_type] || raise "Missing bucket type"
    bucket_name = opts[:bucket_name] || "refresh_token"

    with :ok <-
           Riak.Search.Schema.create(
             schema_name(),
             (:code.priv_dir(:asteroid) ++ '/riak/object_store_refresh_token_schema.xml')
             |> File.read!()
           ),
         :ok <- Riak.Search.Index.put(index_name(), schema_name()),
         :ok <- Riak.Search.Index.set({bucket_type, bucket_name}, index_name()) do
      Logger.info(
        "#{__MODULE__}: created refresh token store `#{bucket_name}` " <>
          "of bucket type `#{bucket_type}`"
      )

      :ok
    else
      e ->
        "#{__MODULE__}: failed to create refresh token store `#{bucket_name}` " <>
          "of bucket type `#{bucket_type}` (reason: #{inspect(e)})"

        {:error, "#{inspect(e)}"}
    end
  catch
    :exit, e ->
      bucket_type = opts[:bucket_type] || raise "Missing bucket type"
      bucket_name = opts[:bucket_name] || "refresh_token"

      "#{__MODULE__}: failed to create refresh token store `#{bucket_name}` " <>
        "of bucket type `#{bucket_type}` (reason: #{inspect(e)})"

      {:error, "#{inspect(e)}"}
  end

  @impl true

  def start_link(opts) do
    opts = Keyword.merge([purge_interval: 1200], opts)

    # we launch the process anyway because we need to return a process
    # but the singleton will do nothing if the value is `:no_purge`
    Singleton.start_child(__MODULE__.Purge, opts, __MODULE__)
  end

  @impl true

  def get(refresh_token_id, opts) do
    bucket_type = opts[:bucket_type] || raise "Missing bucket type"
    bucket_name = opts[:bucket_name] || "refresh_token"

    case Riak.find(bucket_type, bucket_name, refresh_token_id) do
      res when not is_nil(res) ->
        refresh_token =
          res
          |> Riak.CRDT.Map.get(:register, "refresh_token_data_binary")
          |> Base.decode64!(padding: false)
          |> :erlang.binary_to_term()

        Logger.debug(
          "#{__MODULE__}: getting refresh token `#{refresh_token_id}`, " <>
            "value: `#{inspect(refresh_token)}`"
        )

        {:ok, refresh_token}

      nil ->
        Logger.debug(
          "#{__MODULE__}: getting refresh token `#{refresh_token_id}`, " <> "value: `nil`"
        )

        {:ok, nil}
    end
  catch
    :exit, e ->
      {:error, "#{inspect(e)}"}
  end

  @impl true

  def get_from_subject_id(sub, opts) do
    search("sub_register:\"#{String.replace(sub, "\"", "\\\"")}\"", opts)
  end

  @impl true

  def get_from_client_id(client_id, opts) do
    search("client_id_register:\"#{String.replace(client_id, "\"", "\\\"")}\"", opts)
  end

  @impl true

  def get_from_device_id(device_id, opts) do
    search("device_id_register:\"#{String.replace(device_id, "\"", "\\\"")}\"", opts)
  end

  @impl true

  def get_from_authenticated_session_id(as_id, opts) do
    search("authenticated_session_id_register:\"#{String.replace(as_id, "\"", "\\\"")}\"", opts)
  end

  @impl true

  def put(refresh_token, opts) do
    bucket_type = opts[:bucket_type] || raise "Missing bucket type"
    bucket_name = opts[:bucket_name] || "refresh_token"

    riak_map = Riak.CRDT.Map.new()

    refresh_token_data_binary =
      refresh_token
      |> :erlang.term_to_binary()
      |> Base.encode64(padding: false)
      |> Riak.CRDT.Register.new()

    riak_map = Riak.CRDT.Map.put(riak_map, "refresh_token_data_binary", refresh_token_data_binary)

    riak_map =
      if refresh_token.data["exp"] != nil do
        Riak.CRDT.Map.put(
          riak_map,
          "exp_int",
          Riak.CRDT.Register.new(to_string(refresh_token.data["exp"]))
        )
      else
        Logger.warn(
          "Inserting refresh token with no expiration: #{String.slice(refresh_token.id, 1..5)}..."
        )

        riak_map
      end

    riak_map =
      if refresh_token.data["sub"] != nil do
        Riak.CRDT.Map.put(
          riak_map,
          "sub",
          Riak.CRDT.Register.new(to_string(refresh_token.data["sub"]))
        )
      else
        riak_map
      end

    riak_map =
      if refresh_token.data["client_id"] != nil do
        Riak.CRDT.Map.put(
          riak_map,
          "client_id",
          Riak.CRDT.Register.new(to_string(refresh_token.data["client_id"]))
        )
      else
        riak_map
      end

    riak_map =
      if refresh_token.data["device_id"] != nil do
        Riak.CRDT.Map.put(
          riak_map,
          "device_id",
          Riak.CRDT.Register.new(to_string(refresh_token.data["device_id"]))
        )
      else
        riak_map
      end

    riak_map =
      if refresh_token.data["authenticated_session_id"] != nil do
        Riak.CRDT.Map.put(
          riak_map,
          "authenticated_session_id",
          Riak.CRDT.Register.new(to_string(refresh_token.data["authenticated_session_id"]))
        )
      else
        riak_map
      end

    Riak.update(riak_map, bucket_type, bucket_name, refresh_token.id)

    Logger.debug(
      "#{__MODULE__}: stored refresh token `#{refresh_token.id}`, " <>
        "value: `#{inspect(refresh_token)}`"
    )

    :ok
  catch
    :exit, e ->
      {:error, "#{inspect(e)}"}
  end

  @impl true

  def delete(refresh_token_id, opts) do
    bucket_type = opts[:bucket_type] || raise "Missing bucket type"
    bucket_name = opts[:bucket_name] || "refresh_token"

    Riak.delete(bucket_type, bucket_name, refresh_token_id)

    Logger.debug("#{__MODULE__}: deleted refresh token `#{refresh_token_id}`")

    :ok
  catch
    :exit, e ->
      {:error, "#{inspect(e)}"}
  end

  @doc """
  Searches in Riak-stored refresh tokens

  This function is used internaly and made available for user convenience. Refresh tokens are
  stored in the following fields:

  |               Field name           |  Indexed as   |
  |------------------------------------|:-------------:|
  | refresh_token_data_binary_register | *not indexed* |
  | exp_int_register                   | int           |
  | sub_register                       | string        |
  | client_id_register                 | string        |
  | device_id_register                 | string        |
  | authenticated_session_id_register  | string        |

  Note that you are responsible for escaping values accordingly with Solr escaping.

  ## Example

  ```elixir
  iex(13)> Asteroid.ObjectStore.RefreshToken.Riak.search("sub_register:j* AND exp_int_register:[0 TO #{
    :os.system_time(:seconds)
  }]", opts)
  {:ok, ["7WRQL4EAKW27C5BEFF3JDGXBTA", "WCJBCL7SC2THS7TSRXB2KZH7OQ"]}
  ```
  """

  @spec search(String.t(), Asteroid.ObjectStore.RefreshToken.opts()) ::
          {:ok, [Asteroid.Token.RefreshToken.id()]}
          | {:error, any()}

  def search(search_query, opts) do
    case Riak.Search.query(index_name(), search_query, rows: opts[:rows] || 1_000_000) do
      {:ok, {:search_results, result_list, _, _}} ->
        {:ok,
         for {_index_name, attribute_list} <- result_list do
           :proplists.get_value("_yz_rk", attribute_list)
         end}

      {:error, _} = error ->
        error
    end
  end

  @spec schema_name() :: String.t()

  defp schema_name(), do: "asteroid_object_store_refresh_token_riak_schema"

  @doc false

  @spec index_name() :: String.t()

  def index_name(), do: "asteroid_object_store_refresh_token_riak_index"
end
