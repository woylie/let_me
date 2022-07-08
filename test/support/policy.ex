defmodule MyApp.Policy do
  @moduledoc false

  use Expel.Policy

  object :article do
    action :create do
      allow role: :admin
      allow role: :writer
    end

    action :update do
      pre_hooks :preload_groups
      allow :own_resource
    end

    action :view do
      allow true
    end
  end

  object :user do
    action :delete do
      allow role: :admin
      deny :same_user
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
