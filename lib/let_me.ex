defmodule LetMe do
  @moduledoc """
  LetMe is library for defining and evaluating authorization rules and handling
  query scopes and field redactions.

  This module only defines auxiliary functions. The main functionality lies in
  the `LetMe.Policy` module.
  """

  alias LetMe.Rule

  @doc """
  Takes a list of rules and a list of filter options and returns a filtered
  list of rules.

  This function is used by `c:LetMe.Policy.list_rules/1`.

  ## Filter options

  - `:object` - Matches an object exactly.
  - `:action` - Matches an action exactly.
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
      ...>   %LetMe.Rule{action: :create, name: :article_create, object: :article},
      ...>   %LetMe.Rule{action: :create, name: :category_create, object: :category}
      ...> ]
      iex> filter_rules(rules, object: :article)
      [%LetMe.Rule{action: :create, name: :article_create, object: :article}]

      iex> rules = [
      ...>   %LetMe.Rule{
      ...>     action: :create,
      ...>     name: :article_create,
      ...>     object: :article,
      ...>     allow: [[role: :editor]]
      ...>   },
      ...>   %LetMe.Rule{
      ...>     action: :update,
      ...>     name: :article_update,
      ...>     object: :article,
      ...>     allow: [:own_resource, [role: :writer]]
      ...>   }
      ...> ]
      iex> filter_rules(rules, allow: :own_resource)
      [%LetMe.Rule{action: :update, name: :article_update, object: :article, allow: [:own_resource, [role: :writer]]}]
      iex> match?([_, _], filter_rules(rules, allow: :role))
      true
      iex> filter_rules(rules, allow: {:role, :editor})
      [%LetMe.Rule{action: :create, name: :article_create, object: :article, allow: [[role: :editor]]}]
      iex> filter_rules(rules, allow: {:role, :writer})
      [%LetMe.Rule{action: :update, name: :article_update, object: :article, allow: [:own_resource, [role: :writer]]}]
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

  @doc """
  Takes a struct or a list of structs and redacts fields depending on the
  subject (user).

  Uses the callback implementation for `c:LetMe.Schema.redacted_fields/2` in the
  struct module.

  ## Options

  - `:redact_value` - The value to be used for redacted fields. Defaults to
    `:redacted`.

  ## Example

      iex> article = %MyApp.Blog.Article{}
      iex> user = %{id: 2, role: :user}
      iex> redact(article, user)
      %MyApp.Blog.Article{like_count: :redacted, title: "Give us back our moon dust and cockroaches", user_id: 1, view_count: :redacted}

      iex> article = %MyApp.Blog.Article{}
      iex> user = %{id: 2, role: :user}
      iex> redact(article, user, redact_value: nil)
      %MyApp.Blog.Article{like_count: nil, title: "Give us back our moon dust and cockroaches", user_id: 1, view_count: nil}

      iex> articles = [
      ...>   %MyApp.Blog.Article{},
      ...>   %MyApp.Blog.Article{user_id: 2, title: "Joey Chestnut is chomp champ"}
      ...> ]
      iex> user = %{id: 2, role: :user}
      iex> redact(articles, user)
      [%MyApp.Blog.Article{like_count: :redacted, title: "Give us back our moon dust and cockroaches", user_id: 1, view_count: :redacted}, %MyApp.Blog.Article{like_count: 25, title: "Joey Chestnut is chomp champ", user_id: 2, view_count: :redacted}]
  """
  @spec redact(struct, any, keyword) :: struct
  @spec redact([struct], any, keyword) :: [struct]
  @spec redact(nil, any, keyword) :: nil
  def redact(struct, subject, opts \\ [redact_value: :redacted])

  def redact(objects, subject, opts) when is_list(objects) do
    redact_value = Keyword.fetch!(opts, :redact_value)
    Enum.map(objects, &do_redact(&1, subject, redact_value))
  end

  def redact(nil, _, _), do: nil

  def redact(object, subject, opts) do
    redact_value = Keyword.fetch!(opts, :redact_value)
    do_redact(object, subject, redact_value)
  end

  defp do_redact(%module{} = object, subject, redact_value) do
    redacted_fields = module.redacted_fields(object, subject)
    replace_keys(redacted_fields, redact_value, object)
  end

  defp replace_keys([], _, acc), do: acc

  defp replace_keys([key | rest], value, acc) do
    replace_keys(rest, value, Map.put(acc, key, value))
  end

  @doc """
  Removes redacted fields from a given list of fields.

  Uses the `c:LetMe.Schema.redacted_fields/2` callback implementation of the
  struct module to determine the fields to remove.

  ## Examples

      iex> fields = [:like_count, :title, :user_id, :view_count]
      iex> user = %{id: 1, role: :user}
      iex> article = %MyApp.Blog.Article{}
      iex> reject_redacted_fields(fields, article, user)
      [:title, :user_id]

  This can be useful as a safeguard to prevent accidentally casting fields the
  user is not allowed to see and thereby nilifying or replacing them.

      def update_changeset(%Article{} = article, attrs, %User{} = user) do
        fields = LetMe.reject_redacted_fields(
          [:title, :body, :internal_reference],
          article,
          user
        )

        article
        |> cast(attrs, fields)
        |> validate_required([:title, :body])
      end
  """
  @spec reject_redacted_fields([atom], struct, any) :: [atom]
  def reject_redacted_fields(fields, %schema{} = object, subject) do
    redacted_fields = subject |> schema.redacted_fields(object) |> MapSet.new()

    fields
    |> MapSet.new()
    |> MapSet.difference(redacted_fields)
    |> MapSet.to_list()
  end
end
