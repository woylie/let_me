defmodule MyApp.PolicyCombinations do
  @moduledoc false

  use Expel.Policy

  object :simple do
    action :allow_without_options do
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
  end

  object :complex do
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
  end
end