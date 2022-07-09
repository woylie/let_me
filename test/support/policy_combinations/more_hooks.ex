defmodule MyApp.PolicyCombinations.MoreHooks do
  @moduledoc false

  def preload_handsomeness(%{} = subject, %{} = object, factor: factor) do
    {Map.put(subject, :handsomeness, subject.id * factor), object}
  end

  def preload_likeability(%{} = subject, %{} = object) do
    {Map.put(subject, :likeability, subject.id + 1), object}
  end
end
