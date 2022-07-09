defmodule Expel do
  @moduledoc """
  Documentation for `Expel`.
  """

  alias Expel.Rule

  @doc """
  Takes a list of rules and a list of filter options and returns a filtered
  list of rules.

  ## Filter options

  - `:object` - Matches object exactly.
  - `:action` - Matches action exactly.
  - `:allow` - Either a check name as an atom or a 2-tuple with the check name
    and the options.
  - `:deny` - Either a check name as an atom or a 2-tuple with the check name
    and the options.

  If an atom is passed as `allow` or `deny`, the atom is interpreted as a check
  name and all rules using the given check name are returned, regardless of
  whether additional options are passed to the check. If a 2-tuple is passed,
  the first tuple element must be the check name as an atom and the second
  tuple element must be the check options. In this case, all rules are returned
  that use the given check with exactly the same options. In either case, rules
  that have more checks in addition to the given one will also be returned.

  ## Examples

      iex> rules = [
      ...>   %Expel.Rule{action: :create, object: :article},
      ...>   %Expel.Rule{action: :create, object: :category}
      ...> ]
      iex> filter_rules(rules, object: :article)
      [%Expel.Rule{action: :create, object: :article}]

      iex> rules = [
      ...>   %Expel.Rule{
      ...>     action: :create,
      ...>     object: :article,
      ...>     allow: [[role: :editor]]
      ...>   },
      ...>   %Expel.Rule{
      ...>     action: :update,
      ...>     object: :article,
      ...>     allow: [:own_resource, [role: :writer]]
      ...>   }
      ...> ]
      iex> filter_rules(rules, allow: :own_resource)
      [%Expel.Rule{action: :update, object: :article, allow: [:own_resource, [role: :writer]]}]
      iex> match?([_, _], filter_rules(rules, allow: :role))
      true
      iex> filter_rules(rules, allow: {:role, :editor})
      [%Expel.Rule{action: :create, object: :article, allow: [[role: :editor]]}]
      iex> filter_rules(rules, allow: {:role, :writer})
      [%Expel.Rule{action: :update, object: :article, allow: [:own_resource, [role: :writer]]}]
  """
  def filter_rules(rules, opts) when is_list(rules) do
    opts = Keyword.validate!(opts, [:action, :allow, :deny, :object])
    Enum.reduce(opts, rules, &do_filter_rules/2)
  end

  defp do_filter_rules({:action, action}, rules) when is_atom(action) do
    Enum.filter(rules, &(&1.action == action))
  end

  defp do_filter_rules({:allow, check}, rules) do
    Enum.filter(rules, fn %Rule{allow: allow} ->
      matches_check?(allow, check)
    end)
  end

  defp do_filter_rules({:deny, check}, rules) do
    Enum.filter(rules, fn
      %Rule{deny: deny} -> matches_check?(deny, check)
    end)
  end

  defp do_filter_rules({:object, object}, rules) when is_atom(object) do
    Enum.filter(rules, &(&1.object == object))
  end

  defp matches_check?(checks, check) when is_list(checks) do
    Enum.any?(checks, &matches_check?(&1, check))
  end

  defp matches_check?(check, check) when is_atom(check), do: true
  defp matches_check?({check, _}, check) when is_atom(check), do: true
  defp matches_check?({_, _}, check) when is_atom(check), do: false
  defp matches_check?(_, check) when is_atom(check), do: false

  defp matches_check?(check_with_opts, {name, _} = check_with_opts)
       when is_atom(name),
       do: true

  defp matches_check?(_, {name, _opts}) when is_atom(name), do: false
end
