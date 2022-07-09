defmodule Expel.UnauthorizedError do
  @moduledoc """
  Raised by `c:Expel.Policy.authorize!/3` if a request is unauthorized.
  """
  defexception [:message]
end
