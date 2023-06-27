defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/4` if a request is unauthorized.
  """
  defexception [:message]

  def message(exception) do
    exception.message || "unauthorized"
  end
end
