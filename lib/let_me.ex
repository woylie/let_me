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
  - `:metadata` - Either a metadata name as an atom or a 2-tuple with the
    metadata name and the metadata value.
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
    opts = Keyword.validate!(opts, [:action, :allow, :deny, :metadata, :object])
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

  defp do_filter_rules({:metadata, metadata_filter}, rules) do
    Enum.filter(rules, fn
      %Rule{metadata: metadata} -> matches_check?(metadata, metadata_filter)
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
  Takes a list of rules and only returns the rules that would evaluate to `true`
  for the given subject and object.

  The object needs to be passed as a tuple, where the first element is the
  object name, and the second element is the actual object, e.g.
  `{:article, %Article{}}`.

  This function is used internally by `c:LetMe.Policy.filter_allowed_actions/3`.

  ## Example

      rules = MyApp.Policy.list_rules()

      filter_allowed_actions(
        rules,
        %User{},
        {:article, %Article{}},
        MyApp.Policy
      )
  """
  @spec filter_allowed_actions([LetMe.Rule.t()], subject, object, module) :: [
          LetMe.Rule.t()
        ]
        when subject: any, object: {atom, any} | struct
  def filter_allowed_actions(rules, subject, {object_name, object}, policy)
      when is_list(rules) and is_atom(object_name) do
    rules
    |> LetMe.filter_rules(object: object_name)
    |> Enum.reduce([], fn %LetMe.Rule{name: name} = rule, acc ->
      if policy.authorize?(name, subject, object),
        do: [rule | acc],
        else: acc
    end)
    |> Enum.reverse()
  end

  def filter_allowed_actions(rules, subject, %_{} = object, policy) do
    object_name = policy.get_object_name(object)
    filter_allowed_actions(rules, subject, {object_name, object}, policy)
  end

  @doc """
  Takes a struct or a list of structs and redacts fields depending on the
  subject (user).

  Uses the callback implementation for `c:LetMe.Schema.redacted_fields/3` in the
  struct module.

  ## Options

  - `:redact_value` - The value to be used for redacted fields. Defaults to
    `:redacted`.

  Any additional options will be passed to `c:LetMe.Schema.redacted_fields/3`.

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
  def redact(struct, subject, opts \\ [])

  def redact(objects, subject, opts) when is_list(objects) do
    {redact_value, opts} = Keyword.pop(opts, :redact_value, :redacted)
    Enum.map(objects, &do_redact(&1, subject, redact_value, opts))
  end

  def redact(nil, _, _), do: nil

  def redact(object, subject, opts) do
    {redact_value, opts} = Keyword.pop(opts, :redact_value, :redacted)
    do_redact(object, subject, redact_value, opts)
  end

  defp do_redact(%module{} = object, subject, redact_value, opts) do
    redacted_fields = module.redacted_fields(object, subject, opts)
    replace_keys(redacted_fields, subject, redact_value, object, opts)
  end

  defp replace_keys([], _, _, acc, _), do: acc

  defp replace_keys(
         [{key, nested_redacted_fields} | rest],
         subject,
         value,
         acc,
         opts
       )
       when is_atom(key) and is_list(nested_redacted_fields) do
    case Map.get(acc, key) do
      nil ->
        replace_keys(rest, subject, value, acc, opts)

      %{__struct__: Ecto.Association.NotLoaded} ->
        replace_keys(rest, subject, value, acc, opts)

      %{} = nested_map ->
        replace_keys(
          rest,
          subject,
          value,
          Map.put(
            acc,
            key,
            replace_keys(
              nested_redacted_fields,
              subject,
              value,
              nested_map,
              opts
            )
          ),
          opts
        )
    end
  end

  defp replace_keys([{key, module} | rest], subject, value, acc, opts)
       when is_atom(key) and is_atom(module) do
    case Map.get(acc, key) do
      nil ->
        replace_keys(rest, subject, value, acc, opts)

      %{__struct__: Ecto.Association.NotLoaded} ->
        replace_keys(rest, subject, value, acc, opts)

      %^module{} = nested_map ->
        replace_keys(
          rest,
          subject,
          value,
          Map.put(
            acc,
            key,
            do_redact(nested_map, subject, value, opts)
          ),
          opts
        )
    end
  end

  defp replace_keys([key | rest], subject, value, acc, opts)
       when is_atom(key) do
    replace_keys(rest, subject, value, Map.put(acc, key, value), opts)
  end

  @doc """
  Removes redacted fields from a given list of fields.

  Uses the `c:LetMe.Schema.redacted_fields/3` callback implementation of the
  struct module to determine the fields to remove.

  ## Examples

      iex> fields = [:like_count, :title, :user_id, :view_count]
      iex> user = %{id: 1, role: :user}
      iex> article = %MyApp.Blog.Article{}
      iex> reject_redacted_fields(fields, article, user)
      [:like_count, :title, :user_id]

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

  If a keyword list is given as a fourth argument, it is passed to
  `c:LetMe.Schema.redacted_fields/3`.
  """
  @spec reject_redacted_fields([atom], struct, any, keyword) :: [atom]
  def reject_redacted_fields(fields, %schema{} = object, subject, opts \\ [])
      when is_list(opts) do
    redacted_fields =
      object
      |> schema.redacted_fields(subject, opts)
      |> MapSet.new()

    fields
    |> MapSet.new()
    |> MapSet.difference(redacted_fields)
    |> MapSet.to_list()
  end
end
