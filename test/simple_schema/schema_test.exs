defmodule SimpleSchema.SchemaTest do
  use ExUnit.Case
  doctest SimpleSchema.Schema

  defp test_schema(expected, actual) do
    schema = SimpleSchema.Schema.to_json_schema(actual)
    _ = ExJsonSchema.Schema.resolve(schema)
    assert expected == schema
  end

  test "primitive typeをJSON Schemaに変換できる" do
    test_schema %{"type" => "boolean"}, :boolean
    test_schema %{"type" => "integer"}, :integer
    test_schema %{"type" => "number"}, :number
    test_schema %{"type" => "null"}, :null
    test_schema %{"type" => "string"}, :string
  end

  test "null可能な型を定義できる" do
    test_schema %{"type" => ["boolean", "null"]}, {:boolean, nullable: true}
    test_schema %{"type" => ["integer", "null"]}, {:integer, nullable: true}
    test_schema %{"type" => ["number", "null"]}, {:number, nullable: true}
    test_schema %{"type" => ["string", "null"]}, {:string, nullable: true}
    expected = %{
      "type" => ["object", "null"],
      "required" => ["x"],
      "additionalProperties" => false,
      "properties" => %{
        "x" => %{"type" => "string"},
      },
    }
    test_schema expected, {%{x: :string}, nullable: true}
    expected = %{
      "type" => ["array", "null"],
      "items" => %{"type" => "string"},
    }
    test_schema expected, {[:string], nullable: true}
  end

  test "マップをJSON Schemaに変換できる" do
    expected = %{
      "type" => "object",
      "required" => ["name"],
      "additionalProperties" => false,
      "properties" => %{
        "name" => %{"type" => "string"},
      },
    }
    test_schema expected, %{name: :string}
    test_schema expected, %{name: {:string, optional: false}}

    # optional
    expected = %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "name" => %{"type" => "string"},
      },
    }
    test_schema expected, %{name: {:string, optional: true}}
  end

  test "リストをJSON Schemaに変換できる" do
    expected = %{
      "type" => "array",
      "items" => %{"type" => "string"},
    }
    test_schema expected, [:string]
  end

  defmodule MyStruct1 do
    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      {:integer, minimum: 5}
    end

    @impl SimpleSchema
    def convert(_schema, value) do
      {:ok, value}
    end
  end

  defmodule MyStruct2 do
    defstruct [:value]

    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      %{
        value: :integer,
      }
    end

    @impl SimpleSchema
    def convert(schema, value) do
      SimpleSchema.Type.struct(__MODULE__, schema, value)
    end
  end

  test "SimpleSchema ビヘイビアを実装したモジュールを渡すことができる" do
    expected = %{
      "type" => "integer",
      "minimum" => 5,
    }
    test_schema expected, MyStruct1
  end

  test "構造体を定義したモジュールを渡すことができる" do
    expected = %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "value" => %{"type" => "integer"},
      },
      "required" => ["value"],
    }
    test_schema expected, MyStruct2
  end

  test "間違ったスキーマを渡すとエラーになる" do
    # 存在しない型
    assert_raise RuntimeError, fn ->
      SimpleSchema.Schema.to_json_schema(:unknown_type)
    end

    # 存在しない制限
    assert_raise FunctionClauseError, fn ->
      SimpleSchema.Schema.to_json_schema({:integer, unknown_restriction: 10})
    end

    # マップの外での optional の利用
    assert_raise FunctionClauseError, fn ->
      SimpleSchema.Schema.to_json_schema({:integer, optional: true})
    end

    # リストに複数の型を渡す
    assert_raise FunctionClauseError, fn ->
      SimpleSchema.Schema.to_json_schema([:string, :integer])
    end
  end

  test "integerの制限" do
    expected = %{
      "type" => ["integer", "null"],
      "maximum" => 10,
      "minimum" => 5,
      "enum" => [6, 8, 10],
    }
    test_schema expected, {:integer, nullable: true, maximum: 10, minimum: 5, enum: [6, 8, 10]}
  end

  test "numberの制限" do
    expected = %{
      "type" => ["number", "null"],
      "maximum" => 10.5,
      "minimum" => 5.5,
    }
    test_schema expected, {:number, nullable: true, maximum: 10.5, minimum: 5.5}
  end

  test "stringの制限" do
    expected = %{
      "type" => ["string", "null"],
      "maxLength" => 10,
      "minLength" => 1,
      "enum" => ["aaa@a.b", "bbb@a.b"],
      "format" => "email",
    }
    test_schema expected, {:string, nullable: true, max_length: 10, min_length: 1, enum: ["aaa@a.b", "bbb@a.b"], format: :email}
  end

  test "arrayの制限" do
    expected = %{
      "type" => ["array", "null"],
      "maxItems" => 10,
      "minItems" => 1,
      "items" => %{"type" => "string"},
    }
    test_schema expected, {[:string], nullable: true, max_items: 10, min_items: 1}
  end

  test "JSON Objectのキーをatomにしたマップに変換できる" do
    schema = %{key1: %{key2: :integer}}
    json = %{"key1" => %{"key2" => 100}}
    expected = %{key1: %{key2: 100}}
    assert {:ok, expected} == SimpleSchema.Schema.convert(schema, json)
  end

  test "存在しないatomに変換しようとするとエラーになる" do
    schema = %{}
    json = %{"unknown_key" => 100}
    assert_raise ArgumentError, fn ->
      SimpleSchema.Schema.convert(schema, json)
    end
  end

  test "JSON Array の中に JSON Object が入っていてもキーをatomにした値に変換できる" do
    schema = [%{key: :integer}]
    json = [%{"key" => 10}, %{"key" => 20}]
    expected = [%{key: 10}, %{key: 20}]
    assert {:ok, expected} == SimpleSchema.Schema.convert(schema, json)
  end

  test "スキーマに :any が混ざっていても変換できる" do
    schema = %{key: :any}
    json = %{"key" => 10}
    expected = %{key: 10}
    assert {:ok, expected} == SimpleSchema.Schema.convert(schema, json)

    json = %{"key" => %{"foo" => "bar"}}
    expected = %{key: %{"foo" => "bar"}}
    assert {:ok, expected} == SimpleSchema.Schema.convert(schema, json)
  end

  test "SimpleSchema ビヘイビアを実装したモジュールが混ざっていても変換できる" do
    schema = %{key1: MyStruct1, key2: MyStruct2}
    json = %{"key1" => 10, "key2" => %{"value" => 20}}
    expected = %{key1: 10, key2: %MyStruct2{value: 20}}
    assert {:ok, expected} == SimpleSchema.Schema.convert(schema, json)
  end
end
