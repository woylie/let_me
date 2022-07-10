defmodule Expel.Builder do
  @moduledoc false

  def get_acc_attribute(module, name) do
    module
    |> Module.get_attribute(name, [])
    |> Enum.reverse()
  end

  def introspection_functions(%{} = rules) do
    quote do
      defp __rules__, do: unquote(Macro.escape(rules))

      @impl Expel.Policy
      def list_rules, do: Map.values(__rules__())

      @impl Expel.Policy
      def list_rules(opts), do: Expel.filter_rules(list_rules(), opts)

      @impl Expel.Policy
      def fetch_rule(action) when is_atom(action),
        do: Map.fetch(__rules__(), action)

      @impl Expel.Policy
      def fetch_rule!(action) when is_atom(action),
        do: Map.fetch!(__rules__(), action)

      @impl Expel.Policy
      def get_rule(action) when is_atom(action),
        do: Map.get(__rules__(), action)
    end
  end

  def schema_functions(schemas) when is_list(schemas) do
    schemas = Enum.into(schemas, %{})

    quote do
      defp __schemas__, do: unquote(Macro.escape(schemas))

      @impl Expel.Policy
      def get_schema(object_name) when is_atom(object_name),
        do: Map.get(__schemas__(), object_name)
    end
  end

  def authorize_functions(%{} = rules, opts) do
    check_module = Keyword.fetch!(opts, :check_module)
    error_reason = Keyword.fetch!(opts, :error_reason)
    rule_clauses = Enum.map(rules, &permit_function_clause(&1, check_module))

    quote do
      @impl Expel.Policy
      def authorized?(action, subject, object \\ nil)

      unquote(rule_clauses)

      def authorized?(action, _, _) when is_atom(action) do
        Logger.warn(
          "Permission checked for rule that does not exist: #{action}",
          action: action,
          policy_module: unquote(check_module)
        )

        false
      end

      @impl Expel.Policy
      def authorize(action, subject, object \\ nil) do
        if authorized?(action, subject, object),
          do: :ok,
          else: {:error, unquote(error_reason)}
      end

      @impl Expel.Policy
      def authorize!(action, subject, object \\ nil) do
        if authorized?(action, subject, object),
          do: :ok,
          else: raise(Expel.UnauthorizedError)
      end
    end
  end

  defp permit_function_clause(
         {rule_name, %Expel.Rule{} = rule},
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
        {_, true} -> false
        {_, false} -> allow_condition
        {true, _} -> quote(do: !unquote(deny_condition))
        _ -> quote(do: !unquote(deny_condition) && unquote(allow_condition))
      end

    quote do
      def authorized?(unquote(rule_name), subject, object) do
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

        {module, function, args} ->
          {module, function, [args]}
      end)

    quote do
      {subject, object} =
        Enum.reduce(
          unquote(Macro.escape(functions)),
          {subject, object},
          fn {module, function, args}, {subject, object} ->
            apply(module, function, [subject, object] ++ args)
          end
        )
    end
  end

  defp build_conditions([], _), do: false

  defp build_conditions([checks], check_module) do
    build_check(checks, check_module)
  end

  defp build_conditions(conditions, check_module) when is_list(conditions) do
    quote do
      Enum.any?(unquote(Enum.map(conditions, &build_check(&1, check_module))))
    end
  end

  defp build_check([], _), do: false

  defp build_check([check], check_module) do
    build_check(check, check_module)
  end

  defp build_check(checks, check_module) when is_list(checks) do
    quote do
      Enum.all?(unquote(Enum.map(checks, &build_check(&1, check_module))))
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
      apply(unquote(check_module), unquote(function), [subject, object])
    end
  end

  defp build_check({function, opts}, check_module)
       when is_atom(function) do
    quote do
      apply(unquote(check_module), unquote(function), [
        subject,
        object,
        unquote(opts)
      ])
    end
  end
end
