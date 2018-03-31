# SimpleSchema

SimpleSchema is a schema for validating JSON and storing it in a specific schema.

[日本語ドキュメントはこちら](https://qiita.com/melpon/items/9718f9ea107c0b9f799a)

## Motivation

When you are writing an HTTP API server, you may want to verify that the HTTP request body is correct.
For validation only, you can use a library that implements [JSON Schema](http://json-schema.org/).
Fortunately Elixir has a library called [ExJsonSchema](https://github.com/jonasschmidt/ex_json_schema) that implements JSON Schema.

However, it is hard to write JSON Schema by hand. I want to use a more simple schema.

Also, JSON Schema only validates, so it takes time and effort to access the data.

```elixir
json = Poison.decode!(conn.body_param)
:ok = validate(json)

hp = json["player"]["hp"]
# → I want to write json.player.hp

datetime = json["datetime"]                       # get a string and
{:ok, datetime, _} = DateTime.from_iso8601(value) # convert to DateTime
# → I want to get DateTime with json.datetime
```

I made a library called SimpleSchema to easily write the schema and convert the verified data.

## How to Use

Use it as follows.

```elixir
# Define a schema with defschema/1
defmodule Person do
  import SimpleSchema, only: [defschema: 1]

  defschema [
    name: :string,
    age: {:integer, minimum: 0},
  ]
end

# Map that decoded JSON string
json = %{
  "name" => "John Smith",
  "age" => 42,
}

# from_json!/2 with the map and Person, then a value is set in the Person structure
person = SimpleSchema.from_json!(Person, json)

assert person.name == "John Smith"
assert person.age == 42
```

If a passed JSON object is incorrect as the `Person` schema, you get an error like this:

```elixir
bad_json = %{
  "name" => 100,             # not string
  "age" => -10,              # invalid age
  "__additional_key__" => 0, # an additional key
}

# from_json/2 fails
{:error, reason} = SimpleSchema.from_json(Person, bad_json)
IO.inspect reason
```

Output:

```
[{"Expected the value to be >= 0", "#/age"},
 {"Type mismatch. Expected String but got Integer.", "#/name"},
 {"Schema does not allow additional properties.", "#/__additional_key__"}]
```

This allows you to name common schemas and use them.

## Simple Schema

I will explain SimpleSchema features in a bit more detail.

The schema which SimpleSchema library defines and which can be passed to the first argument of `SimpleSchema.from_json/2` is called **simple schema**.
For example, `:integer` is a simple schema.

```elixir
value = SimpleSchema.from_json!(:integer, 10)
assert value == 10
```

`:integer` simple schema checks whether the passed value is an integer, and if it is an integer it will return that value.
You can also possible to add restriction to integers.

```elixir
value = SimpleSchema.from_json!({:integer, minimum: 10, maximum: 20}, 5)
# RuntimeError: [{"Expected the value to be >= 10", "#"}]
```

`{:integer, opts}` is also a simple schema.
It checks whether the passed value is an integer and is within the range of 10 to 20, and if it is correct it will return that value.

`% {...}` is also a simple schema. And all each fields of that simple schema is also a simple schema.

```elixir
schema = %{
  value: {:integer, optional: true},
  point: %{
    x: :integer,
    y: :integer,
  },
}
data = %{
  "point" => %{
    "x" => 10,
    "y" => 20,
  }
}
value = SimpleSchema.from_json!(schema, data)
# value == %{point: %{x: 10, y: 20}}
assert value.point.x == 10
assert value.point.y == 20
```

It checks whether the passed value is a map and is each fields of the passed value matches that simple schema.
If it is correct, it will converts the key of the passed map to atom and it will return that value.

In addition, I added `optional: true` restriction to `:value` field.
This can only be specified for children of the map.
This mean "it will not cause an error even if this field is not present."
So `SimpleSchema.from_json!/2` is successful even if `"value"` key does not exist in `data`.

### List of Simpe Schema

A simple schema must be one of the following:

- `:boolean` or `{:boolean, opts}`
- `:integer` or `{:integer, opts}`
- `:number` or `{:number, opts}`
- `:null` or `{:null, opts}`
- `:string` or `{:string, opts}`
- `:any` or `{:any, opts}`
- `%{...}` or `{%{...}, opts}`
- `[...]` or `{[...], opts}`
- A module that implements `SimpleSchema` behaiviour, or `{Module, opts}`

`opts` specifies restrictions in the keyword list.

### List of Restrictions

The list of restrictions is as follows.

- `{:nullable, boolean}`: If `true`, it can be set `nil`. It can be specified as any simple schema other than `:null`.
- `{:minimum, integer}`: Minimum value. It can be specified as `:integer` and `:number`.
- `{:maximum, integer}`: Maximum value. It can be specified as `:integer` and `:number`.
- `{:min_items, non_neg_integer}`: Minimum element count. It can be specified as `:array`.
- `{:max_items, non_neg_integer}`: Maximum element count. It can be specified as `:array`.
- `{:min_length, non_neg_integer}`: Minimum length. It can be specified as `:string`.
- `{:max_length, non_neg_integer}`: Maximum length. It can be specified as `:string`.
- `{:enum, [...]}`: List of possible values for elements. It can be specified as `:integer` and `:string`.
- `{:format, :datetime | :email}`: Validate by pre-defined format. It can be specified as `:string`.
- `{:optional, boolean}`: If true, the child element of `%{...}` is not required. It can be only specified as the child element of `%{...}`.
- `{:tolerant, boolean}`: If `true`, `"additionalProperties"` would be set to `true`, and will allow non-specified keys to be present in the child elements. It can be only specified as `%{...}`. Defaults to `false`.
- `{:default, any}`: If the default value is specified and a field of the map is not given, the specified default value is set to the field. It can be only specified as the child element of `%{...}`.
- `{:field, string}`: Corresponding JSON field name. It can be only specified as the child element of `%{...}`.

## `SimpleSchema` behaiviour

A module that implements `SimpleSchema` behaiviour is also a simple schema.
You can use this to name a specific schema or to convert it to a specific structure.

For example, to get the date according to ISO 8601 such as `"2017-11-27T11:49:50+09:00"` as a `DateTime` type, define it as follows.

```elixir
defmodule DateTimeSchema do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    {:string, format: :datetime}
  end

  @impl SimpleSchema
  def from_json(_schema, value, _opts) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl SimpleSchema
  def to_json(_schema, value, _opts) do
    {:ok, DateTime.to_iso8601(value)}
  end
end
```

Since `DateTimeSchema` is a simple schema, it can be passed to `SimpleSchema.from_json!/2` as follows.

```elixir
datetime = SimpleSchema.from_json!(DateTimeSchema, "2017-11-27T11:49:50+09:00")
# datetime == #DateTime<2017-11-27 02:49:50Z>
```

By implementing the `SimpleSchema` behavior like this, we can name `DateTimeSchema` to a specific schema and convert it to a structure of `DateTime` type.
A module equivalent to `DateTimeSchema` above is already in `SimpleSchema.Type.DateTime`.

The functions required by `SimpleSchema` behavior are as follows.

```elixir
@callback schema(opts :: Keyword.t) :: simple_schema
@callback from_json(schema :: simple_schema, json :: any, opts :: Keyword.t) :: {:ok, any} | {:error, any}
@callback to_json(schema :: simple_schema, value :: any, opts :: Keyword.t) :: {:ok, any} | {:error, any}
```

In `schema/1`, define the simple schema required by that module.

`from_json/3` converts `value` to an arbitrary type and returns it.
`value` has been verified with the simple schema returned by `schema/1`.
For example `value` passed to `DateTimeSchema.from_json/3` above has been verified by `{:string, format: datetime}`.
So `value` is guaranteed that is a string and is `:datetime` format.

Note: If `optimistic: true` is specified in `SimpleSchema.from_json/2`, validation will not be done. In this case, the user is responsible for passing the correct value.

`to_json/3` converts the passed value to a JSON value satisfying the simple schema.
It performs the inverse conversion from `from_json/3`.
This function is used inside `SimpleSchema.to_json/2`. You can return `{:error, "not implemented"}` if it is not necessary.

## `defschema/1`

`defschema/1` defines a structure by `defstruct/1` and implements `SimpleSchema` behaviour.

```elixir
defmodule Person do
  import SimpleSchema, only: [defschema: 1]

  defschema [
    name: :string,
    age: {:integer, minimum: 0},
  ]
end
```

This code is converted as follows.

```elixir
defmodule Person do
  @enforce_keys [:name, :age]
  defstruct [:name, :age]

  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    %{
      name: :string,
      age: {:integer, minimum: 0},
    }
  end

  @impl SimpleSchema
  def from_json(schema, value, _opts) do
    SimpleSchema.Type.json_to_struct(__MODULE__, schema, value)
  end

  @impl SimpleSchema
  def to_json(schema, value, _opts) do
    SimpleSchema.Type.struct_to_json(__MODULE__, schema, value)
  end
end
```

`schema/1` defines a simple schema as a map with `:name` and `:age`.
When calling `SimpleSchema.from_json!/2`, it verifies the passed JSON object, then calls `Person.from_json/3` and converts `value` to the `Person` structure.
Since we provides `SimpleSchema.Type.json_to_struct/3` as a helper to convert JSON objects to specific structures, using this makes it easy to convert.

## Examples

Simple usage:

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
