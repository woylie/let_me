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
    error = Keyword.fetch!(opts, :error)

    authorize_clauses =
      Enum.map(rules, &authorize_function_clause(&1, check_module))

    authorize_acc_clauses =
      Enum.map(rules, &authorize_acc_function_clause(&1, check_module))

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

      unquote(authorize_clauses)

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
              :ok | {:error, LetMe.UnauthorizedError.t() | term}
      def authorize(action, subject, object \\ nil, opts \\ []) do
        case Keyword.pop(opts, :error, unquote(error)) do
          {:detailed, opts} ->
            case do_authorize(action, subject, object, opts) do
              %{passed?: true} ->
                :ok

              %{passed?: false} = expr ->
                {:error, LetMe.UnauthorizedError.with_expression(expr)}
            end

          {error_reason, opts} ->
            if authorize?(action, subject, object, opts) do
              :ok
            else
              {:error, error_reason}
            end
        end
      end

      @impl LetMe.Policy
      @spec authorize!(action(), any, any, keyword) :: :ok
      def authorize!(action, subject, object \\ nil, opts \\ []) do
        case do_authorize(action, subject, object, opts) do
          %{passed?: true} ->
            :ok

          %{passed?: false} = expr ->
            raise LetMe.UnauthorizedError.with_expression(expr)
        end
      end

      unquote(authorize_acc_clauses)

      defp do_authorize(action, _, _, _) when is_atom(action) do
        Logger.warning(
          "Permission checked for rule that does not exist: #{action}",
          action: action,
          policy_module: unquote(check_module)
        )

        %LetMe.Literal{passed?: false}
      end
    end
  end

  defp authorize_function_clause(
         {rule_name, %LetMe.Rule{expression: expression, pre_hooks: pre_hooks}},
         check_module
       ) do
    case expression do
      %LetMe.Literal{passed?: passed?} ->
        quote do
          def authorize?(unquote(rule_name), _, _, _) do
            unquote(passed?)
          end
        end

      expression ->
        pre_hook_calls = build_pre_hook_calls(pre_hooks, check_module)

        quote do
          def authorize?(unquote(rule_name), subject, object, opts) do
            unquote(pre_hook_calls)

            LetMe.Evaluator.evaluate_expression(
              unquote(Macro.escape(expression)),
              unquote(check_module),
              subject,
              object
            )
          end
        end
    end
  end

  defp authorize_acc_function_clause(
         {rule_name, %LetMe.Rule{expression: expression, pre_hooks: pre_hooks}},
         check_module
       ) do
    case expression do
      %LetMe.Literal{} = literal ->
        quote do
          defp do_authorize(unquote(rule_name), _, _, _) do
            unquote(Macro.escape(literal))
          end
        end

      expression ->
        pre_hook_calls = build_pre_hook_calls(pre_hooks, check_module)

        quote do
          defp do_authorize(unquote(rule_name), subject, object, opts) do
            unquote(pre_hook_calls)

            LetMe.Evaluator.evaluate_expression_acc(
              unquote(Macro.escape(expression)),
              unquote(check_module),
              subject,
              object
            )
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
end
