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
    def convert(schema, value) do
      SimpleSchema.Type.struct(__MODULE__, schema, value)
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
    def convert(schema, value) do
      SimpleSchema.Type.struct(__MODULE__, schema, value)
    end
  end

  test "test" do
    invalid_json = %{"username" => "abc", "address" => "", "internal" => %{"value" => nil}}
    valid_json = %{"username" => "abcd", "address" => "", "internal" => %{"value" => 10}, "datetime" => "2017-10-13T17:30:28+09:00"}
    {:ok, dt, _} = DateTime.from_iso8601("2017-10-13T17:30:28+09:00")
    expected = %MyStruct{username: "abcd", address: "", internal: %MyInternal{value: 10}, datetime: dt}
    {:error, _} = SimpleSchema.from_json(MyStruct, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct, valid_json)
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

  test "test2" do
    invalid_json = %{"username" => "abc", "address" => "", "internal" => %{"value" => nil}}
    valid_json = %{"username" => "abcd", "address" => "", "internal" => %{"value" => 10}, "datetime" => "2017-10-13T17:30:28+09:00"}
    {:ok, dt, _} = DateTime.from_iso8601("2017-10-13T17:30:28+09:00")
    expected = %MyStruct2{username: "abcd", address: "", internal: %MyInternal2{value: 10}, datetime: dt}
    {:error, _} = SimpleSchema.from_json(MyStruct2, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct2, valid_json)
  end
end
