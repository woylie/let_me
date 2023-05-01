defmodule MyApp.Policy do
  @moduledoc false

  use LetMe.Policy, check_module: MyApp.Checks

  object :article, MyApp.Blog.Article do
    action :create do
      allow role: :admin
      allow role: :writer
    end

    action :update do
      pre_hooks :preload_groups
      allow :own_resource
    end

    action :view do
      desc "allows to view an article and the list of articles"
      allow true
    end
  end

  object :user do
    action :delete do
      allow role: :admin
      deny :same_user
      metadata deprecated: "Hard deletion is deprecated", replacement: :remove
      metadata gql_exclude: true
    end

    action :remove do
      allow role: :super_admin
    end

    action :list do
      allow {:role, :admin}
      allow {:role, :client}
    end

    action :view do
      allow {:role, :admin}
      allow [{:role, :client}, :same_company]
      allow :same_user
    end
  end
end
