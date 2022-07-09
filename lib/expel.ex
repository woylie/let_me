defmodule Expel do
  @moduledoc """
  Documentation for `Expel`.
  """

  @doc """
  Takes a list of rules and a list of filter options and returns a filtered
  list of rules.

  ## Example

      iex> rules = [
      ...>   %Expel.Rule{action: :create, object: :article},
      ...>   %Expel.Rule{action: :create, object: :category}
      ...> ]
      iex> filter_rules(rules, object: :article)
      [%Expel.Rule{action: :create, object: :article}]

  ## Filter options

  - `:object`
  - `:action`
  """
  def filter_rules(rules, opts) when is_list(rules) do
    opts = Keyword.validate!(opts, [:action, :object])
    Enum.reduce(opts, rules, &do_filter_rules/2)
  end

  defp do_filter_rules({:object, object}, rules) when is_atom(object) do
    Enum.filter(rules, &(&1.object == object))
  end

  defp do_filter_rules({:action, action}, rules) when is_atom(action) do
    Enum.filter(rules, &(&1.action == action))
  end
end
