defmodule MyApp.Policy do
  @moduledoc false

  use Expel.Policy

  rules TestChecks do
    action :article_create do
      allow role: :admin
      allow role: :writer
    end

    action :article_update do
      pre_hooks :preload_groups

      allow :own_resource
    end

    action :article_view do
      allow true
    end

    action :user_delete do
      allow role: :admin
      disallow :same_user
    end

    action :user_list do
      allow {:role, :admin}
      allow {:role, :client}
    end

    action :user_view do
      allow {:role, :admin}
      allow [{:role, :client}, :same_company]
      allow :same_user
    end
  end
end
