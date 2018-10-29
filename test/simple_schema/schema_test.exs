defmodule SimpleSchema.SchemaTest do
  use ExUnit.Case
  doctest SimpleSchema.Schema

  defp test_schema(expected, actual) do
    schema = SimpleSchema.Schema.to_json_schema(actual)
    _ = ExJsonSchema.Schema.resolve(schema)
    assert expected == schema
  end

  test "Primitive type can be converted to JSON Schema" do
    test_schema(%{"type" => "boolean"}, :boolean)
    test_schema(%{"type" => "integer"}, :integer)
    test_schema(%{"type" => "number"}, :number)
    test_schema(%{"type" => "null"}, :null)
    test_schema(%{"type" => "string"}, :string)
  end

  test "can define nullable type" do
    test_schema(%{"type" => ["boolean", "null"]}, {:boolean, nullable: true})
    test_schema(%{"type" => ["integer", "null"]}, {:integer, nullable: true})
    test_schema(%{"type" => ["number", "null"]}, {:number, nullable: true})
    test_schema(%{"type" => ["string", "null"]}, {:string, nullable: true})

    expected = %{
      "type" => ["object", "null"],
      "required" => ["x"],
      "additionalProperties" => false,
      "properties" => %{
        "x" => %{"type" => "string"}
      }
    }

    test_schema(expected, {%{x: :string}, nullable: true})

    expected = %{
      "type" => ["array", "null"],
      "items" => %{"type" => "string"}
    }

    test_schema(expected, {[:string], nullable: true})
  end

  test "Maps can be converted to JSON Schema" do
    expected = %{
      "type" => "object",
      "required" => ["name"],
      "additionalProperties" => false,
      "properties" => %{
        "name" => %{"type" => "string"}
      }
    }

    test_schema(expected, %{name: :string})
    test_schema(expected, %{name: {:string, optional: false}})

    # optional
    expected = %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "name" => %{"type" => "string"}
      }
    }

    test_schema(expected, %{name: {:string, optional: true}})
  end

  test "Lists can be converted to JSON Schema" do
    expected = %{
      "type" => "array",
      "items" => %{"type" => "string"}
    }

    test_schema(expected, [:string])
  end

  defmodule MyStruct1 do
    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      {:integer, minimum: 5}
    end

    @impl SimpleSchema
    def from_json(_schema, value, _opts) do
      {:ok, value}
    end

    @impl SimpleSchema
    def to_json(_schema, value, _opts) do
      {:ok, value}
    end
  end

  defmodule MyStruct2 do
    defstruct [:value]

    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      %{
        value: :integer
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

  test "can pass a module that implements the SimpleSchema behaviour" do
    expected = %{
      "type" => "integer",
      "minimum" => 5
    }

    test_schema(expected, MyStruct1)
  end

  test "can pass a module that defines a structure" do
    expected = %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "value" => %{"type" => "integer"}
      },
      "required" => ["value"]
    }

    test_schema(expected, MyStruct2)
  end

  test "Error when passing wrong schema" do
    # non existing type
    assert_raise RuntimeError, fn ->
      SimpleSchema.Schema.to_json_schema(:unknown_type)
    end

    # non existing restriction
    assert_raise FunctionClauseError, fn ->
      SimpleSchema.Schema.to_json_schema({:integer, unknown_restriction: 10})
    end

    # using `:optional` restriction outside a map
    assert_raise FunctionClauseError, fn ->
      SimpleSchema.Schema.to_json_schema({:integer, optional: true})
    end

    # pass multiple types to list
    assert_raise FunctionClauseError, fn ->
      SimpleSchema.Schema.to_json_schema([:string, :integer])
    end
  end

  test "integer restrictions" do
    expected = %{
      "type" => ["integer", "null"],
      "maximum" => 10,
      "minimum" => 5,
      "enum" => [6, 8, 10]
    }

    test_schema(expected, {:integer, nullable: true, maximum: 10, minimum: 5, enum: [6, 8, 10]})
  end

  test "number restrictions" do
    expected = %{
      "type" => ["number", "null"],
      "maximum" => 10.5,
      "minimum" => 5.5
    }

    test_schema(expected, {:number, nullable: true, maximum: 10.5, minimum: 5.5})
  end

  test "string restrictions" do
    expected = %{
      "type" => ["string", "null"],
      "maxLength" => 10,
      "minLength" => 1,
      "enum" => ["aaa@a.b", "bbb@a.b"],
      "format" => "email"
    }

    test_schema(
      expected,
      {:string,
       nullable: true, max_length: 10, min_length: 1, enum: ["aaa@a.b", "bbb@a.b"], format: :email}
    )
  end

  test "array restrictions" do
    expected = %{
      "type" => ["array", "null"],
      "maxItems" => 10,
      "minItems" => 1,
      "uniqueItems" => true,
      "items" => %{"type" => "string"}
    }

    test_schema(expected, {[:string], nullable: true, max_items: 10, min_items: 1, unique_items: true})
  end

  test "JSON Object keys can be converted to atom keys" do
    schema = %{key1: %{key2: :integer}}
    json = %{"key1" => %{"key2" => 100}}
    expected = %{key1: %{key2: 100}}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)
  end

  test "Can not convert to nonexistent atom" do
    schema = %{}
    json = %{"unknown_key" => 100}
    {:error, [{:key_not_found, "unknown_key", %{}}]} = SimpleSchema.Schema.from_json(schema, json)
  end

  test "Can convert JSON keys even if JSON Array contains JSON Object" do
    schema = [%{key: :integer}]
    json = [%{"key" => 10}, %{"key" => 20}]
    expected = [%{key: 10}, %{key: 20}]
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)
  end

  test "can be converted the schema even if `:any` is mixed in the schema" do
    schema = %{key: :any}
    json = %{"key" => 10}
    expected = %{key: 10}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)

    json = %{"key" => %{"foo" => "bar"}}
    expected = %{key: %{"foo" => "bar"}}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)
  end

  test "can be converted the schema even if a module that implements SimpleSchema behaviour is mixed in the schema" do
    schema = %{key1: MyStruct1, key2: MyStruct2}
    json = %{"key1" => 10, "key2" => %{"value" => 20}}
    expected = %{key1: 10, key2: %MyStruct2{value: 20}}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)
  end

  test "If a default value exists in the schema, it is set to the result if the key does not exist in a passed JSON" do
    schema = %{key: {:string, default: "default"}}

    json = %{"key" => "foo"}
    expected = %{key: "foo"}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)

    json = %{}
    expected = %{key: "default"}
    expected_json = %{"key" => "default"}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, expected_json} == SimpleSchema.Schema.to_json(schema, expected)
    assert {:ok, expected_json} == SimpleSchema.Schema.to_json(schema, %{})
  end

  test "If a default value exists in the schema, :optional option is ignored" do
    schema = %{key: {:string, default: "default", optional: true}}

    json = %{"key" => "foo"}
    expected = %{key: "foo"}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)

    json = %{}
    expected = %{key: "default"}
    expected_json = %{"key" => "default"}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, expected_json} == SimpleSchema.Schema.to_json(schema, expected)
    assert {:ok, expected_json} == SimpleSchema.Schema.to_json(schema, %{})
  end

  test "Default values can also be set for module-based schema" do
    schema = %{key: {MyStruct2, default: %MyStruct2{value: 100}}}

    json = %{"key" => %{"value" => 200}}
    expected = %{key: %MyStruct2{value: 200}}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, json} == SimpleSchema.Schema.to_json(schema, expected)

    json = %{}
    expected = %{key: %MyStruct2{value: 100}}
    expected_json = %{"key" => %{"value" => 100}}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
    assert {:ok, expected_json} == SimpleSchema.Schema.to_json(schema, expected)
    assert {:ok, expected_json} == SimpleSchema.Schema.to_json(schema, %{})
  end

  test "Additional properties are not allowed without setting `tolerant: true`" do
    schema = %{key1: %{key2: :integer}}
    json = %{"key1" => %{"key2" => 100, "key3" => 200}}
    assert {:error, _} = SimpleSchema.Schema.from_json(schema, json)
  end

  test "Additional properties are allowed by setting `tolerant: true`" do
    schema = %{key1: {%{key2: :integer}, tolerant: true}}
    json = %{"key1" => %{"key2" => 100, "key3" => 200}}
    expected = %{key1: %{key2: 100}}
    assert {:ok, expected} == SimpleSchema.Schema.from_json(schema, json)
  end

  test "Additional properties could be set on most outer objects" do
    schema = {%{key1: %{key2: :integer}}, tolerant: true}
    json1 = %{"key1" => %{"key2" => 100}, "key3" => 200}
    json2 = %{"key1" => %{"key2" => 100, "key3" => 200}}
    assert {:ok, _} = SimpleSchema.Schema.from_json(schema, json1)
    assert {:error, _} = SimpleSchema.Schema.from_json(schema, json2)
  end

  test ":struct_converter opts can convert any JSON" do
    schema = %{key1: MyStruct1}
    struct_converter = fn schema, _opts ->
      %{"$ref" => "#/schemas/#{inspect(schema)}"}
    end

    expected = %{
      "type" => "object",
      "properties" => %{
        "key1" => %{
          "$ref" => "#/schemas/SimpleSchema.SchemaTest.MyStruct1"
        },
      },
      "additionalProperties" => false,
      "required" => ["key1"]
    }

    assert expected == SimpleSchema.Schema.to_json_schema(schema, struct_converter: struct_converter)
  end
end
