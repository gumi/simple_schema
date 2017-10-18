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
  def convert(schema, json) do
    SimpleSchema.Schema.convert(schema, json)
  end
end

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
  def convert(schema, json) do
    SimpleSchema.Schema.convert(schema, json)
  end
end

defmodule StructPerson do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: :string,
    age: :integer,
  ]
end

defmodule StructGroup do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: :string,
    persons: [StructPerson],
  ]
end

defmodule StrictPerson do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: {:string, min_length: 4},
    age: {:integer, minimum: 20, maximum: 65},
  ]
end

defmodule StrictGroup do
  import SimpleSchema, only: [defschema: 1]
  defschema [
    name: {:string, min_length: 4},
    persons: {[StrictPerson], min_items: 2},
  ]
end
