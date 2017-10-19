defmodule SimpleSchemaTest do
  use ExUnit.Case
  doctest SimpleSchema

  defmodule MyInternal do
    defstruct [:value]

    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      %{value: {:integer, nullable: true}}
    end

    @impl SimpleSchema
    def from_json(schema, value) do
      SimpleSchema.Type.json_to_struct(__MODULE__, schema, value)
    end

    @impl SimpleSchema
    def to_json(schema, value) do
      SimpleSchema.Type.struct_to_json(__MODULE__, schema, value)
    end
  end

  defmodule MyStruct do
    defstruct [:username, :address, :internal, :datetime]

    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      %{
        username: {:string, min_length: 4},
        address: :string,
        internal: MyInternal,
        datetime: {SimpleSchema.Type.DateTime, optional: true},
      }
    end

    @impl SimpleSchema
    def from_json(schema, value) do
      SimpleSchema.Type.json_to_struct(__MODULE__, schema, value)
    end

    @impl SimpleSchema
    def to_json(schema, value) do
      SimpleSchema.Type.struct_to_json(__MODULE__, schema, value)
    end
  end

  test "JSON can be converted to MyStruct by from_json/2" do
    input_datetime = "2017-10-13T17:30:28+09:00"
    output_datetime = "2017-10-13T08:30:28Z"

    invalid_json = %{"username" => "abc", "address" => "", "internal" => %{"value" => nil}}
    valid_json = %{"username" => "abcd", "address" => "", "internal" => %{"value" => 10}, "datetime" => input_datetime}
    valid_json_output = %{"username" => "abcd", "address" => "", "internal" => %{"value" => 10}, "datetime" => output_datetime}
    {:ok, dt, _} = DateTime.from_iso8601(input_datetime)
    expected = %MyStruct{username: "abcd", address: "", internal: %MyInternal{value: 10}, datetime: dt}
    {:error, _} = SimpleSchema.from_json(MyStruct, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct, valid_json)
    assert {:ok, valid_json_output} == SimpleSchema.to_json(MyStruct, expected)
  end

  defmodule MyInternal2 do
    import SimpleSchema, only: [defschema: 1]
    defschema [value: {:integer, nullable: true}]
  end
  defmodule MyStruct2 do
    import SimpleSchema, only: [defschema: 1]
    defschema [
      username: {:string, min_length: 4},
      address: {:string, default: ""},
      internal: MyInternal2,
      datetime: {SimpleSchema.Type.DateTime, optional: true},
    ]
  end

  test "JSON can be converted to MyStruct2 by from_json/2 with default value" do
    input_datetime = "2017-10-13T17:30:28+09:00"
    output_datetime = "2017-10-13T08:30:28Z"

    invalid_json = %{"username" => "abc", "address" => "", "internal" => %{"value" => nil}}
    valid_json = %{"username" => "abcd", "address" => "", "internal" => %{"value" => 10}, "datetime" => input_datetime}
    valid_json_output = %{"username" => "abcd", "address" => "", "internal" => %{"value" => 10}, "datetime" => output_datetime}
    {:ok, dt, _} = DateTime.from_iso8601(input_datetime)
    expected = %MyStruct2{username: "abcd", address: "", internal: %MyInternal2{value: 10}, datetime: dt}
    {:error, _} = SimpleSchema.from_json(MyStruct2, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct2, valid_json)
    assert {:ok, valid_json_output} == SimpleSchema.to_json(MyStruct2, expected)
  end
end
