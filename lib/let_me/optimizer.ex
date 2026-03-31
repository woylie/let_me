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

  def optimize(%AllOf{children: [_ | _] = children}) do
    {children, _} =
      Enum.reduce_while(children, {[], MapSet.new()}, fn child, {acc, seen} ->
        child = optimize(child)

        cond do
          # allof(A, false) = false
          literal_false?(child) -> {:halt, {false, nil}}
          # allof(A, B, true) = allof(A, B)
          literal_true?(child) -> {:cont, {acc, seen}}
          # allof(A, B, A) = allof(A, B) => skip duplicates
          MapSet.member?(seen, child) -> {:cont, {acc, seen}}
          # otherwise, add child to accumulator
          true -> {:cont, {[child | acc], MapSet.put(seen, child)}}
        end
      end)

    case children do
      # wrap false from first condition in reducer
      false -> %Literal{passed?: false}
      # allof(A) = A
      [child] -> child
      # allof() = true
      [] -> %Literal{passed?: true}
      # return new allof
      children -> %AllOf{children: Enum.reverse(children)}
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

  defp do_optimize_any_of(%AnyOf{children: children}) do
    {children, _} =
      Enum.reduce_while(
        children,
        {[], MapSet.new()},
        fn child, {acc, seen} ->
          child = optimize(child)

          cond do
            # anyof(A, true) = true
            literal_true?(child) -> {:halt, {true, nil}}
            # anyof(A, B, false) = anyof(A, B)
            literal_false?(child) -> {:cont, {acc, seen}}
            # anyOf(A, B, A) = anyof(A, B) => skip duplicates
            MapSet.member?(seen, child) -> {:cont, {acc, seen}}
            # otherwise, add child to accumulator
            true -> {:cont, {[child | acc], MapSet.put(seen, child)}}
          end
        end
      )

    case children do
      # wrap true from first condition in reducer
      true -> %Literal{passed?: true}
      # anyof(A) = A
      [child] -> child
      # anyof() = false
      [] -> %Literal{passed?: false}
      # return new anyof
      children -> %AnyOf{children: Enum.reverse(children)}
    end
  end

  defp literal_true?(%Literal{passed?: true}), do: true
  defp literal_true?(_), do: false

  defp literal_false?(%Literal{passed?: false}), do: true
  defp literal_false?(_), do: false

  defp factorize(%AnyOf{children: children} = any_of) do
    # find all AllOf children; only factorize if there is more than one
    {all_ofs, other} = Enum.split_with(children, &match?(%AllOf{}, &1))

    case all_ofs do
      [] ->
        any_of

      [_] ->
        any_of

      _ ->
        # find all children that are common among the AllOfs
        common_expressions = find_common_expressions(all_ofs)

        if MapSet.size(common_expressions) == 0 do
          any_of
        else
          # if there are common children, we can factorize
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

    # remove the common child expressions from all AllOfs
    factored_branches =
      Enum.map(all_ofs, fn %AllOf{children: children} ->
        case children -- common_expressions do
          # allof() = true
          [] -> %Literal{passed?: true}
          # allof(A) = A
          [child] -> child
          # if there is more than one child, build a new AllOf
          children -> %AllOf{children: children}
        end
      end)

    # (A and B) or (A and C) = A and (B or C)
    new_all_of = %AllOf{
      children: common_expressions ++ [%AnyOf{children: factored_branches}]
    }

    case other do
      # if there were no none-AllOf expressions in the original AnyOf, just
      # return the factorized AllOf expression
      [] -> new_all_of
      # if there were none-Allof expressions in the original AnyOf, wrap the
      # factorized AllOf expression and the remaining expressions in an AnyOf
      # (A and B) or (A and C) or D = (A and (B or C)) or D
      _ -> %AnyOf{children: [new_all_of | other]}
    end
  end
end
