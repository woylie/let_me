defmodule Expel.Schema do
  @moduledoc """
  Defines a behaviour with callbacks for scoping and redactions.

  Using this module will define overridable default implementations for the
  `scope/2` and `redacted_fields/2` callbacks.

  ## Usage

      defmodule MyApp.Blog.Article do
        use Expel.Schema
        import Ecto.Schema
        alias MyApp.Accounts.User

        @impl Expel.Schema
        def scope(q, %User{role: :admin}), do: q
        def scope(q, %User{}), do: where(q, published: true)

        @impl Expel.Schema
        def redacted_fields(_, %User{role: :admin}), do: []
        def redacted_fields(%__MODULE__{user_id: id}, %User{id: id}), do: []
        def redacted_fields(_, %User{}), do: [:view_count]
      end

  ## Scoping a query

  With the setup above, you can scope a blog article query depending on the
  user.

      defmodule MyApp.Blog do
        import Ecto.Query

        alias MyApp.Accounts.User
        alias MyApp.Blog.Article

        def list_articles(%User{} = current_user) do
          Article
          |> Article.scope(current_user)
          |> Repo.all()
        end

        def get_article(id, %User{} = current_user) when is_integer(id) do
          Article
          |> where(id: id)
          |> Article.scope(current_user)
          |> Repo.one()
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Expel.Schema

      def scope(q, _), do: q
      def redacted_fields(_, _), do: []

      defoverridable Expel.Schema
    end
  end

  @doc """
  Takes a queryable (usually an `Ecto.Queryable`) and a subject (usually the
  current user) and returns an updated queryable.

  This allows you to add `WHERE` clauses to a query depending on the user. For
  example, you may want to add a `WHERE` clause to only return articles that are
  published, unless the user is an admin. Or you may want to only return
  objects that belong to the user.

      defmodule MyApp.Blog.Article do
        use Ecto.Schema
        use Expel.Schema

        import Ecto.Schema
        alias MyApp.Accounts.User

        # Ecto schema and changeset

        @impl Expel.Schema
        def scope(q, %User{role: :admin}), do: q
        def scope(q, %User{}), do: where(q, published: true)
      end

  Since Expel does not depend on Ecto and does not make any assumptions on the
  queryable passed to the callback function, you are not constrained to use this
  mechanism for Ecto queries only. For example, you could use the function to
  add filter parameters before passing them to a filter function or making an
  API call.

      @impl Expel.Schema
      def scope(query_params, %User{role: :admin}), do: query_params

      def scope(query_params, %User{}) do
        Keyword.put(query_params, :published, true)
      end
  """
  @callback scope(queryable, subject) :: queryable
            when queryable: any, subject: any

  @doc """
  Returns the fields that need to be removed from the given object for the given
  subject.

  This function can be used to hide certain fields depending on the current
  user. See also `Expel.redact/3` and `Expel.reject_redacted_fields/3`.

      defmodule MyApp.Blog.Article do
        use Expel.Schema
        alias MyApp.Accounts.User

        @impl Expel.Schema
        # hide view count unless the user is an admin or the article was written
        # by the user
        def redacted_fields(_, %User{role: :admin}), do: []
        def redacted_fields(%__MODULE__{user_id: id}, %User{id: id}), do: []
        def redacted_fields(_, %User{}), do: [:view_count]
      end
  """
  @callback redacted_fields(object, subject) :: [atom]
            when object: any, subject: any
end
