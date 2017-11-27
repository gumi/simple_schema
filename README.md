# SimpleSchema

SimpleSchema is a schema for validating JSON and storing it in a specific type.

[日本語ドキュメントはこちら](TODO)

## Examples

Basic usage:

```elixir
iex> person_schema = %{name: :string, age: :integer}
iex>
iex> json = %{"name" => "John Smith", "age" => 42}
iex> SimpleSchema.from_json(person_schema, json)
{:ok, %{name: "John Smith", age: 42}}
iex>
iex> invalid_json = %{"name" => "John Smith", "age" => "invalid"}
iex> SimpleSchema.from_json(person_schema, invalid_json)
{:error, [{"Type mismatch. Expected Integer but got String.", "#/age"}]}
```

Name a simple schema:

```elixir
defmodule Person do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    %{
      name: :string,
      age: :integer,
    }
  end

  @impl SimpleSchema
  def from_json(schema, json) do
    SimpleSchema.Schema.from_json(schema, json)
  end

  @impl SimpleSchema
  def to_json(schema, json) do
    SimpleSchema.Schema.to_json(schema, json)
  end
end
```

```elixir
iex> json = %{"name" => "John Smith", "age" => 42}
iex> SimpleSchema.from_json(Person, json)
{:ok, %{name: "John Smith", age: 42}}
```

```elixir
# Nesting
defmodule Group do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    %{
      name: :string,
      persons: [Person],
    }
  end

  @impl SimpleSchema
  def from_json(schema, json) do
    SimpleSchema.Schema.from_json(schema, json)
  end

  @impl SimpleSchema
  def to_json(schema, json) do
    SimpleSchema.Schema.to_json(schema, json)
  end
end
```

```elixir
iex> json = %{"name" => "My Group",
...>          "persons" => [%{"name" => "John Smith", "age" => 42},
...>                        %{"name" => "Hans Schmidt", "age" => 18}]}
iex> SimpleSchema.from_json(Group, json)
{:ok, %{name: "My Group",
        persons: [%{name: "John Smith", age: 42},
                  %{name: "Hans Schmidt", age: 18}]}}
```

With struct:

```elixir
defmodule StructPerson do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: :string,
    age: :integer,
  ]
end
```

```elixir
iex> json = %{"name" => "John Smith", "age" => 42}
iex> SimpleSchema.from_json(StructPerson, json)
{:ok, %StructPerson{name: "John Smith", age: 42}}
```

```elixir
# Nesting
defmodule StructGroup do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: :string,
    persons: [StructPerson],
  ]
end
```

```elixir
iex> json = %{"name" => "My Group",
...>          "persons" => [%{"name" => "John Smith", "age" => 42},
...>                        %{"name" => "Hans Schmidt", "age" => 18}]}
iex> SimpleSchema.from_json(StructGroup, json)
{:ok, %StructGroup{name: "My Group",
                   persons: [%StructPerson{name: "John Smith", age: 42},
                             %StructPerson{name: "Hans Schmidt", age: 18}]}}
```

With restrictions:

```elixir
defmodule StrictPerson do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: {:string, min_length: 4},
    age: {:integer, minimum: 20, maximum: 65},
  ]
end
```

```elixir
iex> json = %{"name" => "John Smith", "age" => 42}
iex> SimpleSchema.from_json(StrictPerson, json)
{:ok, %StrictPerson{name: "John Smith", age: 42}}
```

```elixir
# Nesting
defmodule StrictGroup do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: {:string, min_length: 4},
    persons: {[StrictPerson], min_items: 2},
  ]
end
```

```elixir
iex> json = %{"name" => "My Group",
...>          "persons" => [%{"name" => "John Smith", "age" => 42},
...>                        %{"name" => "Hans Schmidt", "age" => 18}]}
iex> SimpleSchema.from_json(StrictGroup, json)
{:error, [{"Expected the value to be >= 20", "#/persons/1/age"}]}
```

## Types

Primitive types:

- `:boolean`
- `:integer`
- `:number`
- `:null`
- `:string`
- `:any`

Composite types:

- `%{...}`
- `[...]`

Module type:

- A module that implements `SimpleSchema` behavior

## Restrictions

You can add restrictions such as `:maximum` and `:min_length` to types.

- `{:nullable, boolean}`: If `true`, you can be set `nil`. Can specify it to all types except `:null`.
- `{:minimum, non_neg_integer}`: Minimum value. Can specify it to `:integer` and `:number` types.
- `{:maximum, non_neg_integer}`: Maximum value. Can specify it to `:integer` and `:number` types.
- `{:min_items, non_neg_integer}`: Minimum element count. Can specify it to `:array` type.
- `{:max_items, non_neg_integer}`: Maximum element count. Can specify it to `:array` type.
- `{:min_length, non_neg_integer}`: Minimum length. Can specify it to `:string` type.
- `{:max_length, non_neg_integer}`: Maximum length. Can specify it to `:string` type.
- `{:enum, [...]}`: List of possible values for elements. Can specify it to `:integer` and `:string` types.
- `{:format, :datetime | :email}`: Validate by pre-defined format. Can specify it to `:string` type.
- `{:optional, boolean}`: If true, an element as a child element of `%{...}` is not required. You can only specify it to a type of the child element of `%{...}`.
- `{:field, string}`: Corresponding JSON field name. You can only specify it to a type of the child element of `%{...}`.
