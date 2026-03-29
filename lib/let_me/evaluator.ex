defmodule LetMe.Evaluator do
  @moduledoc false

  def evaluate_conditions(conditions, check_module, subject, object) do
    Enum.reduce_while(
      conditions,
      {false, []},
      &condition_reducer(&1, &2, check_module, subject, object)
    )
  end

  def condition_reducer(checks, {_, acc}, check_module, subject, object) do
    case evaluate_checks(checks, check_module, subject, object) do
      {true, results} -> {:halt, {true, [results | acc]}}
      {false, results} -> {:cont, {false, [results | acc]}}
    end
  end

  defp evaluate_checks(checks, check_module, subject, object) do
    checks
    |> List.wrap()
    |> Enum.reduce_while(
      {false, []},
      &check_reducer(&1, &2, check_module, subject, object)
    )
  end

  defp check_reducer(check, {_, acc}, check_module, subject, object) do
    result = evaluate_check(check, check_module, subject, object)

    if to_boolean(result) do
      {:cont, {true, [{check, result} | acc]}}
    else
      {:halt, {false, [{check, result} | acc]}}
    end
  end

  defp evaluate_check(false, _, _, _) do
    false
  end

  defp evaluate_check(function, check_module, subject, object)
       when is_atom(function) do
    apply(check_module, function, [subject, object])
  end

  defp evaluate_check({function, opts}, check_module, subject, object)
       when is_atom(function) do
    apply(check_module, function, [subject, object, opts])
  end

  defp to_boolean(bool) when is_boolean(bool), do: bool
  defp to_boolean(:ok), do: true
  defp to_boolean({:ok, _}), do: true
  defp to_boolean(:error), do: false
  defp to_boolean({:error, _}), do: false
end
