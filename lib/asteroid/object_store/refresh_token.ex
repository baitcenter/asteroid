defmodule Asteroid.ObjectStore.RefreshToken do
  @moduledoc """
  Behaviour for refresh token store
  """

  @type opts :: Keyword.t()

  @doc """
  Installs the refresh token store
  """

  @callback install(opts()) :: :ok | {:error, any()}

  @doc """
  Starts the refresh token store (non supervised)
  """

  @callback start(opts()) :: :ok | {:error, any()}

  @doc """
  Starts the refresh token store (supervised)
  """

  @callback start_link(opts()) :: Supervisor.on_start()

  @doc """
  Returns an refresh token from its id

  Returns `{:ok, %Asteroid.Token.RefreshToken{}}` if the refresh token exists and `{:ok, nil}`
  otherwise.
  """

  @callback get(Asteroid.Token.RefreshToken.id(), opts()) ::
              {:ok, Asteroid.Token.RefreshToken.t() | nil}
              | {:error, any()}

  @doc """
  Returns all the *refresh token ids* of a subject
  """

  @callback get_from_subject_id(Asteroid.Subject.id(), opts()) ::
              {:ok, [Asteroid.Token.RefreshToken.id()]} | {:error, any()}

  @doc """
  Returns all the *refresh token ids* of a client
  """

  @callback get_from_client_id(Asteroid.Client.id(), opts()) ::
              {:ok, [Asteroid.Token.RefreshToken.id()]} | {:error, any()}

  @doc """
  Returns all the *refresh token ids* of a device
  """

  @callback get_from_device_id(Asteroid.Device.id(), opts()) ::
              {:ok, [Asteroid.Token.RefreshToken.id()]} | {:error, any()}

  @doc """
  Returns all the *refresh token ids* issued during an authenticated session

  This callback is made optionnal in case authenticated sessions are not used. If it is,
  this callback will be used and its implementation is therefore mandatory.
  """

  @callback get_from_authenticated_session_id(Asteroid.OIDC.AuthenticatedSession.id(), opts()) ::
              {:ok, [Asteroid.Token.RefreshToken.id()]} | {:error, any()}

  @doc """
  Stores an refresh token

  If the refresh token already exists, all of its data should be erased.
  """

  @callback put(Asteroid.Token.RefreshToken.t(), opts()) :: :ok | {:error, any()}

  @doc """
  Removes an refresh token
  """

  @callback delete(Asteroid.Token.RefreshToken.id(), opts()) :: :ok | {:error, any()}

  @optional_callbacks start: 1,
                      start_link: 1,
                      get_from_subject_id: 2,
                      get_from_client_id: 2,
                      get_from_device_id: 2,
                      get_from_authenticated_session_id: 2
end
