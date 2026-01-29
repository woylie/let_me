defmodule LetMe.Builder do
  @moduledoc false

  def get_acc_attribute(module, name) do
    module
    |> Module.get_attribute(name, [])
    |> Enum.reverse()
  end

  def introspection_functions(%{} = rules) do
    quote do
      defp __rules__, do: unquote(Macro.escape(rules))

      @impl LetMe.Policy
      def list_rules, do: Map.values(__rules__())

      @impl LetMe.Policy
      def list_rules(opts), do: LetMe.filter_rules(list_rules(), opts)

      @impl LetMe.Policy
      def filter_allowed_actions(rules, subject, object) when is_list(rules) do
        LetMe.filter_allowed_actions(rules, subject, object, __MODULE__)
      end

      @impl LetMe.Policy
      def fetch_rule(action) when is_atom(action),
        do: Map.fetch(__rules__(), action)

      @impl LetMe.Policy
      def fetch_rule!(action) when is_atom(action),
        do: Map.fetch!(__rules__(), action)

      @impl LetMe.Policy
      def get_rule(action) when is_atom(action),
        do: Map.get(__rules__(), action)
    end
  end

  def schema_functions(schemas) when is_list(schemas) do
    schema_function_clauses =
      for {object_name, schema} <- schemas do
        quote do
          def get_schema(unquote(object_name)), do: unquote(schema)
        end
      end

    object_function_clauses =
      for {object_name, schema} <- schemas do
        quote do
          def get_object_name(unquote(schema)), do: unquote(object_name)
        end
      end

    quote do
      @impl LetMe.Policy
      unquote(schema_function_clauses)
      def get_schema(object_name) when is_atom(object_name), do: nil

      @impl LetMe.Policy
      unquote(object_function_clauses)
      def get_object_name(%schema{}), do: get_object_name(schema)
      def get_object_name(schema), do: nil
    end
  end

  def authorize_functions(%{} = rules, opts) do
    check_module = Keyword.fetch!(opts, :check_module)
    error_reason = Keyword.fetch!(opts, :error_reason)
    error_message = Keyword.fetch!(opts, :error_message)
    rule_clauses = Enum.map(rules, &permit_function_clause(&1, check_module))

    typespec =
      rules
      |> Map.keys()
      |> Enum.reduce(&{:|, [], [&1, &2]})

    quote do
      @typedoc """
      Valid actions to be passed to the various `authorize` functions. These are auto-generated
      from the defined policy rules.
      """
      @type action() :: unquote(typespec)

      @impl LetMe.Policy
      @spec authorize?(action(), any, any, keyword) :: boolean()
      def authorize?(action, subject, object \\ nil, opts \\ [])

      unquote(rule_clauses)

      def authorize?(action, _, _, _) when is_atom(action) do
        Logger.warning(
          "Permission checked for rule that does not exist: #{action}",
          action: action,
          policy_module: unquote(check_module)
        )

        false
      end

      @impl LetMe.Policy
      @spec authorize(action(), any, any, keyword) ::
              :ok | {:error, unquote(error_reason)}
      def authorize(action, subject, object \\ nil, opts \\ []) do
        if authorize?(action, subject, object, opts),
          do: :ok,
          else: {:error, unquote(error_reason)}
      end

      @impl LetMe.Policy
      @spec authorize!(action(), any, any, keyword) :: :ok
      def authorize!(action, subject, object \\ nil, opts \\ []) do
        if authorize?(action, subject, object, opts),
          do: :ok,
          else: raise(LetMe.UnauthorizedError, message: unquote(error_message))
      end

      defp evaluate_check(check) do
        case check do
          {mod, fun, args} when is_atom(fun) and is_list(args) ->
            apply(mod, fun, args)

          true ->
            true

          false ->
            false
        end
      end
    end
  end

  defp permit_function_clause(
         {rule_name, %LetMe.Rule{} = rule},
         check_module
       ) do
    pre_hook_calls = build_pre_hook_calls(rule.pre_hooks, check_module)
    allow_condition = build_conditions(rule.allow, check_module)
    deny_condition = build_conditions(rule.deny, check_module)

    # check for conditions that are always true or false to prevent
    # "this check/guard will always yield the same result" warning
    combined_condition =
      case {allow_condition, deny_condition} do
        {false, _} -> false
        {_, false} -> allow_condition
        _ -> quote(do: !unquote(deny_condition) && unquote(allow_condition))
      end

    quote do
      def authorize?(unquote(rule_name), subject, object, opts) do
        unquote(pre_hook_calls)
        unquote(combined_condition)
      end
    end
  end

  defp build_pre_hook_calls([], _), do: nil

  defp build_pre_hook_calls(pre_hooks, check_module)
       when is_list(pre_hooks) do
    functions =
      Enum.map(pre_hooks, fn
        pre_hook when is_atom(pre_hook) ->
          {check_module, pre_hook, []}

        {module, function} ->
          {module, function, []}

        {module, function, args} when is_list(args) ->
          {module, function, [args]}

        {_, _, args} ->
          raise ArgumentError, """
          Invalid pre-hook options

          Expected pre-hook options to be a keyword list, got:

              #{inspect(args)}
          """
      end)

    quote do
      {subject, object} =
        Enum.reduce(
          unquote(Macro.escape(functions)),
          {subject, object},
          fn {module, function, args}, {subject, object} ->
            args =
              args
              |> List.flatten()
              |> Keyword.merge(opts)
              |> case do
                [] -> []
                args -> [args]
              end

            apply(module, function, [subject, object] ++ args)
          end
        )
    end
  end

  defp build_conditions([], _), do: false

  defp build_conditions([checks], check_module) do
    quote do
      unquote(build_check(checks, check_module))
      |> then(&evaluate_check/1)
    end
  end

  defp build_conditions(conditions, check_module) when is_list(conditions) do
    quote do
      Enum.any?(
        unquote(Enum.map(conditions, &build_check(&1, check_module))),
        &evaluate_check/1
      )
    end
  end

  defp build_check([], _), do: false

  defp build_check([check], check_module) do
    build_check(check, check_module)
  end

  defp build_check(checks, check_module) when is_list(checks) do
    quote do
      Enum.all?(
        unquote(Enum.map(checks, &build_check(&1, check_module))),
        &evaluate_check/1
      )
    end
  end

  defp build_check(true, _) do
    quote do
      true
    end
  end

  defp build_check(false, _) do
    quote do
      false
    end
  end

  defp build_check(function, check_module) when is_atom(function) do
    quote do
      {unquote(check_module), unquote(function), [subject, object]}
    end
  end

  defp build_check({function, opts}, check_module)
       when is_atom(function) do
    quote do
      {unquote(check_module), unquote(function),
       [
         subject,
         object,
         unquote(opts)
       ]}
    end
  end
end
