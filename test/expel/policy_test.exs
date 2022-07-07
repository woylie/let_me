defmodule Expel.PolicyTest do
  use ExUnit.Case, async: true

  alias Expel.Rule
  alias Expel.TestPolicy

  describe "list_rules/0" do
    test "returns all rules" do
      assert TestPolicy.list_rules() == [
               %Rule{
                 action: :article_create,
                 allow: [[role: :admin], [role: :writer]],
                 disallow: [],
                 pre_hooks: []
               },
               %Rule{
                 action: :article_update,
                 allow: [:own_resource],
                 disallow: [],
                 pre_hooks: [:preload_groups]
               },
               %Rule{
                 action: :article_view,
                 allow: [true],
                 disallow: [],
                 pre_hooks: []
               },
               %Rule{
                 action: :user_delete,
                 allow: [[role: :admin]],
                 disallow: [:same_user],
                 pre_hooks: []
               },
               %Rule{
                 action: :user_list,
                 allow: [role: :admin, role: :client],
                 disallow: [],
                 pre_hooks: []
               },
               %Rule{
                 action: :user_view,
                 allow: [
                   {:role, :admin},
                   [{:role, :client}, :same_company],
                   :same_user
                 ],
                 disallow: [],
                 pre_hooks: []
               }
             ]
    end
  end
end
