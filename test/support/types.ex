defmodule Person do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    %{
      name: :string,
      age: :integer
    }
  end

  @impl SimpleSchema
  def from_json(schema, json, _opts) do
    SimpleSchema.Schema.from_json(schema, json)
  end

  @impl SimpleSchema
  def to_json(schema, value, _opts) do
    SimpleSchema.Schema.to_json(schema, value)
  end
end

defmodule Group do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    %{
      name: :string,
      persons: [Person]
    }
  end

  @impl SimpleSchema
  def from_json(schema, json, _opts) do
    SimpleSchema.Schema.from_json(schema, json)
  end

  @impl SimpleSchema
  def to_json(schema, value, _opts) do
    SimpleSchema.Schema.to_json(schema, value)
  end
end

defmodule StructPerson do
  import SimpleSchema, only: [defschema: 1]

  defschema(
    name: :string,
    age: :integer
  )
end

defmodule StructGroup do
  import SimpleSchema, only: [defschema: 1]

  defschema(
    name: :string,
    persons: [StructPerson]
  )
end

defmodule StrictPerson do
  import SimpleSchema, only: [defschema: 1]

  defschema(
    name: {:string, min_length: 4},
    age: {:integer, minimum: 20, maximum: 65}
  )
end

defmodule StrictGroup do
  import SimpleSchema, only: [defschema: 1]

  defschema(
    name: {:string, min_length: 4},
    persons: {[StrictPerson], min_items: 2}
  )
end
