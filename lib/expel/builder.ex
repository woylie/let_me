defmodule Expel.Builder do
  @moduledoc false

  def get_acc_attribute(module, name) do
    module
    |> Module.get_attribute(name, [])
    |> Enum.reverse()
  end
end
