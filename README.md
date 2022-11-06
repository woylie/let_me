# LetMe

[![CI](https://github.com/woylie/let_me/workflows/CI/badge.svg)](https://github.com/woylie/let_me/actions) [![Hex](https://img.shields.io/hexpm/v/let_me)](https://hex.pm/packages/let_me) [![Hex Docs](https://img.shields.io/badge/hex-docs-green)](https://hexdocs.pm/let_me/readme.html) [![Coverage Status](https://coveralls.io/repos/github/woylie/let_me/badge.svg)](https://coveralls.io/github/woylie/let_me)

LetMe is an authorization library for Elixir.

It aims to give you an easy, readable and flexible way of defining authorization
rules by defining a simple DSL, while also giving you introspection functions
that allow you to answer questions like:

- Which actions are defined in my application?
- What are the conditions for a certain action?
- Which actions are allowed for a user with a certain role?

## Installation

Add LetMe to `mix.exs` :

```elixir
def deps do
  [
    {:let_me, "~> 0.2.0"}
  ]
end
```

Add LetMe to `.formatter.exs`:

```elixir
[
  import_deps: [:let_me]
]
```

## Policy module

The heart of LetMe is the Policy module. It provides a set of macros for
defining the authorization rules of your application. These rules are compiled
to authorization and introspection functions.

A policy module for a simple article CRUD interface might look like this:

```elixir
defmodule MyApp.Policy do
  use LetMe.Policy

  object :article do
    # Creating articles is allowed if the user role is `editor` or `writer`.
    action :create do
      allow role: :editor
      allow role: :writer
    end

    # Viewing articles is always allowed, unless the user is banned.
    action :read do
      allow true
      deny :banned
    end

    # Updating an article is allowed if (the user role is `editor`) OR
    # (the user role is `writer` AND the article belongs to the user).
    action :update do
      allow role: :editor
      allow [:own_resource, role: :writer]
    end

    # Deleting an article is allowed if the user is an editor.
    action :delete do
      allow role: :editor
    end
  end
end
```

Whether you want to have a single policy module for your whole application,
or one per context, or whether you want to break it up in any other way is up
to you.

## Check module

In general, authorization rules are based on the subject (usually the current
user), the object on which the action is performed, and the action (verb).
LetMe does not make any assumptions on the authorization model or check
implementation.

The checks passed to `LetMe.Policy.allow/1` reference functions in the check
module (by default `__MODULE__.Checks`, so in the example
`MyApp.Policy.Checks`). Each check function must take the subject, the object,
and optionally an additional argument, and must return a boolean value.

The check module for the policy module above might look like this:

```elixir
defmodule MyApp.Policy.Checks do
  alias MyApp.Accounts.User

  @doc """
  Returns `true` if the `banned` flag is set on the user.
  """
  def banned(%User{banned: banned}, _, _), do: banned

  @doc """
  Checks whether the user ID of the object matches the ID of the current user.

  Assumes that the object has a `:user_id` field.
  """
  def own_resource(%User{id: id}, %{user_id: id}, _opts) when is_binary(id), do: true
  def own_resource(_, _, _), do: false

  @doc """
  Checks whether the user role matches the role passed as an option.

  ## Usage

      allow role: :editor

  or

      allow {:role, :editor}
  """
  def role(%User{role: role}, _object, role), do: true
  def role(_, _, _), do: false
end
```

## Callbacks

With `use LetMe.Policy` at the top of your policy module, LetMe will generate
several functions for you.

- Authorization functions: See `c:LetMe.Policy.authorize/3`,
  `c:LetMe.Policy.authorize!/3` and `c:LetMe.Policy.authorize?/3`.
- Introspection functions: See `c:LetMe.Policy.list_rules/0`,
  `c:LetMe.Policy.list_rules/1`, `c:LetMe.Policy.get_rule/1` and others.

### Authorization

You can use the authorization functions wherever you need to make authorization
decisions, for example in your context module:

```elixir
defmodule MyApp.Blog do
  alias MyApp.Accounts.User
  alias MyApp.Blog.Article
  alias MyApp.Policy

  def list_articles(%User{} = current_user) do
    with :ok <- Policy.authorize(:article_read, current_user) do
      {:ok, Repo.all(Article)}
    end
  end

  def fetch_article(id, %User{} = current_user) do
    with :ok <- Policy.authorize(:article_read, current_user, id) do
      case Repo.get(Article, id) do
        nil -> {:error, :not_found}
        article -> {:ok, article}
      end
    end
  end

  def create_article(params, %User{} = current_user) do
    with :ok <- Policy.authorize(:article_create, current_user) do
      %Article{}
      |> Article.changeset(params)
      |> Repo.insert()
    end
  end

  def update_article(%Article{} = article, params, %User{} = current_user) do
    with :ok <- Policy.authorize(:article_update, current_user, article) do
      article
      |> Article.changeset(params)
      |> Repo.update()
    end
  end

  def delete_article(%Article{} = article, %User{} = current_user) do
    with :ok <- Policy.authorize(:article_delete, current_user, article) do
      Repo.delete(article)
    end
  end
end
```

### Introspection

With the introspection functions, you can get the complete list of authorization
rules, e.g. to display them in a documentation page:

```elixir
iex> MyApp.Policy.list_rules()
[
  %LetMe.Rule{
    action: :create,
    allow: [
      [role: :admin],
      [role: :writer]
    ],
    deny: [],
    description: nil,
    name: :article_create,
    object: :article,
    pre_hooks: []
  },
  # ...
]
```

You can also find a rule by its name:

```elixir
iex> MyApp.Policy.get_rule(:article_create)
%LetMe.Rule{
  action: :create,
  allow: [
    [role: :admin],
    [role: :writer]
  ],
  name: :article_create,
  object: :article,
  # ...
}
```

Or you can list all actions tied to a certain role (or any other check):

```elixir
iex> MyApp.Policy.list_rules(role: :writer)
[
  %LetMe.Rule{
    action: :create,
    object: :article,
    # ...
  },
  %LetMe.Rule{
    action: :update,
    object: :article,
    # ...
  }
]
```

## Scoped queries

Even if a user is generally allowed to see a certain resource type, they may
only be allowed to see a subset of the data. For example, in a blog system, a
user might only be allowed to see published articles, unless they are a writer.
Or in a system where users belong to companies, a company user might only be
allowed to see users who belong to the same company.

In order to scope your queries depending on the user type, you can implement the
`c:LetMe.Schema.scope/3` callback of the `LetMe.Schema` behaviour, usually in
your Ecto schema module.

```elixir
defmodule MyApp.Blog.Article do
  use Ecto.Schema
  use LetMe.Schema

  import Ecto.Query
  alias MyApp.Accounts.User

  # Ecto schema and changeset

  @impl LetMe.Schema
  def scope(q, user, opts \\ nil)
  def scope(q, %User{role: :editor}, _), do: q
  def scope(q, %User{role: :writer}, _), do: q
  def scope(q, %User{}, _), do: where(q, published: true)
end
```

Here, the Ecto query is modified to only return published articles, unless the
user is an editor or writer. You can use the third argument for additional
options.

With this, you can then update your list and fetch functions:

```elixir
def list_articles(%User{} = current_user) do
  with :ok <- Policy.authorize(:article_read, current_user) do
    articles =
      Article
      |> Article.scope(current_user)
      |> Repo.all()

    {:ok, articles}
  end
end

def fetch_article(id, %User{} = current_user) do
  with :ok <- Policy.authorize(:article_read, current_user, id) do
    result =
      Article
      |> where(id: ^id)
      |> Article.scope(current_user)
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      article -> {:ok, article}
    end
  end
end
```

Looks familiar? Yes, this is nearly the same as in
[Bodyguard](https://hex.pm/packages/bodyguard). However, Bodyguard exposes a
`Bodyguard.scope/2` function, which does nothing more than to derive the Ecto
schema module from the `Ecto.Queryable` and dispatch the call to that module.
But since you usually know which schema module you are dealing with, I believe
this is of limited use, and hence you need to call the `scope/2` function of
your Ecto schema directly. The behaviour then only serves to enforce the
pattern.

## Field redactions

Sometimes a user may be allowed to retrieve a resource, but some fields should
be hidden. For example, a user might be allowed to see some general information
about another user, such as the name and avatar, but should not be able to see
contact information like the email or the phone number. You could handle
situations like this by conditionally showing or hiding certain information in
the frontend, but it would be cleaner if the context functions would not return
those fields in the first place.

To assist in these kinds of situations, the `LetMe.Schema` behaviour has another
callback: `c:LetMe.Schema.redacted_fields/3`.

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  use LetMe.Schema

  alias MyApp.Accounts.User

  # Ecto schema and changeset

  @impl LetMe.Schema
  def redacted_fields(%User{}, %User{role: :admin}, _), do: []
  def redacted_fields(%User{id: id}, %User{id: id}, _), do: []
  def redacted_fields(%User{}, %User{}, _), do: [:email, :phone_number]
end
```

The `redacted_fields/2` function takes the object as the first argument and the
subject as the second argument. The third argument can be used to pass any
additional options. The function returns a list of fields that need to be
redacted.

In the example above, all fields are visible if the user is an admin or if the
user that is viewed (the object) is the same as the current user (the subject).
In all other cases, the email and phone number are hidden.

You have two options to handle field redactions:

1. Modify the query to not select the redacted fields.
2. Redact the fields after retrieving the resource(s) from the database.

### Modifying the query

You can get the non-virtual schema fields with the `__schema__/1` function that
Ecto defines in your Ecto module, reject the redacted fields from the list and
then add a select clause with only the unredacted fields.

```elixir
def list_users(%User{} = current_user) do
  fields = User.__schema__(:fields)
  filtered_fields = LetMe.reject_redacted_fields(fields, %User{}, current_user)

  Article
  |> select(^filtered_fields)
  |> Repo.all()
end
```

The advantage of this method is that the fields won't even be transferred from
the DB.

The drawback is that you cannot make decisions on which fields to select
based on data in the struct. Used with the `redacted_fields/2` function above,
we can make sure that admins can see all fields, but we can not make sure that
users can see all fields of their own user account.

Another drawback is that all redacted fields will be returned as `nil`, and you
won't be able to distinguish which fields were redacted and which fields are
just empty, which might be information you would want to display in the
frontend.

Also, you might have more complex select clauses that are not compatible with
this syntax.

### Redacting the query result

To mitigate these shortcomings, you can do the redactions _after_ retrieving the
data from the database using `LetMe.redact/2`.

```elixir
def list_articles(%User{} = current_user) do
  Article
  |> Repo.all()
  |> LetMe.redact(current_user)
end
```

The `redact` function can handle structs, lists of structs, and `nil` values.

## Why would I want to use this library?

- You want an easy-to-read DSL for authorization rules that still allows you
  to implement your authorization checks in any way you want.
- You prefer to put your authorization rules into your business layer and
  decouple them from your interfaces.
- You prefer to keep your authorization rules in one place (or one place per
  context, or similar).
- You want to generate a list of authorization rules.
- You want to filter your authorization rules, e.g. to find out which actions
  are available to a certain user role.
- You want a library that can also help you with query scopes and field
  redactions.
- You want a library with zero dependencies.

## Why wouldn't I want to use this library?

- You prefer to couple authorization checks to your interfaces.
- You prefer to use plugs or middlewares for authorization checks and want the
  necessary plumbing ready for use (you can of course build your own plugs and
  middlewares around the functions of this library).
- You don't like DSLs and prefer to write functions (note that the DSL only
  describes _which_ checks to run and _how_ to apply them, though; you still
  write the actual checks as regular functions).
- You don't care about introspection.
- You want to return details on _why_ an authorization request fails. Checks
  in LetMe must currently return a boolean value, which means you'll only be
  able to give your users a generic error, without telling them which exact
  check failed.

## Alternatives

For comparison, please have a look at these Elixir libraries:

- [Canada](https://hex.pm/packages/canada)
- [Canary](https://hex.pm/packages/canary)
- [Bodyguard](https://hex.pm/packages/bodyguard)
- [Speakeasy](https://hex.pm/packages/speakeasy)

You might also find the article
[Authorization for Phoenix Contexts](https://dockyard.com/blog/2017/08/01/authorization-for-phoenix-contexts) helpful.
