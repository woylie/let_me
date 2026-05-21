defmodule LetMe.EvaluatorTest do
  use ExUnit.Case, async: true

  alias __MODULE__.Checks
  alias LetMe.Check
  alias LetMe.Evaluator
  alias LetMe.Literal
  alias Spek.AllOf
  alias Spek.AnyOf
  alias Spek.Not

  defmodule Checks do
    def own_resource(%{id: user_id}, %{user_id: user_id}), do: true
    def own_resource(_, _), do: false

    def role(%{role: role}, _, role), do: true
    def role(_, _, _), do: false

    def return_arg(_, _, arg), do: arg
    def return_object(_, object), do: object
  end

  def subject(opts \\ []) do
    [id: "sid"]
    |> Keyword.merge(opts)
    |> Map.new()
  end

  def object(opts \\ []) do
    [id: "sid"]
    |> Keyword.merge(opts)
    |> Map.new()
  end

  describe "evaluate_expression/4" do
    test "evaluates literal" do
      assert Evaluator.evaluate_expression(
               %Literal{satisfied?: true},
               Checks,
               subject()
             ) == true

      assert Evaluator.evaluate_expression(
               %Literal{satisfied?: false},
               Checks,
               subject()
             ) == false
    end

    test "evaluates check without arg" do
      assert Evaluator.evaluate_expression(
               %Check{name: :own_resource},
               Checks,
               subject(),
               object(user_id: "sid")
             ) == true

      assert Evaluator.evaluate_expression(
               %Check{name: :own_resource},
               Checks,
               subject(),
               object(user_id: "dis")
             ) == false
    end

    test "evaluates check without arg that returns no boolean" do
      test_cases = [
        # check return value, expected result
        {:ok, true},
        {:error, false},
        {{:ok, "msg"}, true},
        {{:error, "msg"}, false}
      ]

      for {value, expected_result} <- test_cases do
        assert Evaluator.evaluate_expression(
                 %Check{name: :return_object},
                 Checks,
                 subject(),
                 # check function always returns object
                 value
               ) == expected_result
      end
    end

    test "evaluates check with arg" do
      assert Evaluator.evaluate_expression(
               %Check{name: :role, arg: :admin},
               Checks,
               subject(role: :admin)
             ) == true

      assert Evaluator.evaluate_expression(
               %Check{name: :role, arg: :admin},
               Checks,
               subject(role: :editor)
             ) == false
    end

    test "evaluates check with arg that returns no boolean" do
      test_cases = [
        # check return value, expected result
        {:ok, true},
        {:error, false},
        {{:ok, "msg"}, true},
        {{:error, "msg"}, false}
      ]

      for {value, expected_result} <- test_cases do
        assert Evaluator.evaluate_expression(
                 # check always returns the arg
                 %Check{name: :return_arg, arg: value},
                 Checks,
                 subject()
               ) == expected_result
      end
    end

    test "evaluates not" do
      assert Evaluator.evaluate_expression(
               %Not{expression: %Literal{satisfied?: true}},
               Checks,
               subject()
             ) == false

      assert Evaluator.evaluate_expression(
               %Not{expression: %Literal{satisfied?: false}},
               Checks,
               subject()
             ) == true
    end

    test "evaluates AllOf without children" do
      assert Evaluator.evaluate_expression(
               %AllOf{children: []},
               Checks,
               subject()
             ) == true
    end

    test "evaluates AllOf with one child" do
      assert Evaluator.evaluate_expression(
               %AllOf{children: [%Literal{satisfied?: true}]},
               Checks,
               subject()
             ) == true

      assert Evaluator.evaluate_expression(
               %AllOf{children: [%Literal{satisfied?: false}]},
               Checks,
               subject()
             ) == false
    end

    test "evaluates AllOf with two children" do
      test_cases = [
        # first child, second child, expected result
        {true, true, true},
        {true, false, false},
        {false, true, false},
        {false, false, false}
      ]

      for {v1, v2, expected} <- test_cases do
        assert Evaluator.evaluate_expression(
                 %AllOf{
                   children: [
                     %Literal{satisfied?: v1},
                     %Literal{satisfied?: v2}
                   ]
                 },
                 Checks,
                 subject()
               ) == expected
      end
    end

    test "evaluates AnyOf without children" do
      assert Evaluator.evaluate_expression(
               %AnyOf{children: []},
               Checks,
               subject()
             ) == false
    end

    test "evaluates AnyOf with one child" do
      assert Evaluator.evaluate_expression(
               %AnyOf{children: [%Literal{satisfied?: true}]},
               Checks,
               subject()
             ) == true

      assert Evaluator.evaluate_expression(
               %AnyOf{children: [%Literal{satisfied?: false}]},
               Checks,
               subject()
             ) == false
    end

    test "evaluates AnyOf with two children" do
      test_cases = [
        # first child, second child, expected result
        {true, true, true},
        {true, false, true},
        {false, true, true},
        {false, false, false}
      ]

      for {v1, v2, expected} <- test_cases do
        assert Evaluator.evaluate_expression(
                 %AnyOf{
                   children: [
                     %Literal{satisfied?: v1},
                     %Literal{satisfied?: v2}
                   ]
                 },
                 Checks,
                 subject()
               ) == expected
      end
    end
  end

  describe "evaluate_expression_acc/4" do
    test "evaluates literal" do
      assert Evaluator.evaluate_expression_acc(
               %Literal{satisfied?: true},
               Checks,
               subject()
             ) == %Literal{satisfied?: true}

      assert Evaluator.evaluate_expression_acc(
               %Literal{satisfied?: false},
               Checks,
               subject()
             ) == %Literal{satisfied?: false}
    end

    test "evaluates check without arg" do
      assert Evaluator.evaluate_expression_acc(
               %Check{name: :own_resource},
               Checks,
               subject(),
               object(user_id: "sid")
             ) == %Check{name: :own_resource, satisfied?: true, result: true}

      assert Evaluator.evaluate_expression_acc(
               %Check{name: :own_resource},
               Checks,
               subject(),
               object(user_id: "dis")
             ) == %Check{name: :own_resource, satisfied?: false, result: false}
    end

    test "evaluates check without arg that returns no boolean" do
      test_cases = [
        # check return value, expected result
        {:ok, true},
        {:error, false},
        {{:ok, "msg"}, true},
        {{:error, "msg"}, false}
      ]

      for {value, expected_result} <- test_cases do
        assert Evaluator.evaluate_expression_acc(
                 %Check{name: :return_object},
                 Checks,
                 subject(),
                 # check function always returns object
                 value
               ) == %Check{
                 name: :return_object,
                 satisfied?: expected_result,
                 result: value
               }
      end
    end

    test "evaluates check with arg" do
      assert Evaluator.evaluate_expression_acc(
               %Check{name: :role, arg: :admin},
               Checks,
               subject(role: :admin)
             ) == %Check{
               name: :role,
               arg: :admin,
               satisfied?: true,
               result: true
             }

      assert Evaluator.evaluate_expression_acc(
               %Check{name: :role, arg: :admin},
               Checks,
               subject(role: :editor)
             ) == %Check{
               name: :role,
               arg: :admin,
               satisfied?: false,
               result: false
             }
    end

    test "evaluates check with arg that returns no boolean" do
      test_cases = [
        # check return value, expected result
        {:ok, true},
        {:error, false},
        {{:ok, "msg"}, true},
        {{:error, "msg"}, false}
      ]

      for {value, expected_result} <- test_cases do
        assert Evaluator.evaluate_expression_acc(
                 # check always returns the arg
                 %Check{name: :return_arg, arg: value},
                 Checks,
                 subject()
               ) == %Check{
                 name: :return_arg,
                 arg: value,
                 satisfied?: expected_result,
                 result: value
               }
      end
    end

    test "evaluates not with literal" do
      assert Evaluator.evaluate_expression_acc(
               %Not{expression: %Literal{satisfied?: true}},
               Checks,
               subject()
             ) == %Not{
               expression: %Literal{satisfied?: true},
               satisfied?: false
             }

      assert Evaluator.evaluate_expression_acc(
               %Not{expression: %Literal{satisfied?: false}},
               Checks,
               subject()
             ) == %Not{
               expression: %Literal{satisfied?: false},
               satisfied?: true
             }
    end

    test "evaluates not with check" do
      assert Evaluator.evaluate_expression_acc(
               %Not{expression: %Check{name: :role, arg: :admin}},
               Checks,
               subject(role: :admin)
             ) == %Not{
               expression: %Check{
                 satisfied?: true,
                 arg: :admin,
                 name: :role,
                 result: true
               },
               satisfied?: false
             }

      assert Evaluator.evaluate_expression_acc(
               %Not{expression: %Check{name: :role, arg: :admin}},
               Checks,
               subject(role: :editor)
             ) == %Not{
               expression: %Check{
                 satisfied?: false,
                 arg: :admin,
                 name: :role,
                 result: false
               },
               satisfied?: true
             }
    end

    test "evaluates AllOf without children" do
      assert Evaluator.evaluate_expression_acc(
               %AllOf{children: []},
               Checks,
               subject()
             ) == %AllOf{children: [], satisfied?: true}
    end

    test "evaluates AllOf with one child" do
      assert Evaluator.evaluate_expression_acc(
               %AllOf{children: [%Check{name: :role, arg: :admin}]},
               Checks,
               subject(role: :admin)
             ) == %AllOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(
               %AllOf{children: [%Check{name: :role, arg: :admin}]},
               Checks,
               subject(role: :editor)
             ) == %AllOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end

    test "evaluates AllOf with two children" do
      # all checks true
      assert Evaluator.evaluate_expression_acc(
               %AllOf{
                 children: [
                   %Check{name: :role, arg: :admin},
                   %Check{name: :own_resource}
                 ]
               },
               Checks,
               subject(role: :admin),
               object(user_id: "sid")
             ) == %AllOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: true,
                   satisfied?: true
                 },
                 %Check{
                   name: :own_resource,
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      # first check true, second check false
      assert Evaluator.evaluate_expression_acc(
               %AllOf{
                 children: [
                   %Check{name: :role, arg: :admin},
                   %Check{name: :own_resource}
                 ]
               },
               Checks,
               subject(role: :admin),
               object(user_id: "dis")
             ) == %AllOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: true,
                   satisfied?: true
                 },
                 %Check{
                   name: :own_resource,
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }

      # first checks false; second check shouldn't have been evaluated
      assert Evaluator.evaluate_expression_acc(
               %AllOf{
                 children: [
                   %Check{name: :role, arg: :admin},
                   %Check{name: :own_resource}
                 ]
               },
               Checks,
               subject(role: :editor),
               object()
             ) == %AllOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end

    test "evaluates AnyOf without children" do
      assert Evaluator.evaluate_expression_acc(
               %AnyOf{children: []},
               Checks,
               subject()
             ) == %AnyOf{children: [], satisfied?: false}
    end

    test "evaluates AnyOf with one child" do
      assert Evaluator.evaluate_expression_acc(
               %AnyOf{children: [%Check{name: :role, arg: :admin}]},
               Checks,
               subject(role: :admin)
             ) == %AnyOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(
               %AnyOf{children: [%Check{name: :role, arg: :admin}]},
               Checks,
               subject(role: :editor)
             ) == %AnyOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end

    test "evaluates AnyOf with two children" do
      # first check true, second check shouldn't have been evaluated
      assert Evaluator.evaluate_expression_acc(
               %AnyOf{
                 children: [
                   %Check{name: :role, arg: :admin},
                   %Check{name: :own_resource}
                 ]
               },
               Checks,
               subject(role: :admin),
               object(user_id: "sid")
             ) == %AnyOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      # first check false, second check true
      assert Evaluator.evaluate_expression_acc(
               %AnyOf{
                 children: [
                   %Check{name: :role, arg: :admin},
                   %Check{name: :own_resource}
                 ]
               },
               Checks,
               subject(role: :editor),
               object(user_id: "sid")
             ) == %AnyOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: false,
                   satisfied?: false
                 },
                 %Check{
                   name: :own_resource,
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      # all checks false
      assert Evaluator.evaluate_expression_acc(
               %AnyOf{
                 children: [
                   %Check{name: :role, arg: :admin},
                   %Check{name: :own_resource}
                 ]
               },
               Checks,
               subject(role: :editor),
               object()
             ) == %AnyOf{
               children: [
                 %Check{
                   name: :role,
                   arg: :admin,
                   result: false,
                   satisfied?: false
                 },
                 %Check{
                   name: :own_resource,
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end
  end
end
