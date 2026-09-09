defmodule MyApp.PolicyAllowTrue do
  @moduledoc false

  # This module isn't used in any tests. It exists to catch a regression where
  # "clause will never match" compile-time warnings are emitted if the
  # optimized expression is a literal.
  use LetMe.Policy, check_module: MyApp.Checks

  object :article do
    action :view do
      allow true
    end
  end
end
