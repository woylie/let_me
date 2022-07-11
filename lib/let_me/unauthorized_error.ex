defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/3` if a request is unauthorized.
  """
  defexception message: "unauthorized"
end
