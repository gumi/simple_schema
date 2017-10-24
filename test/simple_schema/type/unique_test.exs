defmodule SimpleSchema.Type.UniqueTest do
  use ExUnit.Case
  doctest SimpleSchema.Type.Unique

  defmodule MyStruct do
    import SimpleSchema, only: [defschema: 1]
    defschema [
      id: :integer,
      name: :string,
    ]
  end

  test "pass unique data" do
    json = [
      %{"id" => 1, "name" => "John"},
      %{"id" => 2, "name" => "Smith"},
    ]
    schema = {SimpleSchema.Type.Unique, element_type: MyStruct, unique_key: :id}
    expected = [
      %MyStruct{id: 1, name: "John"},
      %MyStruct{id: 2, name: "Smith"},
    ]
    assert {:ok, expected} == SimpleSchema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.to_json(schema, expected)
  end

  test "not pass non-unique data" do
    json = [
      %{"id" => 1, "name" => "John"},
      %{"id" => 1, "name" => "Smith"},
    ]
    schema = {SimpleSchema.Type.Unique, element_type: MyStruct, unique_key: :id}
    assert {:error, "Duplicate entry: key=id"} == SimpleSchema.from_json(schema, json)
  end
end
