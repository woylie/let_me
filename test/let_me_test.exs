defmodule LetMeTest do
  use ExUnit.Case
  doctest LetMe, import: true

  alias MyApp.Blog.Article

  @article %Article{
    like_count: 25,
    title: "Give us back our moon dust and cockroaches",
    user_id: 5,
    view_count: 200
  }

  @admin %{role: :admin, id: 1}
  @owner %{role: :user, id: 5}
  @user %{role: :user, id: 2}

  defmodule Person do
    use LetMe.Schema

    defstruct [:name, :email, :phone_number, :pet, :spouse, :age, :locale]

    @impl LetMe.Schema
    def redacted_fields(_, :nested_fields, _) do
      [:name, :phone_number, spouse: [:email, pet: [:weight]]]
    end

    def redacted_fields(_, :nested_schemas, _) do
      [:name, :phone_number, spouse: __MODULE__, pet: LetMeTest.Pet]
    end
  end

  defmodule Pet do
    use LetMe.Schema

    defstruct [:name, :email, :phone_number, :weight, :age]

    @impl LetMe.Schema
    def redacted_fields(_, :nested_schemas, _) do
      [:email, :age]
    end
  end

  describe "redact/3" do
    test "replaces struct keys with default value depending on user" do
      assert LetMe.redact(@article, @admin) == @article

      assert LetMe.redact(@article, @owner) ==
               %{@article | view_count: :redacted}

      assert LetMe.redact(@article, @user) ==
               %{@article | like_count: :redacted, view_count: :redacted}
    end

    test "replaces struct keys with given value depending on user" do
      opts = [redact_value: :removed]

      assert LetMe.redact(@article, @owner, opts) ==
               %{@article | view_count: :removed}

      assert LetMe.redact(@article, @user, opts) ==
               %{@article | like_count: :removed, view_count: :removed}
    end

    test "replaces keys in struct list with default value depending on user" do
      assert LetMe.redact([@article], @admin) == [@article]

      assert LetMe.redact([@article], @owner) ==
               [%{@article | view_count: :redacted}]

      assert LetMe.redact([@article], @user) ==
               [%{@article | like_count: :redacted, view_count: :redacted}]
    end

    test "replaces keys in struct list with given value depending on user" do
      opts = [redact_value: :removed]

      assert LetMe.redact([@article], @owner, opts) ==
               [%{@article | view_count: :removed}]

      assert LetMe.redact([@article], @user, opts) ==
               [%{@article | like_count: :removed, view_count: :removed}]
    end

    test "replaces nested lists of fields" do
      person = person()

      assert LetMe.redact(person, :nested_fields) ==
               %Person{
                 name: :redacted,
                 email: "juan@person",
                 phone_number: :redacted,
                 age: 25,
                 locale: "es",
                 pet: %Pet{
                   name: "Betty",
                   email: "betty@pet",
                   phone_number: "987",
                   weight: 8,
                   age: 7
                 },
                 spouse: %Person{
                   name: "Oliver",
                   email: :redacted,
                   phone_number: "456",
                   age: "28",
                   locale: "fr",
                   pet: %Pet{
                     name: "Rocky",
                     email: "rocky@pet",
                     phone_number: "654",
                     weight: :redacted,
                     age: 3
                   }
                 }
               }
    end

    test "uses redact function of referenced modules" do
      person = person()

      assert LetMe.redact(person, :nested_schemas) ==
               %Person{
                 name: :redacted,
                 email: "juan@person",
                 phone_number: :redacted,
                 age: 25,
                 locale: "es",
                 pet: %Pet{
                   name: "Betty",
                   email: :redacted,
                   phone_number: "987",
                   weight: 8,
                   age: :redacted
                 },
                 spouse: %Person{
                   name: :redacted,
                   email: "oliver@person",
                   phone_number: :redacted,
                   age: "28",
                   locale: "fr",
                   pet: %Pet{
                     name: "Rocky",
                     email: :redacted,
                     phone_number: "654",
                     weight: 5,
                     age: :redacted
                   }
                 }
               }
    end

    test "ignores NotLoaded structs" do
      person = %Person{
        name: "Juan",
        email: "juan@person",
        phone_number: "123",
        age: 25,
        locale: "es",
        pet: %Pet{
          name: "Betty",
          email: "betty@pet",
          phone_number: "987",
          weight: 8,
          age: 7
        },
        spouse: %Ecto.Association.NotLoaded{}
      }

      assert LetMe.redact(person, :nested_fields) ==
               %Person{
                 name: :redacted,
                 email: "juan@person",
                 phone_number: :redacted,
                 age: 25,
                 locale: "es",
                 pet: %Pet{
                   name: "Betty",
                   email: "betty@pet",
                   phone_number: "987",
                   weight: 8,
                   age: 7
                 },
                 spouse: %Ecto.Association.NotLoaded{}
               }

      assert LetMe.redact(person, :nested_schemas) ==
               %Person{
                 name: :redacted,
                 email: "juan@person",
                 phone_number: :redacted,
                 age: 25,
                 locale: "es",
                 pet: %Pet{
                   name: "Betty",
                   email: :redacted,
                   phone_number: "987",
                   weight: 8,
                   age: :redacted
                 },
                 spouse: %Ecto.Association.NotLoaded{}
               }
    end

    test "handles nil value" do
      assert LetMe.redact(nil, @user) == nil
    end

    test "handles nil value in nested field" do
      person = %{person() | spouse: nil}
      assert %Person{spouse: nil} = LetMe.redact(person, :nested_fields)
      assert %Person{spouse: nil} = LetMe.redact(person, :nested_schemas)
    end
  end

  describe "reject_redacted_fields/4" do
    test "can handle nested fields returned by callback" do
      fields = [:name, :email, :phone_number, :pet, :spouse, :age, :locale]
      person = person()

      assert LetMe.reject_redacted_fields(fields, person, :nested_fields) == [
               :age,
               :email,
               :locale,
               :pet,
               :spouse
             ]

      assert LetMe.reject_redacted_fields(fields, person, :nested_schemas) == [
               :age,
               :email,
               :locale,
               :pet,
               :spouse
             ]
    end
  end

  defp person do
    %Person{
      name: "Juan",
      email: "juan@person",
      phone_number: "123",
      age: 25,
      locale: "es",
      pet: %Pet{
        name: "Betty",
        email: "betty@pet",
        phone_number: "987",
        weight: 8,
        age: 7
      },
      spouse: %Person{
        name: "Oliver",
        email: "oliver@person",
        phone_number: "456",
        age: "28",
        locale: "fr",
        pet: %Pet{
          name: "Rocky",
          email: "rocky@pet",
          phone_number: "654",
          weight: 5,
          age: 3
        }
      }
    }
  end
end
