defmodule LetMe.UnauthorizedErrorTest do
  use ExUnit.Case, async: true

  alias LetMe.UnauthorizedError

  doctest LetMe.UnauthorizedError

  describe "message/1" do
    test "returns the message" do
      assert UnauthorizedError.message(UnauthorizedError.new("forbidden")) ==
               "forbidden"
    end

    test "falls back to the default message" do
      assert UnauthorizedError.message(%UnauthorizedError{}) == "unauthorized"
    end
  end

  describe "new/1" do
    test "returns an UnauthorizedError struct with default message" do
      assert UnauthorizedError.new() == %UnauthorizedError{
               message: "unauthorized",
               expression: nil
             }
    end

    test "returns an UnauthorizedError struct with custom message" do
      assert UnauthorizedError.new("forbidden") == %UnauthorizedError{
               message: "forbidden",
               expression: nil
             }
    end
  end
end
