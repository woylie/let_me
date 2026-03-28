defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/4` if a request is unauthorized.
  """
  @type t :: %__MODULE__{message: String.t()}

  defexception [:message]

  def message(exception) do
    exception.message || "unauthorized"
  end
end
