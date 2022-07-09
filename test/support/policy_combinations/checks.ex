defmodule MyApp.PolicyCombinations.Checks do
  @moduledoc false

  def own_resource(%{id: user_id}, %{user_id: user_id}), do: true
  def own_resource(_, _), do: false

  def role(%{role: role}, _, role), do: true
  def role(_, _, _), do: false

  def same_user(%{id: id}, %{id: id}), do: true
  def same_user(_, _), do: false
end
