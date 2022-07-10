defmodule MyApp.Blog.Article do
  @moduledoc """
  Schema module for articles, without the Ecto stuff.
  """

  use Expel.Schema

  defstruct like_count: 25,
            title: "Give us back our moon dust and cockroaches",
            user_id: 1,
            view_count: 200

  @impl Expel.Schema
  def scope(q, user) when is_atom(q), do: scope([module: q], user)
  def scope(q, %{role: :admin}), do: q
  def scope(q, %{id: id}) when is_list(q), do: Keyword.put(q, :user_id, id)

  @impl Expel.Schema
  def redacted_fields(_, %{role: :admin}), do: []
  def redacted_fields(%{user_id: id}, %{id: id}), do: [:view_count]
  def redacted_fields(_, %{}), do: [:like_count, :view_count]
end
