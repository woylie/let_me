defmodule LetMe.Evaluator do
  @moduledoc false

  alias LetMe.AllOf
  alias LetMe.AnyOf
  alias LetMe.Check
  alias LetMe.Literal
  alias LetMe.Not

  ## non-accumulating

  def evaluate_expression(expr, check_module, subject, object \\ nil)

  def evaluate_expression(%Literal{passed?: passed?}, _, _, _) do
    passed?
  end

  def evaluate_expression(
        %Check{name: fun, arg: nil},
        check_module,
        subject,
        object
      ) do
    check_module
    |> apply(fun, [subject, object])
    |> to_boolean()
  end

  def evaluate_expression(
        %Check{name: fun, arg: arg},
        check_module,
        subject,
        object
      ) do
    check_module
    |> apply(fun, [subject, object, arg])
    |> to_boolean()
  end

  def evaluate_expression(
        %Not{expression: expression},
        check_module,
        subject,
        object
      ) do
    not evaluate_expression(expression, check_module, subject, object)
  end

  def evaluate_expression(
        %AllOf{children: children},
        check_module,
        subject,
        object
      ) do
    Enum.all?(children, &evaluate_expression(&1, check_module, subject, object))
  end

  def evaluate_expression(
        %AnyOf{children: children},
        check_module,
        subject,
        object
      ) do
    Enum.any?(children, &evaluate_expression(&1, check_module, subject, object))
  end

  ## accumulating

  def evaluate_expression_acc(expr, check_module, subject, object \\ nil)

  def evaluate_expression_acc(%Literal{} = literal, _, _, _) do
    literal
  end

  def evaluate_expression_acc(
        %Check{name: fun, arg: nil} = check,
        check_module,
        subject,
        object
      ) do
    result = apply(check_module, fun, [subject, object])
    %{check | result: result, passed?: to_boolean(result)}
  end

  def evaluate_expression_acc(
        %Check{name: fun, arg: arg} = check,
        check_module,
        subject,
        object
      ) do
    result = apply(check_module, fun, [subject, object, arg])
    %{check | result: result, passed?: to_boolean(result)}
  end

  def evaluate_expression_acc(
        %Not{expression: expression} = not_expr,
        check_module,
        subject,
        object
      ) do
    evaluated_expression =
      evaluate_expression_acc(expression, check_module, subject, object)

    %{
      not_expr
      | expression: evaluated_expression,
        passed?: not evaluated_expression.passed?
    }
  end

  def evaluate_expression_acc(
        %AllOf{children: children} = all_of,
        check_module,
        subject,
        object
      ) do
    {passed?, evaluated_children} =
      Enum.reduce_while(
        children,
        {true, []},
        &all_of_reducer(&1, &2, check_module, subject, object)
      )

    %{all_of | passed?: passed?, children: Enum.reverse(evaluated_children)}
  end

  def evaluate_expression_acc(
        %AnyOf{children: children} = any_of,
        check_module,
        subject,
        object
      ) do
    {passed?, evaluated_children} =
      Enum.reduce_while(
        children,
        {false, []},
        &any_of_reducer(&1, &2, check_module, subject, object)
      )

    %{any_of | passed?: passed?, children: Enum.reverse(evaluated_children)}
  end

  defp all_of_reducer(expression, {_, acc}, check_module, subject, object) do
    case evaluate_expression_acc(expression, check_module, subject, object) do
      %{passed?: true} = expr -> {:cont, {true, [expr | acc]}}
      %{passed?: false} = expr -> {:halt, {false, [expr | acc]}}
    end
  end

  defp any_of_reducer(expression, {_, acc}, check_module, subject, object) do
    case evaluate_expression_acc(expression, check_module, subject, object) do
      %{passed?: true} = expr -> {:halt, {true, [expr | acc]}}
      %{passed?: false} = expr -> {:cont, {false, [expr | acc]}}
    end
  end

  defp to_boolean(bool) when is_boolean(bool), do: bool
  defp to_boolean(:ok), do: true
  defp to_boolean({:ok, _}), do: true
  defp to_boolean(:error), do: false
  defp to_boolean({:error, _}), do: false
end
