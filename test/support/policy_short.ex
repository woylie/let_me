defmodule MyApp.PolicyShort do
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
  end
end
