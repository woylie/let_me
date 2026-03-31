defmodule LetMe.OptimizerTest do
  use ExUnit.Case, async: true

  alias LetMe.AllOf
  alias LetMe.AnyOf
  alias LetMe.Check
  alias LetMe.Literal
  alias LetMe.Not
  alias LetMe.Optimizer

  test "returns Literal unchanged" do
    literal = %Literal{passed?: true}
    assert Optimizer.optimize(literal) == literal
  end

  test "returns Check unchanged" do
    check = %Check{name: :role, arg: :admin}
    assert Optimizer.optimize(check) == check
  end

  test "removes nested not" do
    assert Optimizer.optimize(%Not{
             expression: %Not{expression: %Check{name: :two_factor}}
           }) == %Check{name: :two_factor}
  end

  test "resolves not on literals" do
    assert Optimizer.optimize(%Not{expression: %Literal{passed?: true}}) ==
             %Literal{passed?: false}
  end

  test "pushes down Not in AllOf" do
    assert Optimizer.optimize(%Not{
             expression: %AllOf{
               children: [%Check{name: :suspended}, %Check{name: :unverified}]
             }
           }) ==
             %AnyOf{
               children: [
                 %Not{expression: %Check{name: :suspended}},
                 %Not{expression: %Check{name: :unverified}}
               ]
             }
  end

  test "pushes down Not in AnyOf" do
    assert Optimizer.optimize(%Not{
             expression: %AnyOf{
               children: [%Check{name: :suspended}, %Check{name: :unverified}]
             }
           }) ==
             %AllOf{
               children: [
                 %Not{expression: %Check{name: :suspended}},
                 %Not{expression: %Check{name: :unverified}}
               ]
             }
  end

  test "converts AllOf without children to true Literal" do
    assert Optimizer.optimize(%AllOf{children: []}) == %Literal{passed?: true}
  end

  test "converts AnyOf without children to false Literal" do
    assert Optimizer.optimize(%AnyOf{children: []}) == %Literal{passed?: false}
  end

  test "unwraps AllOf with a single child" do
    check = %Check{name: :role, arg: :admin}
    assert Optimizer.optimize(%AllOf{children: [check]}) == check
  end

  test "applies optimization on unwrapped AllOf child and on result" do
    assert Optimizer.optimize(%AllOf{children: [%AnyOf{children: []}]}) ==
             %Literal{passed?: false}
  end

  test "unwraps anyOf with a single child" do
    check = %Check{name: :role, arg: :admin}
    assert Optimizer.optimize(%AnyOf{children: [check]}) == check
  end

  test "applies optimization on unwrapped AnyOf child and on result" do
    assert Optimizer.optimize(%AnyOf{children: [%AllOf{children: []}]}) ==
             %Literal{passed?: true}
  end

  test "deduplicates AllOf" do
    assert Optimizer.optimize(%AllOf{
             children: [
               %Check{name: :role},
               %Check{name: :two_fa},
               %Check{name: :role}
             ]
           }) == %AllOf{
             children: [
               %Check{name: :role},
               %Check{name: :two_fa}
             ]
           }
  end

  test "does not deduplicate AllOf checks with different args" do
    assert Optimizer.optimize(%AllOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :role, arg: :editor}
             ]
           }) == %AllOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :role, arg: :editor}
             ]
           }
  end

  test "optimizes after deduplicating AllOf" do
    assert Optimizer.optimize(%AllOf{
             children: [
               %Literal{passed?: true},
               %Literal{passed?: true}
             ]
           }) == %Literal{passed?: true}
  end

  test "unwraps AllOf if one child remains after optimization" do
    assert Optimizer.optimize(%AllOf{
             children: [
               %Literal{passed?: true},
               %Check{name: :two_factor}
             ]
           }) == %Check{name: :two_factor}
  end

  test "deduplicates AnyOf" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %Check{name: :role},
               %Check{name: :two_fa},
               %Check{name: :role}
             ]
           }) == %AnyOf{
             children: [
               %Check{name: :role},
               %Check{name: :two_fa}
             ]
           }
  end

  test "does not deduplicate AnyOf checks with different args" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :role, arg: :editor}
             ]
           }) == %AnyOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :role, arg: :editor}
             ]
           }
  end

  test "optimizes after deduplicating AnyOf" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %Literal{passed?: true},
               %Literal{passed?: true}
             ]
           }) == %Literal{passed?: true}

    assert Optimizer.optimize(%AnyOf{
             children: [
               %Literal{passed?: false},
               %Literal{passed?: false}
             ]
           }) == %Literal{passed?: false}
  end

  test "unwraps AnyOf if one child remains after optimization" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %Literal{passed?: false},
               %Check{name: :two_factor}
             ]
           }) == %Check{name: :two_factor}
  end

  test "converts AllOf with false literal to literal" do
    assert Optimizer.optimize(%AllOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Literal{passed?: false}
             ]
           }) == %Literal{passed?: false}
  end

  test "converts AnyOf with true literal to literal" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Literal{passed?: true}
             ]
           }) == %Literal{passed?: true}
  end

  test "removes true literal from AllOf" do
    assert Optimizer.optimize(%AllOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :two_fa},
               %Literal{passed?: true}
             ]
           }) == %AllOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :two_fa}
             ]
           }
  end

  test "removes false literal from AnyOf" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :two_fa},
               %Literal{passed?: false}
             ]
           }) == %AnyOf{
             children: [
               %Check{name: :role, arg: :admin},
               %Check{name: :two_fa}
             ]
           }
  end

  test "factorizes AnyOf and collapses single-child factorized branches" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1},
                   %Check{name: :check2}
                 ]
               },
               %AllOf{
                 children: [
                   %Check{name: :check3},
                   %Check{name: :check1}
                 ]
               },
               %Check{name: :check4}
             ]
           }) == %AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1},
                   %AnyOf{
                     children: [
                       %Check{name: :check2},
                       %Check{name: :check3}
                     ]
                   }
                 ]
               },
               %Check{name: :check4}
             ]
           }
  end

  test "factorizes AnyOf" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1},
                   %Check{name: :check2},
                   %Check{name: :check3}
                 ]
               },
               %AllOf{
                 children: [
                   %Check{name: :check4},
                   %Check{name: :check1},
                   %Check{name: :check5}
                 ]
               }
             ]
           }) == %AllOf{
             children: [
               %Check{name: :check1},
               %AnyOf{
                 children: [
                   %AllOf{
                     children: [
                       %Check{name: :check2},
                       %Check{name: :check3}
                     ]
                   },
                   %AllOf{
                     children: [
                       %Check{name: :check4},
                       %Check{name: :check5}
                     ]
                   }
                 ]
               }
             ]
           }
  end

  test "factorizes AnyOf and folds single child left behind" do
    # (A and B) or A = A
    assert Optimizer.optimize(%AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1},
                   %Check{name: :check2}
                 ]
               },
               %AllOf{
                 children: [
                   %Check{name: :check1}
                 ]
               }
             ]
           }) == %Check{name: :check1}
  end

  test "does not factorize AnyOf with single AllOf child" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1},
                   %Check{name: :check2}
                 ]
               },
               %Check{name: :check3}
             ]
           }) == %AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1},
                   %Check{name: :check2}
                 ]
               },
               %Check{name: :check3}
             ]
           }
  end

  test "anyof(allof(A), allof(A)) = A" do
    assert Optimizer.optimize(%AnyOf{
             children: [
               %AllOf{
                 children: [
                   %Check{name: :check1}
                 ]
               },
               %AllOf{
                 children: [
                   %Check{name: :check1}
                 ]
               }
             ]
           }) == %Check{name: :check1}
  end
end
