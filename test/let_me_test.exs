defmodule LetMeTest do
  use ExUnit.Case
  doctest LetMe, import: true

  alias MyApp.Blog.Article

  @article %Article{
    like_count: 25,
    title: "Give us back our moon dust and cockroaches",
    user_id: 5,
    view_count: 200
  }

  @admin %{role: :admin, id: 1}
  @owner %{role: :user, id: 5}
  @user %{role: :user, id: 2}

  describe "redact/3" do
    test "replaces struct keys with default value depending on user" do
      assert LetMe.redact(@article, @admin) == @article

      assert LetMe.redact(@article, @owner) ==
               %{@article | view_count: :redacted}

      assert LetMe.redact(@article, @user) ==
               %{@article | like_count: :redacted, view_count: :redacted}
    end

    test "replaces struct keys with given value depending on user" do
      opts = [redact_value: :removed]

      assert LetMe.redact(@article, @owner, opts) ==
               %{@article | view_count: :removed}

      assert LetMe.redact(@article, @user, opts) ==
               %{@article | like_count: :removed, view_count: :removed}
    end

    test "replaces keys in struct list with default value depending on user" do
      assert LetMe.redact([@article], @admin) == [@article]

      assert LetMe.redact([@article], @owner) ==
               [%{@article | view_count: :redacted}]

      assert LetMe.redact([@article], @user) ==
               [%{@article | like_count: :redacted, view_count: :redacted}]
    end

    test "replaces keys in struct list with given value depending on user" do
      opts = [redact_value: :removed]

      assert LetMe.redact([@article], @owner, opts) ==
               [%{@article | view_count: :removed}]

      assert LetMe.redact([@article], @user, opts) ==
               [%{@article | like_count: :removed, view_count: :removed}]
    end

    test "handles nil value" do
      assert LetMe.redact(nil, @user) == nil
    end
  end
end
