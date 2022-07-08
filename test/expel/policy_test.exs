defmodule Expel.PolicyTest do
  use ExUnit.Case, async: true
  doctest Expel.Policy

  alias Expel.Rule
  alias MyApp.Policy

  describe "introspection" do
    test "list_rules/0 returns all rules" do
      assert Policy.list_rules() == [
               %Rule{
                 action: :create,
                 allow: [[role: :admin], [role: :writer]],
                 disallow: [],
                 object: :article,
                 pre_hooks: []
               },
               %Rule{
                 action: :update,
                 allow: [:own_resource],
                 disallow: [],
                 object: :article,
                 pre_hooks: [:preload_groups]
               },
               %Rule{
                 action: :view,
                 allow: [true],
                 disallow: [],
                 object: :article,
                 pre_hooks: []
               },
               %Rule{
                 action: :delete,
                 allow: [[role: :admin]],
                 disallow: [:same_user],
                 object: :user,
                 pre_hooks: []
               },
               %Rule{
                 action: :list,
                 allow: [role: :admin, role: :client],
                 disallow: [],
                 object: :user,
                 pre_hooks: []
               },
               %Rule{
                 action: :view,
                 allow: [
                   {:role, :admin},
                   [{:role, :client}, :same_company],
                   :same_user
                 ],
                 disallow: [],
                 object: :user,
                 pre_hooks: []
               }
             ]
    end
  end

  describe "get_rule/1" do
    test "returns rule" do
      assert Policy.get_rule(:article_create) == %Rule{
               action: :create,
               allow: [[role: :admin], [role: :writer]],
               disallow: [],
               object: :article,
               pre_hooks: []
             }
    end

    test "returns nil if rule is not found" do
      assert Policy.get_rule(:cookie_eat) == nil
    end
  end

  describe "fetch_rule/1" do
    test "returns rule" do
      assert Policy.fetch_rule(:article_create) ==
               {:ok,
                %Rule{
                  action: :create,
                  allow: [[role: :admin], [role: :writer]],
                  disallow: [],
                  object: :article,
                  pre_hooks: []
                }}
    end

    test "returns :error if rule is not found" do
      assert Policy.fetch_rule(:cookie_eat) == :error
    end
  end

  describe "fetch_rule!/1" do
    test "returns rule" do
      assert Policy.fetch_rule!(:article_create) == %Rule{
               action: :create,
               allow: [[role: :admin], [role: :writer]],
               disallow: [],
               object: :article,
               pre_hooks: []
             }
    end

    test "raises error if rule is not found" do
      assert_raise KeyError, fn ->
        Policy.fetch_rule!(:cookie_eat)
      end
    end
  end
end
