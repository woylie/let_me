defmodule LetMe.UnauthorizedErrorTest do
  use ExUnit.Case, async: true

  alias LetMe.UnauthorizedError

  describe "new/1" do
    test "returns an UnauthorizedError struct with default message" do
      assert UnauthorizedError.new() == %UnauthorizedError{
               message: "unauthorized",
               allow_checks: nil,
               deny_checks: nil
             }
    end

    test "returns an UnauthorizedError struct with custom message" do
      assert UnauthorizedError.new("forbidden") == %UnauthorizedError{
               message: "forbidden",
               allow_checks: nil,
               deny_checks: nil
             }
    end
  end
end
