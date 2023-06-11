defmodule LetMe.Schema do
  @moduledoc """
  Defines a behaviour with callbacks for scoping and redactions.

  Using this module will define overridable default implementations for the
  `c:scope/3` and `c:redacted_fields/3` callbacks.

  ## Usage

      defmodule MyApp.Blog.Article do
        use LetMe.Schema
        import Ecto.Schema
        alias MyApp.Accounts.User

        @impl LetMe.Schema
        def scope(q, user, opts \\\\ nil)
        def scope(q, %User{role: :admin}, _), do: q
        def scope(q, %User{}, _), do: where(q, published: true)

        @impl LetMe.Schema
        def redacted_fields(_, %User{role: :admin}, _), do: []
        def redacted_fields(%__MODULE__{user_id: id}, %User{id: id}, _), do: []
        def redacted_fields(_, %User{}, _), do: [:view_count]
      end

  > #### `use LetMe.Schema` {: .info}
  >
  > When you `use LetMe.Schema`, the module will set `@behaviour LetMe.Schema`
  > and define default implementations for the functions `scope/3` and
  > `redacted_fields/3`. Both functions are overridable.

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

  ## Redacting fields

  After implementing the `c:redacted_fields/3` callback, you can hide fields
  from depending on the user by calling `LetMe.redact/3` on a struct or a list
  of structs.

      def list_articles(%User{} = current_user) do
        Article
        |> Repo.all()
        |> LetMe.redact(current_user)
      end
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour LetMe.Schema

      def scope(q, _, _), do: q
      def redacted_fields(_, _, _), do: []

      defoverridable LetMe.Schema
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
        use LetMe.Schema

        import Ecto.Schema
        alias MyApp.Accounts.User

        # Ecto schema and changeset

        @impl LetMe.Schema
        def scope(q, user, opts \\\\ nil)
        def scope(q, %User{role: :admin}, _), do: q
        def scope(q, %User{}, _), do: where(q, published: true)
      end

  Since LetMe does not depend on Ecto and does not make any assumptions on the
  queryable passed to the callback function, you are not constrained to use this
  mechanism for Ecto queries only. For example, you could use the function to
  add filter parameters before passing them to a filter function or making an
  API call.

      @impl LetMe.Schema
      def scope(q, user, opts \\\\ nil)

      def scope(query_params, %User{role: :admin}, _), do: query_params

      def scope(query_params, %User{}, _) do
        Keyword.put(query_params, :published, true)
      end

  You can use the third argument to pass any additional options.
  """
  @callback scope(queryable, subject, opts) :: queryable
            when queryable: any, subject: any, opts: any

  @doc """
  Returns the fields that need to be removed from the given object for the given
  subject.

  This function can be used to hide certain fields depending on the current
  user. See also `LetMe.redact/3` and `LetMe.reject_redacted_fields/3`.

      defmodule MyApp.Blog.Article do
        use LetMe.Schema
        alias MyApp.Accounts.User

        @impl LetMe.Schema
        # hide view count unless the user is an admin or the article was written
        # by the user
        def redacted_fields(_, %User{role: :admin}, _), do: []
        def redacted_fields(%__MODULE__{user_id: id}, %User{id: id}, _), do: []
        def redacted_fields(_, %User{}, _), do: [:view_count]
      end

  The return value must be a list of fields to redact. You can also redact
  nested fields by passing the field names directly:

      [:email, sibling: [:phone_number]]

  Or you can pass the module name of a nested struct, if that module also
  implements `LetMe.Schema`:

      [:email, sibling: MyApp.Relative]

  The last argument can be used for any additional options.
  """
  @callback redacted_fields(object, subject, opts) :: redacted_fields()
            when object: any, subject: any, opts: keyword

  @type redacted_fields :: [atom | {atom, module | redacted_fields()}]
end
