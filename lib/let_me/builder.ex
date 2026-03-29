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

  # credo:disable-for-next-line
  def authorize_functions(%{} = rules, opts) do
    check_module = Keyword.fetch!(opts, :check_module)
    rule_clauses = Enum.map(rules, &authorize_function_clause(&1, check_module))

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
      def authorize?(action, subject, object \\ nil, opts \\ []) do
        case do_authorize(action, subject, object, opts) do
          :ok -> true
          {:error, _, _} -> false
        end
      end

      @impl LetMe.Policy
      @spec authorize(action(), any, any, keyword) ::
              :ok | {:error, LetMe.UnauthorizedError.t()}
      def authorize(action, subject, object \\ nil, opts \\ []) do
        case do_authorize(action, subject, object, opts) do
          :ok ->
            :ok

          {:error, allow_checks, deny_checks} ->
            {:error, LetMe.UnauthorizedError.new(allow_checks, deny_checks)}
        end
      end

      @impl LetMe.Policy
      @spec authorize!(action(), any, any, keyword) :: :ok
      def authorize!(action, subject, object \\ nil, opts \\ []) do
        case do_authorize(action, subject, object, opts) do
          :ok ->
            :ok

          {:error, allow_checks, deny_checks} ->
            raise LetMe.UnauthorizedError.new(allow_checks, deny_checks)
        end
      end

      unquote(rule_clauses)

      defp do_authorize(action, _, _, _) when is_atom(action) do
        Logger.warning(
          "Permission checked for rule that does not exist: #{action}",
          action: action,
          policy_module: unquote(check_module)
        )

        {:error, [], []}
      end
    end
  end

  defp authorize_function_clause(
         {rule_name, %LetMe.Rule{} = rule},
         check_module
       ) do
    allow_condition = build_conditions(rule.allow, check_module)
    deny_condition = build_conditions(rule.deny, check_module)

    case combine_conditions(allow_condition, deny_condition) do
      true ->
        quote do
          defp do_authorize(unquote(rule_name), _, _, _) do
            :ok
          end
        end

      :deny_true ->
        quote do
          defp do_authorize(unquote(rule_name), _, _, _) do
            {:error, [], [[true]]}
          end
        end

      :allow_false ->
        quote do
          defp do_authorize(unquote(rule_name), _, _, _) do
            {:error, [[false]], []}
          end
        end

      combined_condition ->
        pre_hook_calls = build_pre_hook_calls(rule.pre_hooks, check_module)

        quote do
          defp do_authorize(unquote(rule_name), subject, object, opts) do
            unquote(pre_hook_calls)
            unquote(combined_condition)
          end
        end
    end
  end

  # allow false -> always unauthorized
  defp combine_conditions(false, _), do: :allow_false

  # deny true -> always unauthorized
  defp combine_conditions(_, true), do: :deny_true

  # allow true, deny false -> always authorized
  defp combine_conditions(true, false), do: true

  # allow true with deny checks -> only check deny conditions
  defp combine_conditions(true, deny_condition) do
    quote do
      case unquote(deny_condition) do
        {false, _} ->
          :ok

        {true, deny_checks} ->
          {:error, [], deny_checks}
      end
    end
  end

  # deny false with allow conditions -> only check allow conditions
  defp combine_conditions(allow_condition, false) do
    quote do
      case unquote(allow_condition) do
        {true, _} ->
          :ok

        {false, allow_checks} ->
          {:error, allow_checks, []}
      end
    end
  end

  defp combine_conditions(allow_condition, deny_condition) do
    quote do
      case unquote(deny_condition) do
        {true, deny_checks} ->
          {:error, [], deny_checks}

        {false, deny_checks} ->
          case unquote(allow_condition) do
            {true, _} ->
              :ok

            {false, allow_checks} ->
              {:error, allow_checks, deny_checks}
          end
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
          &LetMe.Builder.prehook_reducer(&1, &2, opts)
        )
    end
  end

  def prehook_reducer({module, function, args}, {subject, object}, opts) do
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

  defp build_conditions([], _), do: false

  defp build_conditions(conditions, check_module) when is_list(conditions) do
    conditions =
      conditions
      |> Enum.reject(&(&1 == []))
      |> Enum.map(&optimize_checks/1)

    cond do
      conditions == [] ->
        false

      Enum.any?(conditions, &(&1 == true)) ->
        true

      Enum.all?(conditions, &(&1 == false)) ->
        false

      true ->
        quote do
          LetMe.Evaluator.evaluate_conditions(
            unquote(conditions),
            unquote(check_module),
            subject,
            object
          )
        end
    end
  end

  defp optimize_checks([true]), do: true

  defp optimize_checks(checks) when is_list(checks) do
    # checks are combined with AND
    if Enum.any?(checks, &(&1 == false)) do
      # A AND false == false
      false
    else
      # A AND true == A
      Enum.reject(checks, &(&1 == true))
    end
  end

  defp optimize_checks(check) do
    check
  end
end
