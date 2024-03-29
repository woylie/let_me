defmodule MyApp.PolicyShort do
  @moduledoc false

  use LetMe.Policy,
    check_module: MyApp.Checks,
    error_reason: :forbidden,
    error_message: "What were you thinking?"

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
