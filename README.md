# Expel

Expel is an Elixir library that aims to solve three aspects of authorization:

1. Permissions: Determine whether the user is allowed to execute an action.
2. Scopes: Manipulate queries, so that no resources are returned that the user is not allowed to see.
3. Redactions: Hide certain fields on a resource depending on the user.

## Installation

Add Expel to `mix.exs` :

```elixir
def deps do
  [
    {:expel, "~> 0.1.0"}
  ]
end
```

Add Expel to `.formatter.exs`:

```elixir
[
  import_deps: [:expel]
]
```

## Quickstart

Define a policy module:

```elixir
defmodule MyApp.Policy do
  use Expel

  object :user do
    action :list do
      # Listing users is allowed for users with the role :admin and client.
      # The checks passed to `allow` point to the functions in the Checks
      # module (by default `__MODULE__.Checks`).
      allow [role: :admin]
      allow [role: :client]
    end

    action :view do
      # A user can be viewed if the user is an admin
      # OR if the current user is a client and belongs to the same company as the object
      # OR if the current user is the same as the object.
      allow [role: :admin]
      allow [role: :client, :same_company]
      allow :same_user
    end

    action :delete do
      # A user can be deleted if the user is an admin,
      # BUT NOT if the current user is the same user as the subject.
      allow [role: :admin]
      deny :same_user
    end

  end

  object :article do
    action :view do
      # An article can be viewed by anybody without conditions,
      # UNLESS the user is banned.
      allow true
      deny :banned
    end
  end
end
```

Every check has to be implemented in the Checks module (default:
`__MODULE__.Checks`). Each function takes the subject (current user), object (on
which to perform the action), and additional options as arguments; they must
return a boolean.

```elixir
defmodule MyApp.Policy.Checks do
  alias MyApp.Accounts.User

  def banned(%User{banned: banned}, _, _), do: banned

  def role(%User{role: role}, _object, role), do: true
  def role(_, _, _), do: false

  def same_user(%User{id: id}, %User{id: id}, _opts), do: true
  def same_user(%User{id: id}, id, _opts), do: true
  def same_user(_, _, _), do: false

  def same_company(%User{company_id: id}, %User{company_id: id}, _opts) when is_binary(id), do: true
  def same_company(_, _, _), do: false
end
```

Implement the `Expel.Schema` protocol for your Ecto struct, if needed.

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  # schema

  defimpl Expel.Protocol do
    import Ecto.Query

    alias MyApp.Accounts.User

    def scope(_, q, %User{role: :admin}), do: q

    def scope(_, q, %User{role: :client, company_id: company_id}) do
      where(q, company_id: ^company_id)
    end

    def redact(%User{role: :admin}, _), do: []
    def redact(%User{role: :client}, _), do: [:flagged, :status]
  end
end
```

And finally, add permission checks, scoping and/or redactions to your context module.

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Accounts.User
  alias MyApp.Policy

  def list_users(%User{} = current_user) do
    with :ok <- Policy.permit(:user_list, current_user) do
      result =
        User
        |> Expel.scope(current_user)
        |> Repo.all()
        |> Expel.redact(current_user)

      {:ok, result}
    end
  end

  def fetch_user(id, %User{} = current_user) do
    with :ok <- Policy.permit(:user_view, current_user, id) do
      result =
        User
        |> Expel.scope(current_user)
        |> Repo.one()
        |> Expel.redact(current_user)

      case result do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    end
  end

  def delete_user(%User{} = object, %User{} = current_user) do
    with :ok <- Policy.permit(:user_delete, current_user, object) do
      Repo.delete(subject)
    end
  end
end
```

## Design Decisions and Usage

### Permissions

While the authentication method may differ depending on whether you are dealing with a server-side rendered page opened in the browser, a GraphQL or REST API used by a frontend, or an internal API used for service-to-service communication, the authorization rules will be the same for every interface once you know who the user is. Authorization should be part of the business logic, so that the rules are consistently applied independently of the interface.

Since the authorization rules are a vital concern of an application, it makes sense to define them in a central place, so that you can understand your rule set at a glance.

You could use a simple function to check permissions for your actions. For example, [Canada](https://hex.pm/packages/canada) requires you to implement a protocol with a single `can?/3` function for your subject, i.e. user struct:

```elixir
defimpl Canada.Can, for: MyApp.Accounts.User do
  alias MyApp.Accounts.User
  alias MyApp.Blog.Post

  def can?(%User{id: user_id}, :update_post, %Post{user_id: user_id}), do: true
  def can?(%User{role: :admin}, :update_post, _), do: true
end
```

Similarly, [Bodyguard](https://hex.pm/packages/bodyguard) requires you to implement a behaviour with a single `authorize/3` function:

```elixir
defmodule MyApp.Blog do
  @behaviour Bodyguard.Policy

  alias MyApp.Accounts.User
  alias MyApp.Blog.Post

  def authorize(:update_post, %User{role: :admin}, _post), do: :ok
  def authorize(:update_post, %User{id: id}, %Post{user_id: id}), do: :ok
  def authorize(:update_post, _, _), do: :error
end
```

There are two issues with these approaches.

1. You have to carefully read the function clauses to understand the rules (you could improve readability by defining check functions to be called in the protocol/behaviour function, of course).
2. There is no introspection. It is not possible to programmatically answer questions like:

- Which actions are defined in my application?
- What are the conditions for a certain action?
- Which actions are allowed for a user with a certain role?

To address these issues, this library defines a DSL for authorization rules. It compiles functions for both permission requests and introspection. You will have to define two modules: One _policy_ module that defines the authorization rules in a readable format, and one _checks_ module that implements the actual checks depending on your requirements. If you have a large application, you might prefer to have a separate policy module for each context.

We can translate the Canada and Bodyguard example from above to the DSL as follows:

```elixir
defmodule MyApp.Policy do
  use Expel

  object :post do
    action :update do
      allow [role: :admin]
      allow [:own_resource]
    end
  end
end

defmodule MyApp.Policy.Checks do
  alias MyApp.Accounts.User

  @doc """
  Allows action if the user has the given role.
  """
  def role(%User{role: role}, _object, role), do: true
  def role(_, _, _), do: false

  @doc """
  Allows action if the given resource belongs to the user.
  """
  def own_resource(%User{id: id}, %{user_id: id}, _opts), do: true
  def own_resource(_, _, _), do: false
end
```

This way, the rule expressions are separate from the check implementations,
allowing you to reuse checks in your rules, and increasing the readability of
your authorization rules.

The `rules` macro will define two sets of functions: _permit_ functions and
_introspection_ functions. You can use the `permit` functions in your context
module:

```elixir
defmodule MyApp.Blog do
  alias MyApp.Blog.Post
  alias MyApp.Policy

  def update_post(%Post{} = post, %{} = params, %User{} = current_user) do
    with :ok <- Policy.permit(:update_post, current_user, post) do
      post
      |> Post.changeset(params)
      |> Repo.update()
    end
  end
end
```

With the introspection functions, you can get the complete list of authorization rules, e.g. to display in a documentation page:

```elixir
iex> MyApp.Policy.list_rules()
[
  %Expel.Rule{
    action: :update,
    allow: [
      [role: :admin],
      [:own_resource]
    ],
    object: :post,
    deny: []
  }
]
```

You can also get the conditions for a certain action:

```elixir
iex> MyApp.Policy.get_rule()
%Expel.Rule{
  action: :update,
  allow: [
    [role: :admin],
    [:own_resource]
  ],
  object: :post,
  deny: []
}
```

Or you can list all actions for a certain role (or any other check):

```elixir
iex> MyApp.Policy.list_rules(role: :admin)
[
  %Expel.Rule{
    action: :update,
    allow: [
      [role: :admin],
      [:own_resource]
    ],
    object: :post,
    deny: []
  }
]
```

#### Pre-hooks

Sometimes you might need to load additional data from the database or process the data that is passed to the check functions in other ways. If the same enhanced data is needed for multiple checks of the same action, it would be less than ideal to do the processing in each check function. Instead, you can define a pre-hook.

```elixir
object :post do
  action :update do
    pre_hook :preload_groups

    allow [:active_group]
    allow [:some_other_check]
  end
end
```

You can reference a hook function in several ways.

- The name of a function defined in the same module as an atom: `:preload_groups`
- A module/function tuple: `{MyApp.SomeModule, :preload_groups}`
- A module/function/arguments tuple: `{MyApp.SomeModule, :preload_groups, force: true}`

In either case, the function will need to take the subject (current user) as the first argument, the object as the second argument, and in the case of an mfa tuple, the arguments as a third argument. It must return a tuple with the updated subject and object.

Assuming that a user belongs to a group, and we need some fields from the group for our checks, we could do something like:

```elixir
def preload_groups(%User{} = user, %Post{} = post) do
  {Repo.preload(user, :group), post}
end
```

### Scopes

Even if a user is allowed to retrieve a list of resources, they may only be allowed to see a subset of the data. For example, in a blog system, a user might only be allowed to see published posts, unless they are a writer. Or in a system where users belong to companies, a company user might only be allowed to see users who belong to the same company.

To do this, you first will need to implement the `Expel.Schema` protocol.

```elixir
defmodule MyApp.Blog.Article do
  use Ecto.Schema

  # schema

  defimpl Expel.Protocol do
    import Ecto.Query

    alias MyApp.Accounts.User
    alias MyApp.Blog.Article

    def scope(_, q, %User{role: :admin}), do: q
    def scope(_, q, %User{}), do: where(q, published: true)

    def redact(_, _), do: []
  end
end
```

The protocol has two functions: `redact/2` (explained below) and `scope/3`. The `scope` function takes the Ecto query as the second argument, the current user as the third argument, and returns the updated query. You can then use `Expel.scope/3` in your context functions:

```elixir
def list_articles(%User{} = current_user) do
  Article
  |> Expel.scope(current_user)
  |> Repo.all()
end

def get_article(id, %User{} = current_user) when is_binary(id) do
  Article
  |> where(id: ^id)
  |> Expel.scope(current_user)
  |> Repo.all()
end
```

Looks familiar? Yes, this is nearly the same as in [Bodyguard](https://hex.pm/packages/bodyguard).

### Redactions

Sometimes a user may be allowed to retrieve a resource, but some fields should be hidden. For example, a user might be allowed to see some general information about another user, such as the name and avatar, but should not be able to see contact information like the email or the phone number. You could handle situations like this by conditionally showing or hiding certain information in the frontend, but it would be cleaner if the context functions would not return those fields in the first place.

You have two options to handle this with this library:

1. Add a `select` clause to the query to only select fields the user may see.
2. Redact the fields after retrieving the resource from the database.

In both cases, you will first have to implement the `redact` function of the `Expel.Protocol` protocol.

```elixir
defmodule MyApp.Blog.Article do
  use Ecto.Schema

  # schema

  defimpl Expel.Protocol do
    alias MyApp.Accounts.User
    alias MyApp.Blog.Article

    # scope

    def redact(%Article{}, %User{role: :admin}), do: []
    def redact(%Article{}, %User{}), do: [:internal_reference]
  end
end
```

The `redact/2` functions takes the current user as the second argument and returns a list of fields that need to be hidden.

You can then use `Expel.unredacted_fields/2` to get the fields the user is allowed to see and use the result in your `select` clause.

```elixir
def list_articles(%User{} = current_user) do
  fields = Expel.unredacted_fields(Article, current_user)

  Article
  |> select(^fields)
  |> Repo.all()
end

def get_article(id, %User{} = current_user) do
  fields = Expel.unredacted_fields(Article, current_user)

  Article
  |> select(^fields)
  |> where(id: ^id)
  |> Repo.one()
end
```

The advantage of this method is that the fields won't even be transferred from the DB. The drawback is that you cannot make decisions on which fields to select based on data in the struct. For example, you might want to redact certain fields, unless the user is the owner of the resource. Another drawback is that all redacted fields will be returned as `nil`, and you won't be able to distinguish which fields were redacted and which fields are just empty, which might be information you would want to display in the frontend. Also, you might have more complex select clauses that are not compatible with this syntax.

To mitigate these shortcomings, you can do the redactions _after_ retrieving the data from the database using `Expel.redact/2`.

```elixir
def list_articles(%User{} = current_user) do
  Article
  |> Repo.all()
  |> Expel.redact(current_user)
end

def get_article(id, %User{} = current_user) do
  Article
  |> Repo.get(id)
  |> Expel.redact(current_user)
end
```

Now you can update your protocol implementation to take the article ownership into consideration:

```elixir
defimpl Expel.Protocol do
  alias MyApp.Accounts.User
  alias MyApp.Blog.Article

  def redact(%Article{}, %User{role: :admin}), do: []
  def redact(%Article{user_id: id}, %User{id: id}), do: []
  def redact(%Article{}, %User{}), do: [:internal_reference]
end
```

You can also set the value to be used for redacted fields:

```elixir
def list_articles(%User{} = current_user) do
  Article
  |> Repo.all()
  |> Expel.redact(current_user, redacted_value: :redacted)
end
```

The `redact` function can handle structs, lists of structs, and `nil` values.

#### Changesets

You might have a situation where a user can update a resource, but may not see all the fields, which of course means that the redacted fields should not be cast. While you should probably implement your changeset so that it takes the current user into consideration, you can use `Expel.filter_redacted_fields/2` to retrieve the redacted fields and add a safeguard to prevent accidentally casting and nilifying them.

```elixir
def update_changeset(%Article{} = article, attrs, %User{} = current_user) do
  fields = Expel.filter_redacted_fields(
    [:title, :body, :internal_reference],
    article,
    current_user
  )

  article
  |> cast(attrs, fields)
  |> validate_required([:title, :body])
end
```

## Alternatives

If you don't want to use a DSL and you don't need introspection, or if you prefer a ready-made solution to handle your authorization with plugs or resolvers instead of adding checks to your context functions, have a look at these Elixir libraries:

- [Canada](https://hex.pm/packages/canada)
- [Canary](https://hex.pm/packages/canary)
- [Bodyguard](https://hex.pm/packages/bodyguard)
- [Speakeasy](https://hex.pm/packages/speakeasy)
