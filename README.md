# LetMe

[![CI](https://github.com/woylie/let_me/workflows/CI/badge.svg)](https://github.com/woylie/let_me/actions) [![Hex](https://img.shields.io/hexpm/v/let_me)](https://hex.pm/packages/let_me) [![Hex Docs](https://img.shields.io/badge/hex-docs-green)](https://hexdocs.pm/let_me/readme.html) [![Coverage Status](https://coveralls.io/repos/github/woylie/let_me/badge.svg)](https://coveralls.io/github/woylie/let_me)

LetMe is an authorization library for Elixir that allows you to define your
authorization rules with a Domain Specific Language (DSL).

It also provides introspection function that enable you to answer questions
such as:

- Which actions are defined in my application?
- What are the conditions for a particular action?
- Which actions are permissible for a user assigned a specific role?

## Installation

Add LetMe to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:let_me, "~> 1.2.5"}
  ]
end
```

Include LetMe in your `.formatter.exs` file:

```elixir
[
  import_deps: [:let_me]
]
```

This ensures that your LetMe authorization rules are formatted correctly when
you run `mix format`.

## Policy module

You define your authorization rules in a policy module using the LetMe macros.
These rules are then compiled into functions for both authorization checks and
introspection.

For instance, here's how you might define a policy for a simple article CRUD
interface:

```elixir
defmodule MyApp.Policy do
  use LetMe.Policy

  object :article do
    # Creating articles is allowed if the user role is `editor` or `writer`.
    action :create do
      allow role: :editor
      allow role: :writer
      desc "Create a new article"
    end

    # Viewing articles is always allowed, unless the user is banned.
    action :read do
      allow true
      deny :banned
      desc "Read an article"
    end

    # Updating an article is allowed if (the user role is `editor`) OR
    # (the user role is `writer` AND the article belongs to the user).
    action :update do
      allow role: :editor
      allow [:own_resource, role: :writer]
      desc "Update an article"
    end

    # Deleting an article is allowed if the user is an editor.
    action :delete do
      allow role: :editor
      desc "Delete an article"
    end
  end
end
```

You can work with a single policy module, or you can define one policy module
for each of your contexts.

While this example uses Role-Based Access Control (RBAC), LetMe doesn't make any
assumptions about your access control model. You are completely free to define
your authorization rules in any way you see fit.

## Check module

Authorization rules are based on the subject (usually the current user), the
object on which the action is performed, and the action itself (the verb). LetMe
doesn't enforce a particular authorization model or check implementation.

The checks passed to `LetMe.Policy.allow/1` reference functions in your own
check module (by default `__MODULE__.Checks`, so in the given example, this
would be `MyApp.Policy.Checks`). Each function in your check module should
accept the subject, the object, and optionally an extra argument. If no options
are passed to `allow` or `deny` (e.g. `deny :banned`), the check function must
be a 2-arity function. If an option is passed (e.g. `allow role: :writer`), the
function must be a 3-arity function. All check functions must return a boolean
value indicating the result of the check.

For the policy example provided earlier, a corresponding check module could look
like this:

```elixir
defmodule MyApp.Policy.Checks do
  alias MyApp.Accounts.Scope
  alias MyApp.Accounts.User

  @doc """
  Returns `true` if the `banned` flag is set on the user.
  """
  def banned(%Scope{current_user: %User{banned: banned}}, _), do: banned

  @doc """
  Checks whether the user ID of the object matches the ID of the current user.

  Assumes that the object has a `:user_id` field.
  """
  def own_resource(
    %Scope{current_user: User{id: id}},
    %{user_id: id}
  ) when is_binary(id), do: true
  def own_resource(_, _), do: false

  @doc """
  Checks whether the user role matches the role passed as an option.

  ## Usage

      allow role: :editor

  or

      allow {:role, :editor}
  """
  def role(%Scope{current_user: %User{role: role}}, _object, role), do: true
  def role(_, _, _), do: false
end
```

Note the usage of the `Scope` struct. This is a struct defined in your
application that at the very least contains the current user, but it might also
include other relevant information, like the remote IP address or the
authenticator assurance level (AAL).

The usage of the `Scope` struct is in line with a new feature of the Phoenix
generators introduced in Phoenix 1.8. You could also use the `User` struct
directly, but basing authorization rules on a `Scope` struct will make it
easier to update your application later on if your authorization requirements
become more complex.

## Callbacks

Adding `use LetMe.Policy` to the start of your policy module will generate
several functions from the authorization rules:

- Authorization functions: See `c:LetMe.Policy.authorize/4`,
  `c:LetMe.Policy.authorize!/4` and `c:LetMe.Policy.authorize?/4`.
- Introspection functions: See `c:LetMe.Policy.list_rules/0`,
  `c:LetMe.Policy.list_rules/1`, `c:LetMe.Policy.get_rule/1` and others.

### Authorization

With the authorization rules and checks in place, you can authorize user actions
wherever needed. A natural place are the functions in your context modules. This
way, authorization checks are part of your business logic, and they will be
applied independently from the interface that is used. For example, even if you
have a LiveView application, a REST API, and a GraphQL API, the authorization
checks will only have to be added once to the context modules.

For example, we might have a Blog context like this:

```elixir
defmodule MyApp.Blog do
  alias MyApp.Accounts.Scope
  alias MyApp.Blog.Article
  alias MyApp.Policy

  def list_articles(%Scope{} = scope) do
    with :ok <- Policy.authorize(:article_read, scope) do
      {:ok, Repo.all(Article)}
    end
  end

  def fetch_article(%Scope{} = scope, id) do
    with :ok <- Policy.authorize(:article_read, scope, id) do
      case Repo.get(Article, id) do
        nil -> {:error, :not_found}
        article -> {:ok, article}
      end
    end
  end

  def create_article(%Scope{current_user: %User{} = current_user}, params) do
    with :ok <- Policy.authorize(:article_create, current_user) do
      %Article{}
      |> Article.changeset(params)
      |> Repo.insert()
    end
  end

  def update_article(
    %Scope{current_user: %User{} = current_user},
    %Article{} = article,
    params
  ) do
    with :ok <- Policy.authorize(:article_update, current_user, article) do
      article
      |> Article.changeset(params)
      |> Repo.update()
    end
  end

  def delete_article(
    %Scope{current_user: %User{} = current_user},
    %Article{} = article
  ) do
    with :ok <- Policy.authorize(:article_delete, current_user, article) do
      Repo.delete(article)
    end
  end
end
```

Every context function takes the `Scope` struct as the first argument. Before
performing any actions on the articles, we first ensure the current user
is authorized to perform the intended action.

#### Typespecs

LetMe automatically generates typespecs for the authorize functions in your
policy modules, which helps Dialyzer to ensure that only valid actions are
passed to the authorize functions.

### Introspection

LetMe generates introspection functions for your authorization rules. This can
be useful if you want to render a documentation page, or if you want to show
a user's capabilities in their user profile.

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
    description: "Create a new article",
    name: :article_create,
    object: :article,
    pre_hooks: [],
    metadata: []
  },
  # ...
]
```

To find a specific rule by its name:

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

To list all actions associated with a particular role (or any other check):

```elixir
iex> MyApp.Policy.list_rules(allow: {:role, :writer})
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

You can also define metadata on an `action`, which can be used to extend
the library's functionality.

For example, imagine you want to expose certain actions through your Absinthe
GraphQL schema while excluding others. You could achieve this by adding a
`:gql_exclude` key to the metadata.

```elixir
defmodule GraphqlPolicy do
  use LetMe.Policy

  object :user do
    action :disable do
      allow role: :admin
      metadata :gql_exclude, true
    end
  end
end
```

```elixir
iex> MyApp.Policy.get_rule(:user_disable)
%LetMe.Rule{
  action: :disable,
  allow: [
    [role: :admin]
  ],
  deny: [],
  description: nil,
  name: :user_disable,
  object: :user,
  pre_hooks: [],
  metadata: [
    gql_exclude: true
  ]
}
```

## Scoped queries

Often, a user should have access to a certain resource type, but only to a
subset of the data. Consider a blog system: a user might be restricted to
viewing only published articles, unless they hold the role of a writer.
Similarly, in a system where users are part of specific companies, they might
only be allowed to see users from their own company.

To narrow down your queries based on the user type, implement the
`c:LetMe.Schema.scope/3` callback of the LetMe.Schema behavior, typically within
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

In this example, the Ecto query is modified to only return published articles,
unless the user is an editor or writer. The third argument can be utilized for
additional options.

With this setup, your list and fetch functions can be updated as follows:

```elixir
def list_articles(%Scope{current_user: %User{} = current_user} = scope) do
  with :ok <- Policy.authorize(:article_read, scope) do
    articles =
      Article
      |> Article.scope(current_user)
      |> Repo.all()

    {:ok, articles}
  end
end

def fetch_article(
  %Scope{current_user: %User{} = current_user} = scope,
  id
) do
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

If you've worked with [Bodyguard](https://hex.pm/packages/bodyguard) before,
this might look familiar. In Bodyguard,
you can find a `Bodyguard.scope/2` function that derives the Ecto schema module
from the `Ecto.Queryable` and forwards the call to that module. In LetMe, you
need to call the `scope/2` function of your Ecto schema directly. The behaviour
then only serves to enforce this pattern.

## Field redactions

In certain scenarios, a user may be authorized to access a resource, but should
only see a subset of its fields. For instance, a user might be able to see
basic details of another user, such as name and avatar, but shouldn't see
sensitive information like email or phone number. One way to manage such cases
would be to conditionally show or hide specific information on the frontend.
However, a cleaner solution is to have your context functions omit sensitive
fields entirely.

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

The `redacted_fields/2` function takes the object as the first argument, the
subject as the second argument, and an options argument. The function should
return a list of fields to redact.

In the example above, all fields are visible if the user has an 'admin' role, or
if the user being viewed (the object) is the same as the current user (the
subject). In other cases, the 'email' and 'phone_number' fields are hidden.

There are two strategies for handling field redactions:

1. Modify the query to exclude the redacted fields.
2. Redact the fields after retrieving the resource(s) from the database.

### Modifying the query

One approach to field redaction involves adjusting the database query to
exclude redacted fields. Ecto's `__schema__/1` function can retrieve the
non-virtual schema fields from your Ecto module. From this list, you can reject
any redacted fields and add a select clause that includes only the unredacted
fields.

```elixir
def list_users(%Scope{current_user: %User{} = current_user} = scope) do
  fields = User.__schema__(:fields)
  filtered_fields = LetMe.reject_redacted_fields(fields, %User{}, current_user)

  Article
  |> select(^filtered_fields)
  |> Repo.all()
end
```

This method has the advantage of preventing the transfer of redacted fields from
the database. However, it also comes with several drawbacks:

1. Decisions about which fields to select cannot be made based on data in the
   struct. For instance, with the `redacted_fields/2` function described
   earlier, we can ensure that admins can see all fields, but we cannot
   guarantee that users can view all fields in their own user account.
2. All redacted fields will appear as `nil`, and you won't be able to
   distinguish between fields that were redacted and fields that are simply
   empty. This distinction might be necessary for display in the frontend.
3. More complex select clauses may not be compatible with this syntax.

### Redacting the query result

To address the limitations of modifying the query, you can redact fields _after_
retrieving the data from the database. This can be done using the
`LetMe.redact/2` function.

```elixir
def list_articles(%User{} = current_user) do
  Article
  |> Repo.all()
  |> LetMe.redact(current_user)
end
```

The `redact` function can handle structs, lists of structs, and `nil` values.

## Why use this library?

Consider using this library if:

- You're seeking an easy-to-read DSL for authorization rules that offers the
  flexibility to implement your authorization checks as desired.
- You prefer to locate your authorization rules within your business layer,
  thereby decoupling them from your interfaces.
- You'd like to centralize your authorization rules in one place (or one per
  context).
- You want to generate a list of authorization rules.
- You need to filter your authorization rules, e.g., to identify which actions a
  certain user role can perform.
- You're in need of a library that aids with query scopes and field redactions.
- You prefer a library with zero dependencies.

## When not to use this library?

This library might not be the best fit if:

- You prefer to couple authorization checks with your interfaces.
- You favor using plugs or middlewares for authorization checks and require
  ready-made solutions (though you can create your own plugs and middlewares
  around this library's functions).
- You dislike DSLs and prefer to write functions directly (keep in mind, the DSL
  only describes which checks to run and how to apply them; you'll still write
  the actual checks as regular functions).
- Introspection isn't a priority for you.
- You need to provide details on why an authorization request fails. Checks in
  LetMe currently return only a boolean value, meaning users receive a generic
  error without knowing which exact check failed.

## Status

This library is actively maintained, but given its zero dependencies and
narrow feature set, you may not see frequent updates. If you ever find something
missing or encounter an issue, don't hesitate to open an issue.

## Alternatives

For comparison, consider exploring these Elixir libraries:

- [Canada](https://hex.pm/packages/canada)
- [Canary](https://hex.pm/packages/canary)
- [Bodyguard](https://hex.pm/packages/bodyguard)
- [Speakeasy](https://hex.pm/packages/speakeasy)

The article
[Authorization for Phoenix Contexts](https://dockyard.com/blog/2017/08/01/authorization-for-phoenix-contexts)
may also be a helpful resource.
