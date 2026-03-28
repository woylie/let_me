defmodule LetMe.PolicyTest do
  use ExUnit.Case, async: true
  doctest LetMe.Policy

  import ExUnit.CaptureLog

  alias LetMe.Rule
  alias MyApp.Blog.Article
  alias MyApp.Policy
  alias MyApp.PolicyShort
  alias MyApp.PolicyStruct
  alias MyApp.TestPolicy

  defmodule TestPolicy do
    use LetMe.Policy, check_module: MyApp.Checks
    alias LetMe.TestHooks

    object :simple do
      action :allow_without_options do
        allow :own_resource
      end

      action [:list_of_actions_1, :list_of_actions_2] do
        allow :own_resource
      end

      action :allow_with_options do
        allow role: :editor
      end

      action :allow_true do
        allow true
      end

      action :allow_false do
        allow false
      end

      action :deny_without_options do
        allow true
        deny :same_user
      end

      action :deny_with_options do
        allow true
        deny role: :writer
      end

      action :deny_true do
        allow true
        deny true
      end

      action :deny_false do
        allow true
        deny false
      end

      action :no_allow do
        deny :same_user
      end

      action :no_checks do
      end

      action :empty_list_check do
        allow []
      end

      action :with_metadata do
        metadata :desc_ja, "指定されたユーザーに対して、指定された機能を無効にします。"
      end

      action :with_reason do
        allow role_with_reason: :admin
        deny :user_suspended
      end
    end

    object :complex, MyApp.Blog.Article do
      action :multiple_allow_checks do
        allow [:own_resource, role: :editor]
      end

      action :multiple_allow_conditions do
        allow role: :editor
        allow :own_resource
      end

      action :multiple_deny_checks do
        allow true
        deny [:same_user, role: :writer]
      end

      action :multiple_deny_conditions do
        allow true
        deny :same_user
        deny role: :writer
      end

      action :single_prehook do
        pre_hooks :preload_groups
        allow :same_group
      end

      action :single_mf_prehook do
        pre_hooks {TestHooks, :preload_likeability}
        allow min_likeability: 5
      end

      action :single_mfa_prehook do
        pre_hooks {TestHooks, :preload_handsomeness, factor: 2}
        allow min_handsomeness: 5
      end

      action :multiple_prehooks do
        pre_hooks [:preload_groups, :preload_pets]
        allow [:same_group, :same_pet]
      end

      action :prehook_with_opts do
        pre_hooks :add_reason_arg
        allow [:has_valid_reason]
      end

      action :single_prehook_with_opts do
        pre_hooks :preload_groups
        allow :same_group
      end

      action :single_mf_prehook_with_opts do
        pre_hooks {TestHooks, :preload_likeability}
        allow min_likeability: 5
      end

      action :single_mfa_prehook_with_opts do
        pre_hooks {TestHooks, :preload_handsomeness, factor: 2}
        allow min_handsomeness: 5
      end

      action :multiple_prehooks_with_opts do
        pre_hooks [:preload_groups, :preload_pets]
        allow [:same_group, :same_pet]
      end
    end

    object :lazy do
      action :two_allow_checks_first_false do
        allow lazy_check: {:allow_1, false},
              lazy_check: {:allow_2, true}
      end

      action :two_allow_checks_both_true do
        allow lazy_check: {:allow_1, true},
              lazy_check: {:allow_2, true}
      end

      action :two_allow_rules_first_true do
        allow lazy_check: {:allow_1_1, true},
              lazy_check: {:allow_1_2, true}

        allow lazy_check: {:allow_2_1, true},
              lazy_check: {:allow_2_2, false}
      end

      action :two_deny_checks_first_false do
        allow true

        deny lazy_check: {:deny_1, false},
             lazy_check: {:deny_2, true}
      end

      action :two_deny_checks_both_true do
        allow true

        deny lazy_check: {:deny_1, true},
             lazy_check: {:deny_2, true}
      end

      action :two_deny_rules_first_true do
        allow true

        deny lazy_check: {:deny_1_1, true},
             lazy_check: {:deny_1_2, true}

        deny lazy_check: {:deny_2_1, true},
             lazy_check: {:deny_2_2, false}
      end

      action :two_deny_and_two_allow_checks do
        allow lazy_check: {:allow_1, true},
              lazy_check: {:allow_2, true}

        deny lazy_check: {:deny_1, true},
             lazy_check: {:deny_2, true}
      end
    end
  end

  describe "lazy evaluation" do
    @describetag :this
    test "does not evaluate second allow check if first one is false" do
      assert TestPolicy.authorize?(:lazy_two_allow_checks_first_false, %{}) ==
               false

      assert_receive {:check, :allow_1}
      refute_receive {:check, :allow_2}
    end

    test "evaluates all allow checks" do
      assert TestPolicy.authorize?(:lazy_two_allow_checks_both_true, %{}) ==
               true

      assert_receive {:check, :allow_1}
      assert_receive {:check, :allow_2}
    end

    test "does not evaluate second allow rule if first one is true" do
      assert TestPolicy.authorize?(:lazy_two_allow_rules_first_true, %{}) ==
               true

      assert_receive {:check, :allow_1_1}
      assert_receive {:check, :allow_1_2}
      refute_receive {:check, :allow_2_1}
      refute_receive {:check, :allow_2_2}
    end

    test "does not evaluate second deny check if first one is false" do
      assert TestPolicy.authorize?(:lazy_two_deny_checks_first_false, %{}) ==
               true

      assert_receive {:check, :deny_1}
      refute_receive {:check, :deny_2}
    end

    test "evaluates all deny checks" do
      assert TestPolicy.authorize?(:lazy_two_deny_checks_both_true, %{}) ==
               false

      assert_receive {:check, :deny_1}
      assert_receive {:check, :deny_2}
    end

    test "does not evaluate second deny rule if first one is true" do
      assert TestPolicy.authorize?(:lazy_two_deny_rules_first_true, %{}) ==
               false

      assert_receive {:check, :deny_1_1}
      assert_receive {:check, :deny_1_2}
      refute_receive {:check, :deny_2_1}
      refute_receive {:check, :deny_2_2}
    end

    test "does evaluate allow rules if deny rule is true" do
      assert TestPolicy.authorize?(:lazy_two_deny_and_two_allow_checks, %{}) ==
               false

      assert_receive {:check, :deny_1}
      assert_receive {:check, :deny_2}
      refute_receive {:check, :allow_1}
      refute_receive {:check, :allow_2}
    end
  end

  describe "list_rules" do
    test "returns all rules" do
      assert Enum.sort(Policy.list_rules()) ==
               Enum.sort([
                 %Rule{
                   action: :create,
                   allow: [[role: :admin], [role: :writer]],
                   deny: [],
                   name: :article_create,
                   object: :article,
                   pre_hooks: []
                 },
                 %Rule{
                   action: :update,
                   allow: [:own_resource],
                   deny: [],
                   name: :article_update,
                   object: :article,
                   pre_hooks: [:preload_groups]
                 },
                 %Rule{
                   action: :view,
                   allow: [true],
                   description:
                     "allows to view an article and the list of articles",
                   deny: [],
                   name: :article_view,
                   object: :article,
                   pre_hooks: []
                 },
                 %Rule{
                   action: :delete,
                   allow: [[role: :admin]],
                   deny: [:same_user],
                   name: :user_delete,
                   object: :user,
                   pre_hooks: [],
                   metadata: [
                     gql_exclude: true,
                     desc_ja: "ユーザーアカウントを削除できるようにする"
                   ]
                 },
                 %Rule{
                   action: :list,
                   allow: [role: :admin, role: :client],
                   deny: [],
                   name: :user_list,
                   object: :user,
                   pre_hooks: []
                 },
                 %Rule{
                   action: :remove,
                   allow: [[role: :super_admin]],
                   deny: [],
                   name: :user_remove,
                   object: :user,
                   pre_hooks: [],
                   metadata: []
                 },
                 %Rule{
                   action: :view,
                   allow: [
                     {:role, :admin},
                     [{:role, :client}, :same_company],
                     :same_user
                   ],
                   deny: [],
                   name: :user_view,
                   object: :user,
                   pre_hooks: []
                 }
               ])
    end

    test "filters by object" do
      rules = Policy.list_rules(object: :article)
      assert Enum.all?(rules, &(&1.object == :article))

      rules = Policy.list_rules(object: :user)
      assert Enum.all?(rules, &(&1.object == :user))
    end

    test "filters by action" do
      rules = Policy.list_rules(action: :view)
      assert Enum.all?(rules, &(&1.action == :view))
    end

    test "filters by allow check name without options" do
      assert [%Rule{action: :update, object: :article}] =
               Policy.list_rules(allow: :own_resource)
    end

    test "filters by allow check name with options" do
      assert [%Rule{action: :create, object: :article}] =
               Policy.list_rules(allow: {:role, :writer})
    end

    test "filters by deny check name without options" do
      assert [%Rule{action: :delete, object: :user}] =
               Policy.list_rules(deny: :same_user)
    end

    test "filters by metadata key" do
      assert [%Rule{action: :delete, object: :user}] =
               Policy.list_rules(metadata: :desc_ja)
    end

    test "filters by metadata pair" do
      assert [%Rule{action: :delete, object: :user}] =
               Policy.list_rules(metadata: {:gql_exclude, true})
    end
  end

  describe "filter_allowed_actions" do
    test "filters list of rules by subject and object" do
      rules = Policy.list_rules()
      object = {:article, %Article{user_id: 1}}

      assert [%Rule{name: :article_view}] =
               Policy.filter_allowed_actions(rules, %{id: 2}, object)

      assert [%Rule{name: :article_create}, %Rule{name: :article_view}] =
               Enum.sort_by(
                 Policy.filter_allowed_actions(
                   rules,
                   %{id: 2, role: :writer},
                   object
                 ),
                 & &1.name
               )

      assert [%Rule{name: :article_create}, %Rule{name: :article_view}] =
               Enum.sort_by(
                 Policy.filter_allowed_actions(
                   rules,
                   %{id: 2, role: :admin},
                   object
                 ),
                 & &1.name
               )

      assert [
               %Rule{name: :article_create},
               %Rule{name: :article_update},
               %Rule{name: :article_view}
             ] =
               rules
               |> Policy.filter_allowed_actions(
                 %{id: 1, role: :admin},
                 object
               )
               |> Enum.sort_by(& &1.name)

      assert [%Rule{name: :article_update}, %Rule{name: :article_view}] =
               Enum.sort_by(
                 Policy.filter_allowed_actions(rules, %{id: 1}, object),
                 & &1.name
               )
    end

    test "can filter by passing the struct only" do
      rules = Policy.list_rules()
      object = %Article{user_id: 1}

      assert [%Rule{name: :article_view}] =
               Policy.filter_allowed_actions(rules, %{id: 2}, object)
    end
  end

  describe "get_rule/1" do
    test "returns rule" do
      assert Policy.get_rule(:article_create) == %Rule{
               action: :create,
               allow: [[role: :admin], [role: :writer]],
               deny: [],
               name: :article_create,
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
                  name: :article_create,
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
               name: :article_create,
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

  describe "authorize?/4" do
    test "evaluates a single allow check without options" do
      assert TestPolicy.authorize?(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a single allow check with options" do
      assert TestPolicy.authorize?(
               :simple_allow_with_options,
               %{role: :editor}
             ) == true

      assert TestPolicy.authorize?(
               :simple_allow_with_options,
               %{role: :writer}
             ) == false
    end

    test "evaluates a boolean as an allow check" do
      assert TestPolicy.authorize?(:simple_allow_true, %{}) == true
      assert TestPolicy.authorize?(:simple_allow_false, %{}) == false
    end

    test "evaluates a single deny check without options" do
      assert TestPolicy.authorize?(
               :simple_deny_without_options,
               %{id: 1},
               %{id: 1}
             ) == false

      assert TestPolicy.authorize?(
               :simple_deny_without_options,
               %{id: 1},
               %{id: 2}
             ) == true
    end

    test "evaluates a single deny check with options" do
      assert TestPolicy.authorize?(
               :simple_deny_with_options,
               %{role: :editor}
             ) == true

      assert TestPolicy.authorize?(
               :simple_deny_with_options,
               %{role: :writer}
             ) == false
    end

    test "evaluates a boolean as a deny check" do
      assert TestPolicy.authorize?(:simple_deny_true, %{}) == false
      assert TestPolicy.authorize?(:simple_deny_false, %{}) == true
    end

    test "deny check without any allow checks is always false" do
      assert TestPolicy.authorize?(
               :simple_no_allow,
               %{id: 1},
               %{id: 1}
             ) == false

      assert TestPolicy.authorize?(
               :simple_no_allow,
               %{id: 1},
               %{id: 2}
             ) == false
    end

    test "action without any checks is always false" do
      assert TestPolicy.authorize?(:simple_no_checks, %{}) == false

      assert TestPolicy.authorize?(:simple_empty_list_check, %{}) ==
               false
    end

    test "action with list of names results in multiple rules" do
      assert TestPolicy.authorize?(
               :simple_list_of_actions_1,
               %{id: 1},
               %{user_id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :simple_list_of_actions_2,
               %{id: 1},
               %{user_id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :simple_list_of_actions_1,
               %{id: 1},
               %{user_id: 2}
             ) == false

      assert TestPolicy.authorize?(
               :simple_list_of_actions_2,
               %{id: 1},
               %{user_id: 2}
             ) == false
    end

    test "returns false and logs warning if rule does not exist" do
      assert capture_log([level: :warning], fn ->
               assert TestPolicy.authorize?(:does_not_exist, %{}) ==
                        false
             end) =~ "Permission checked for rule that does not exist"
    end

    test "evaluates a list of allow checks with AND" do
      # allow [:own_resource, role: :editor]
      assert TestPolicy.authorize?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :editor},
               %{user_id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :editor},
               %{user_id: 2}
             ) == false

      assert TestPolicy.authorize?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :writer},
               %{user_id: 1}
             ) == false

      assert TestPolicy.authorize?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :writer},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a multiple allow conditions with OR" do
      # allow role: :editor
      # allow :own_resource
      assert TestPolicy.authorize?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :editor},
               %{user_id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :editor},
               %{user_id: 2}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :writer},
               %{user_id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :writer},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a list of deny checks with AND" do
      # deny [:same_user, role: :writer]

      assert TestPolicy.authorize?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :writer},
               %{id: 1}
             ) == false

      assert TestPolicy.authorize?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :writer},
               %{id: 2}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :editor},
               %{id: 1}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :editor},
               %{id: 2}
             ) == true
    end

    test "evaluates a multiple deny conditions with OR" do
      # deny :same_user
      # deny role: :writer
      assert TestPolicy.authorize?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :editor},
               %{id: 1}
             ) == false

      assert TestPolicy.authorize?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :editor},
               %{id: 2}
             ) == true

      assert TestPolicy.authorize?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :writer},
               %{id: 1}
             ) == false

      assert TestPolicy.authorize?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :writer},
               %{id: 2}
             ) == false
    end

    test "can configure check module with use option" do
      # Policy module is configured to use TestPolicy.Checks
      assert Policy.authorize?(:user_delete, %{role: :admin, id: 1}, %{id: 2})
      refute Policy.authorize?(:user_delete, %{role: :admin, id: 1}, %{id: 1})
      refute Policy.authorize?(:user_delete, %{role: :user, id: 1}, %{id: 2})
      refute Policy.authorize?(:user_delete, %{role: :user, id: 1}, %{id: 1})
    end

    test "updates subject and object with pre-hook" do
      assert TestPolicy.authorize?(
               :complex_single_prehook,
               %{id: 1},
               %{id: 100}
             )
    end

    test "updates subject and object with multiple pre-hooks" do
      assert TestPolicy.authorize?(
               :complex_multiple_prehooks,
               %{id: 1},
               %{id: 100}
             )
    end

    test "accepts module/function tuples as pre-hooks" do
      assert TestPolicy.authorize?(
               :complex_single_mf_prehook,
               %{id: 4},
               %{id: 100}
             )
    end

    test "accepts mfa tuples as pre-hooks" do
      assert TestPolicy.authorize?(
               :complex_single_mfa_prehook,
               %{id: 3},
               %{id: 100}
             )
    end

    test "uses authorize? opts as args in prehook" do
      assert TestPolicy.authorize?(
               :complex_prehook_with_opts,
               %{id: 5},
               %{id: 6},
               reason: "valid"
             )

      assert TestPolicy.authorize?(
               :complex_prehook_with_opts,
               %{id: 5},
               %{id: 6},
               reason: "also_valid"
             )

      refute TestPolicy.authorize?(
               :complex_prehook_with_opts,
               %{id: 5},
               %{id: 6},
               reason: "invalid"
             )
    end

    test "updates subject and object with pre-hook with opts" do
      assert TestPolicy.authorize?(
               :complex_single_prehook_with_opts,
               %{id: 1},
               %{id: 100},
               group_id: 500
             )
    end

    test "updates subject and object with multiple pre-hooks with opts" do
      assert TestPolicy.authorize?(
               :complex_multiple_prehooks_with_opts,
               %{id: 1},
               %{id: 100},
               pet_id: 10,
               group_id: 100
             )
    end

    test "accepts module/function tuples as pre-hooks with opts" do
      assert TestPolicy.authorize?(
               :complex_single_mf_prehook_with_opts,
               %{id: 2},
               %{id: 100},
               bonus: 3
             )
    end

    test "accepts mfa tuples as pre-hooks with opts" do
      assert TestPolicy.authorize?(
               :complex_single_mfa_prehook_with_opts,
               %{id: 2},
               %{id: 100},
               factor: 2,
               bonus: 1
             )
    end

    test "raises error if pre-hook options are not a list" do
      error =
        assert_raise ArgumentError, fn ->
          defmodule RaiseTestPolicy do
            use LetMe.Policy, check_module: MyApp.Checks
            alias LetMe.TestHooks

            object :some_object do
              action :single_mfa_prehook do
                pre_hooks {TestHooks, :preload_handsomeness, %{factor: 2}}
                allow true
              end
            end
          end
        end

      assert error.message =~ "Invalid pre-hook options"
    end

    test "handles ok/error tuples" do
      assert TestPolicy.authorize?(
               :simple_with_reason,
               %{role: :admin, state: :active}
             ) == true

      assert TestPolicy.authorize?(
               :simple_with_reason,
               %{role: :admin, state: :suspended}
             ) == false

      assert TestPolicy.authorize?(
               :simple_with_reason,
               %{role: :writer, state: :active}
             ) == false
    end
  end

  describe "authorize/4" do
    test "evaluates a single allow check without options" do
      assert TestPolicy.authorize(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == :ok

      assert TestPolicy.authorize(
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

    test "can configure error message" do
      assert_raise LetMe.UnauthorizedError, "What were you thinking?", fn ->
        PolicyShort.authorize!(:article_create, %{role: :nobody})
      end
    end

    test "returns error struct if configured" do
      # PolicyShort module sets error_reason to :struct
      assert PolicyStruct.authorize(:article_create, %{role: :nobody}) ==
               {:error,
                %LetMe.UnauthorizedError{message: "What were you thinking?"}}
    end
  end

  describe "authorize!/4" do
    test "evaluates a single allow check without options" do
      assert TestPolicy.authorize!(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == :ok

      assert_raise LetMe.UnauthorizedError, "unauthorized", fn ->
        TestPolicy.authorize!(
          :simple_allow_without_options,
          %{id: 1},
          %{user_id: 2}
        )
      end
    end
  end

  describe "typespec generation" do
    test "should generate action() typespec" do
      assert Code.Typespec.fetch_types(LetMe.TypespecTestPolicy) ==
               {:ok,
                [
                  type:
                    {:action,
                     {:type, 1, :union,
                      [
                        {:atom, 0, :type_check_write},
                        {:atom, 0, :type_check_read}
                      ]}, []}
                ]}
    end
  end
end
