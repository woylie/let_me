defmodule MyApp.PolicyCaller do
  @moduledoc false

  # This module isn't used in any tests. It exists to catch a regression where
  # a rule that always evaluates to a literal causes a compile-time warning
  # about dead branches in the caller. If a rule is temporarily set to a
  # literal, the caller's branches should remain in place, or else there is
  # a risk of forgetting to reinstate them once the rule is made dynamic
  # again.
  def view_article(subject) do
    if MyApp.Policy.authorize?(:article_view, subject) do
      :allowed
    else
      :denied
    end
  end

  def view_denied_article(subject) do
    if MyApp.PolicyDenyTrue.authorize?(:article_view, subject) do
      :allowed
    else
      :denied
    end
  end
end
