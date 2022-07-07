defmodule MyApp.PolicyShort do
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
  end
end
