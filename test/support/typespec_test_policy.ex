defmodule LetMe.TypespecTestPolicy do
  @moduledoc """
  This is a trivial policy for the purposes of testing typespec generation.
  """
  use LetMe.Policy

  object :type_check do
    action :read do
      allow :own_resource
    end

    action :write do
      allow :same_user
    end
  end

  # A test call to test the behaviour of the typespecs. When
  # `MIX_ENV=test mix dialyzer` is run, this should generate a warning for the
  # `:invalid_action` call, but not the `:type_check_read` one.
  def test_call do
    authorize(:type_check_read, nil, nil)
    authorize(:invalid_action, nil, nil)
  end
end
