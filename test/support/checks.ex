defmodule MyApp.Checks do
  @moduledoc false

  # checks

  def min_handsomeness(%{handsomeness: h}, _, min_h), do: h >= min_h

  def min_likeability(%{likeability: l}, _, min_l), do: l >= min_l

  def own_resource(%{id: user_id}, %{user_id: user_id}), do: true
  def own_resource(_, _), do: false

  def role(%{role: role}, _, role), do: true
  def role(_, _, _), do: false

  def same_group(%{group_id: id}, %{group_id: id}), do: true
  def same_group(%{group_id: _}, %{group_id: _}), do: false

  def same_pet(%{pet_id: id}, %{pet_id: id}), do: true
  def same_pet(%{pet_id: _}, %{pet_id: _}), do: false

  def same_user(%{id: id}, %{id: id}), do: true
  def same_user(_, _), do: false

  def has_valid_reason(_, %{reason: reason})
      when reason in ["valid", "also_valid"],
      do: true

  def has_valid_reason(_, _), do: false

  # Simulates an extarnal lookup
  def lookup_true(_, _) do
    :ets.update_counter(:lookups, :counter, {2, 1})
    true
  end

  def lookup_false(_, _) do
    :ets.update_counter(:lookups, :counter, {2, 1})
    false
  end

  # pre-hooks

  def preload_groups(%{} = subject, %{} = object) do
    {Map.put(subject, :group_id, 50), Map.put(object, :group_id, 50)}
  end

  def preload_groups(%{} = subject, %{} = object, opts) do
    group_id = Keyword.fetch!(opts, :group_id)

    {Map.put(subject, :group_id, group_id),
     Map.put(object, :group_id, group_id)}
  end

  def preload_pets(%{} = subject, %{} = object) do
    {Map.put(subject, :pet_id, 80), Map.put(object, :pet_id, 80)}
  end

  def preload_pets(%{} = subject, %{} = object, opts) do
    pet_id = Keyword.fetch!(opts, :pet_id)
    {Map.put(subject, :pet_id, pet_id), Map.put(object, :pet_id, pet_id)}
  end

  def add_reason_arg(%{} = subject, %{} = object, reason: reason) do
    {subject, %{object: object, reason: reason}}
  end
end
