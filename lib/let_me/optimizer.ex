defmodule LetMe.Optimizer do
  @moduledoc false

  alias LetMe.AllOf
  alias LetMe.AnyOf
  alias LetMe.Check
  alias LetMe.Literal
  alias LetMe.Not

  def optimize(%Literal{} = literal) do
    literal
  end

  def optimize(%Check{} = check) do
    check
  end

  def optimize(%Not{expression: expression}) do
    case optimize(expression) do
      # not(not(expr)) == expr
      %Not{expression: expr} ->
        expr

      # not(true) == false, not(false) == true
      %Literal{passed?: bool} ->
        %Literal{passed?: not bool}

      # not (A and B) = (not A) or (not B)
      %AllOf{children: children} ->
        %AnyOf{children: Enum.map(children, &optimize(%Not{expression: &1}))}

      # not (A or B) = (not A) and (not B)
      %AnyOf{children: children} ->
        %AllOf{children: Enum.map(children, &optimize(%Not{expression: &1}))}

      # otherwise, not(expr)
      expr ->
        %Not{expression: expr}
    end
  end

  def optimize(%AllOf{children: []}) do
    %Literal{passed?: true}
  end

  def optimize(%AllOf{children: [child]}) do
    optimize(child)
  end

  def optimize(%AllOf{children: [_ | _] = children} = all_of) do
    {children, _} =
      Enum.reduce_while(children, {[], MapSet.new()}, fn child, {acc, seen} ->
        child = optimize(child)

        cond do
          literal_false?(child) -> {:halt, {false, nil}}
          literal_true?(child) -> {:cont, {acc, seen}}
          MapSet.member?(seen, child) -> {:cont, {acc, seen}}
          true -> {:cont, {[child | acc], MapSet.put(seen, child)}}
        end
      end)

    case children do
      false -> %Literal{passed?: false}
      [child] -> child
      [] -> %Literal{passed?: true}
      children -> %{all_of | children: Enum.reverse(children)}
    end
  end

  def optimize(%AnyOf{children: []}) do
    %Literal{passed?: false}
  end

  def optimize(%AnyOf{children: [child]}) do
    optimize(child)
  end

  def optimize(%AnyOf{children: [_ | _]} = any_of) do
    case factorize(any_of) do
      %AnyOf{} = any_of ->
        do_optimize_any_of(any_of)

      %AllOf{} = all_of ->
        optimize(all_of)
    end
  end

  defp do_optimize_any_of(%AnyOf{children: children} = any_of) do
    {children, _} =
      Enum.reduce_while(
        children,
        {[], MapSet.new()},
        fn child, {acc, seen} ->
          child = optimize(child)

          cond do
            literal_true?(child) -> {:halt, {true, nil}}
            literal_false?(child) -> {:cont, {acc, seen}}
            MapSet.member?(seen, child) -> {:cont, {acc, seen}}
            true -> {:cont, {[child | acc], MapSet.put(seen, child)}}
          end
        end
      )

    case children do
      true -> %Literal{passed?: true}
      [child] -> child
      [] -> %Literal{passed?: false}
      children -> %{any_of | children: Enum.reverse(children)}
    end
  end

  defp literal_true?(%Literal{passed?: true}), do: true
  defp literal_true?(_), do: false

  defp literal_false?(%Literal{passed?: false}), do: true
  defp literal_false?(_), do: false

  defp factorize(%AnyOf{children: children} = any_of) do
    {all_ofs, other} = Enum.split_with(children, &match?(%AllOf{}, &1))

    case all_ofs do
      [] ->
        any_of

      [_] ->
        any_of

      _ ->
        common_expressions = find_common_expressions(all_ofs)

        if MapSet.size(common_expressions) == 0 do
          any_of
        else
          do_factorize(all_ofs, other, common_expressions)
        end
    end
  end

  defp find_common_expressions(all_ofs) do
    all_ofs
    |> Enum.map(fn %AllOf{children: children} ->
      MapSet.new(children)
    end)
    |> Enum.reduce(&MapSet.intersection/2)
  end

  defp do_factorize(all_ofs, other, common_expressions) do
    common_expressions = MapSet.to_list(common_expressions)

    factored_branches =
      Enum.map(all_ofs, fn %AllOf{children: children} ->
        case children -- common_expressions do
          [] -> %Literal{passed?: false}
          [child] -> child
          children -> %AllOf{children: children}
        end
      end)

    new_all_of = %AllOf{
      children: common_expressions ++ [%AnyOf{children: factored_branches}]
    }

    case other do
      [] -> new_all_of
      _ -> %AnyOf{children: [new_all_of | other]}
    end
  end
end
