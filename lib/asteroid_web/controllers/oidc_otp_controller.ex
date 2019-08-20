defmodule AsteroidWeb.OIDCOTPController do
  use AsteroidWeb, :controller

  import Asteroid.Utils

  alias Asteroid.OIDC
  alias Asteroid.OIDC.{AuthenticatedSession, AuthenticationEvent}
  alias Asteroid.Subject
  alias AsteroidWeb.AuthorizeController.Request

  def index(conn, _params) do
    authz_request = get_session(conn, :authz_request)

    if authenticate?(conn, authz_request) do
      if authz_request.prompt == "none" do
        AsteroidWeb.AuthorizeController.authorization_denied(
          conn,
          %{
            authz_request: authz_request,
            error: OIDC.LoginRequiredError.exception(reason: "Login required")})
      else
        subject =
          get_session(conn, :subject)
          |> Subject.fetch_attributes(["email"])

        authentication_code =
          :io_lib.format("~6..0B", [:rand.uniform(1000000) - 1])
          |> to_string()

        AsteroidWeb.OTPEmail.otp_email(subject.attrs["email"], authentication_code)
        |> Asteroid.Mailer.deliver_later()

        conn
        |> put_session(:otp, authentication_code)
        |> put_status(200)
        |> render("form.html")
      end
    else
      conn
      |> redirect(to: "/oidc_authorize_scopes")
    end
  end

  def put(conn, %{"otp" => otp}) do
    if get_session(conn, :otp) == otp do
      {:ok, _} =
        get_session(conn, :authenticated_session_id)
        |> AuthenticationEvent.gen_new()
        |> AuthenticationEvent.put_value("name", "emailotp")
        |> AuthenticationEvent.put_value("amr", "otp")
        |> AuthenticationEvent.put_value("time", now())
        |> AuthenticationEvent.put_value("exp", now() + 60)
        |> AuthenticationEvent.store()

      conn
      |> redirect(to: "/oidc_authorize_scopes")
    else
      conn
      |> put_flash(:error, "Invalid authentication code")
      |> index(%{})
    end
  end

  def put(conn, _params) do
    conn
    |> put_flash(:error, "Invalid authentication code")
    |> index(%{})
  end

  @spec authenticate?(Plug.Conn.t(), Request.t()) :: boolean()

  defp authenticate?(_conn, %Request{prompt: "login"}) do
    true
  end

  defp authenticate?(conn, %Request{preferred_acr: "2-factor"} = authz_request) do
    case get_session(conn, :authenticated_session_id) do
      authenticated_session_id when is_binary(authenticated_session_id) ->
        case AuthenticatedSession.get(authenticated_session_id) do
          {:ok, authenticated_session} ->
            session_info =
              AuthenticatedSession.info(authenticated_session, authz_request.preferred_acr)

              "otp" not in (session_info[:amr] || []) or
              (
                authz_request.max_age != nil and
                authz_request.max_age < now() - session_info[:auth_time]
              )

          {:error, _} ->
            false
        end
        
      _ ->
        true
    end
  end

  defp authenticate?(_conn, _authz_request) do
    false
  end
end