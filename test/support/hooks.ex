defmodule LetMe.TestHooks do
  @moduledoc false

  def preload_handsomeness(%{} = subject, %{} = object, opts) do
    factor = Keyword.get(opts, :factor)
    bonus = Keyword.get(opts, :bonus, 0)
    {Map.put(subject, :handsomeness, subject.id * factor + bonus), object}
  end

  def preload_likeability(%{} = subject, %{} = object) do
    {Map.put(subject, :likeability, subject.id + 1), object}
  end

  def preload_likeability(%{} = subject, %{} = object, bonus: bonus) do
    {Map.put(subject, :likeability, subject.id + bonus), object}
  end
end
