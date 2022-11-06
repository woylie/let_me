defmodule MyApp.Blog.Article do
  @moduledoc """
  Schema module for articles, without the Ecto stuff.
  """

  use LetMe.Schema

  defstruct like_count: 25,
            title: "Give us back our moon dust and cockroaches",
            user_id: 1,
            view_count: 200

  @impl LetMe.Schema
  def scope(q, user, _) when is_atom(q), do: scope([module: q], user, nil)
  def scope(q, %{role: :admin}, _), do: q
  def scope(q, %{id: id}, _) when is_list(q), do: Keyword.put(q, :user_id, id)

  @impl LetMe.Schema
  def redacted_fields(_, %{role: :admin}), do: []
  def redacted_fields(%__MODULE__{user_id: id}, %{id: id}), do: [:view_count]
  def redacted_fields(_, %{}), do: [:like_count, :view_count]
end
