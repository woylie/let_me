defmodule Expel.PolicyTest do
  use ExUnit.Case, async: true
  doctest Expel.Policy

  import ExUnit.CaptureLog

  alias Expel.Rule
  alias MyApp.Policy
  alias MyApp.PolicyCombinations
  alias MyApp.PolicyShort

  describe "introspection" do
    test "list_rules/0 returns all rules" do
      assert Policy.list_rules() == [
               %Rule{
                 action: :create,
                 allow: [[role: :admin], [role: :writer]],
                 deny: [],
                 object: :article,
                 pre_hooks: []
               },
               %Rule{
                 action: :update,
                 allow: [:own_resource],
                 deny: [],
                 object: :article,
                 pre_hooks: [:preload_groups]
               },
               %Rule{
                 action: :view,
                 allow: [true],
                 description:
                   "allows to view an article and the list of articles",
                 deny: [],
                 object: :article,
                 pre_hooks: []
               },
               %Rule{
                 action: :delete,
                 allow: [[role: :admin]],
                 deny: [:same_user],
                 object: :user,
                 pre_hooks: []
               },
               %Rule{
                 action: :list,
                 allow: [role: :admin, role: :client],
                 deny: [],
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
                 deny: [],
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
               deny: [],
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
                  deny: [],
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
               deny: [],
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

  describe "authorized?/3" do
    test "evaluates a single allow check without options" do
      assert PolicyCombinations.authorized?(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a single allow check with options" do
      assert PolicyCombinations.authorized?(
               :simple_allow_with_options,
               %{role: :editor}
             ) == true

      assert PolicyCombinations.authorized?(
               :simple_allow_with_options,
               %{role: :writer}
             ) == false
    end

    test "evaluates a boolean as an allow check" do
      assert PolicyCombinations.authorized?(:simple_allow_true, %{}) == true
      assert PolicyCombinations.authorized?(:simple_allow_false, %{}) == false
    end

    test "evaluates a single deny check without options" do
      assert PolicyCombinations.authorized?(
               :simple_deny_without_options,
               %{id: 1},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :simple_deny_without_options,
               %{id: 1},
               %{id: 2}
             ) == true
    end

    test "evaluates a single deny check with options" do
      assert PolicyCombinations.authorized?(
               :simple_deny_with_options,
               %{role: :editor}
             ) == true

      assert PolicyCombinations.authorized?(
               :simple_deny_with_options,
               %{role: :writer}
             ) == false
    end

    test "evaluates a boolean as a deny check" do
      assert PolicyCombinations.authorized?(:simple_deny_true, %{}) == false
      assert PolicyCombinations.authorized?(:simple_deny_false, %{}) == true
    end

    test "deny check without any allow checks is always false" do
      assert PolicyCombinations.authorized?(
               :simple_no_allow,
               %{id: 1},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :simple_no_allow,
               %{id: 1},
               %{id: 2}
             ) == false
    end

    test "action without any checks is always false" do
      assert PolicyCombinations.authorized?(:simple_no_checks, %{}) == false
    end

    test "returns false and logs warning if rule does not exist" do
      assert capture_log([level: :warn], fn ->
               assert PolicyCombinations.authorized?(:does_not_exist, %{}) ==
                        false
             end) =~ "Permission checked for rule that does not exist"
    end

    test "evaluates a list of allow checks with AND" do
      # allow [:own_resource, role: :editor]
      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :editor},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :editor},
               %{user_id: 2}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :writer},
               %{user_id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :writer},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a multiple allow conditions with OR" do
      # allow role: :editor
      # allow :own_resource
      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :editor},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :editor},
               %{user_id: 2}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :writer},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :writer},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a list of deny checks with AND" do
      # deny [:same_user, role: :writer]

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :writer},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :writer},
               %{id: 2}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :editor},
               %{id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :editor},
               %{id: 2}
             ) == true
    end

    test "evaluates a multiple deny conditions with OR" do
      # deny :same_user
      # deny role: :writer
      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :editor},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :editor},
               %{id: 2}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :writer},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :writer},
               %{id: 2}
             ) == false
    end

    test "can configure check module with use option" do
      # Policy module is configured to use PolicyCombinations.Checks
      assert Policy.authorized?(:user_delete, %{role: :admin, id: 1}, %{id: 2})
      refute Policy.authorized?(:user_delete, %{role: :admin, id: 1}, %{id: 1})
      refute Policy.authorized?(:user_delete, %{role: :user, id: 1}, %{id: 2})
      refute Policy.authorized?(:user_delete, %{role: :user, id: 1}, %{id: 1})
    end
  end

  describe "authorize/3" do
    test "evaluates a single allow check without options" do
      assert PolicyCombinations.authorize(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == :ok

      assert PolicyCombinations.authorize(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 2}
             ) == {:error, :unauthorized}
    end

    test "can configure error reason" do
      # PolicyShort module is configured to use :forbidden
      assert PolicyShort.authorize(:article_create, %{role: :nobody}) ==
               {:error, :forbidden}
    end
  end

  describe "authorize!/3" do
    test "evaluates a single allow check without options" do
      assert PolicyCombinations.authorize!(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == :ok

      assert_raise Expel.UnauthorizedError, "unauthorized", fn ->
        PolicyCombinations.authorize!(
          :simple_allow_without_options,
          %{id: 1},
          %{user_id: 2}
        )
      end
    end
  end
end
