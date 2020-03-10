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
    def from_json(schema, value, _opts) do
      SimpleSchema.Type.json_to_struct(__MODULE__, schema, value)
    end

    @impl SimpleSchema
    def to_json(schema, value, _opts) do
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
        datetime: {SimpleSchema.Type.DateTime, optional: true}
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

  test "JSON can be converted to MyStruct by from_json/2" do
    input_datetime = "2017-10-13T17:30:28+09:00"
    output_datetime = "2017-10-13T08:30:28Z"

    invalid_json = %{"username" => "abc", "address" => "", "internal" => %{"value" => nil}}

    valid_json = %{
      "username" => "abcd",
      "address" => "",
      "internal" => %{"value" => 10},
      "datetime" => input_datetime
    }

    valid_json_output = %{
      "username" => "abcd",
      "address" => "",
      "internal" => %{"value" => 10},
      "datetime" => output_datetime
    }

    {:ok, dt, _} = DateTime.from_iso8601(input_datetime)

    expected = %MyStruct{
      username: "abcd",
      address: "",
      internal: %MyInternal{value: 10},
      datetime: dt
    }

    {:error, _} = SimpleSchema.from_json(MyStruct, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct, valid_json)
    assert {:ok, valid_json_output} == SimpleSchema.to_json(MyStruct, expected)
  end

  defmodule MyInternal2 do
    import SimpleSchema, only: [defschema: 1]
    defschema(value: {:integer, nullable: true})
  end

  defmodule MyStruct2 do
    import SimpleSchema, only: [defschema: 1]

    defschema(
      username: {:string, min_length: 4},
      address: {:string, default: ""},
      internal: MyInternal2,
      datetime: {SimpleSchema.Type.DateTime, optional: true}
    )
  end

  test "JSON can be converted to MyStruct2 by from_json/2 with default value" do
    input_datetime = "2017-10-13T17:30:28+09:00"
    output_datetime = "2017-10-13T08:30:28Z"

    invalid_json = %{"username" => "abc", "address" => "", "internal" => %{"value" => nil}}

    valid_json = %{
      "username" => "abcd",
      "address" => "",
      "internal" => %{"value" => 10},
      "datetime" => input_datetime
    }

    valid_json_output = %{
      "username" => "abcd",
      "address" => "",
      "internal" => %{"value" => 10},
      "datetime" => output_datetime
    }

    {:ok, dt, _} = DateTime.from_iso8601(input_datetime)

    expected = %MyStruct2{
      username: "abcd",
      address: "",
      internal: %MyInternal2{value: 10},
      datetime: dt
    }

    {:error, _} = SimpleSchema.from_json(MyStruct2, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct2, valid_json)
    assert {:ok, valid_json_output} == SimpleSchema.to_json(MyStruct2, expected)
  end

  defmodule MyStruct2.Nullable do
    import SimpleSchema, only: [defschema: 1]

    defschema(
      internal: {MyInternal2, nullable: true},
      internal2: {MyInternal2, nullable: true, default: nil}
    )
  end

  test "JSON can be converted to MyStruct2.Nullable by from_json/2" do
    invalid_json = %{}
    valid_json = %{"internal" => nil}

    valid_json_output = %{
      "internal" => nil,
      "internal2" => nil
    }

    expected = %MyStruct2.Nullable{
      internal: nil,
      internal2: nil
    }

    {:error, _} = SimpleSchema.from_json(MyStruct2.Nullable, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct2.Nullable, valid_json)
    assert {:ok, valid_json_output} == SimpleSchema.to_json(MyStruct2.Nullable, expected)
  end

  defmodule MyStruct.OptionalNullableDefault do
    import SimpleSchema, only: [defschema: 1]

    defschema(
      value: :integer,
      optional: {:integer, optional: true},
      nullable: {:integer, nullable: true},
      default: {:integer, default: 0},
      optional_nullable: {:integer, optional: true, nullable: true},
      optional_default: {:integer, optional: true, default: 0},
      nullable_default: {:integer, nullable: true, default: 0},
      optional_nullable_default: {:integer, optional: true, nullable: true, default: 0}
    )
  end

  test "構造体を optional, nullable, default で利用した場合の動作" do
    valid_json = %{"value" => 1, "nullable" => 100}

    expected = %MyStruct.OptionalNullableDefault{
      # optional, default のどちらも設定されてない場合、フィールドの設定は必須になる
      value: 1,
      nullable: 100,

      # optional にした場合はフィールドを省略可能だが、nullable の設定に関係なく nil が設定される
      # （構造体で値を指定しなかったのと同じ動作）
      optional: nil,
      optional_nullable: nil,

      # default が指定されている場合はフィールドを省略可能で、
      # フィールドが存在しなかった場合にデフォルト値が設定される
      default: 0,
      optional_default: 0,
      nullable_default: 0,
      optional_nullable_default: 0
    }

    assert {:ok, expected} ==
             SimpleSchema.from_json(MyStruct.OptionalNullableDefault, valid_json)
  end

  defmodule MyStruct.Nullable do
    defstruct [:id, :datetime]

    @behaviour SimpleSchema

    @impl SimpleSchema
    def schema([]) do
      %{
        id: :integer,
        datetime: {SimpleSchema.Type.DateTime, optional: true, nullable: true}
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

  test "JSON can be converted to MyStruct.Nullable by from_json/2 with nullable DateTime" do
    input_datetime = "2017-10-13T17:30:28+09:00"
    output_datetime = "2017-10-13T08:30:28Z"

    normal_json = %{"id" => 1, "datetime" => input_datetime}
    null_json = %{"id" => 1, "datetime" => nil}
    omitted_json = %{"id" => 1}

    {:ok, datetime, _} = DateTime.from_iso8601(input_datetime)

    null_expected = %MyStruct.Nullable{id: 1, datetime: nil}
    expected = %MyStruct.Nullable{id: 1, datetime: datetime}

    assert {:ok, null_expected} == SimpleSchema.from_json(MyStruct.Nullable, null_json)
    assert {:ok, null_expected} == SimpleSchema.from_json(MyStruct.Nullable, omitted_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct.Nullable, normal_json)

    null_expected_json = %{"id" => 1, "datetime" => nil}
    expected_json = %{"id" => 1, "datetime" => output_datetime}

    assert {:ok, expected_json} == SimpleSchema.to_json(MyStruct.Nullable, expected)
    assert {:ok, null_expected_json} == SimpleSchema.to_json(MyStruct.Nullable, null_expected)
  end

  defmodule MyStruct3 do
    import SimpleSchema, only: [defschema: 1]

    defschema(
      username: {:string, field: "_username"},
      address: {:string, field: "_address", default: "", optional: true}
    )
  end

  test "each simple schema fields are mapped from each :field values" do
    invalid_json = %{"username" => "abcd"}
    valid_json = %{"_username" => "abcd"}
    expected = %MyStruct3{username: "abcd"}
    expected_json = %{"_username" => "abcd", "_address" => ""}
    {:error, _} = SimpleSchema.from_json(MyStruct3, invalid_json)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct3, valid_json)
    assert {:ok, expected_json} == SimpleSchema.to_json(MyStruct3, expected)
  end

  defmodule MyStruct4 do
    import SimpleSchema, only: [defschema: 1]

    defschema(gift_ids: {[:integer], max_items: 5, unique_items: true})
  end

  test "array restriction is valid" do
    invalid_json = %{"gift_ids" => [1, 2, 3, 4, 5, 6]}
    invalid_json2 = %{"gift_ids" => [1, 2, 3, 4, 3]}
    valid_json = %{"gift_ids" => [1, 2, 3, 4, 5]}
    expected = %MyStruct4{gift_ids: [1, 2, 3, 4, 5]}
    expected_json = valid_json
    {:error, _} = SimpleSchema.from_json(MyStruct4, invalid_json)
    {:error, _} = SimpleSchema.from_json(MyStruct4, invalid_json2)
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct4, valid_json)
    assert {:ok, expected_json} == SimpleSchema.to_json(MyStruct4, expected)
  end

  defmodule MyStruct5 do
    import SimpleSchema, only: [defschema: 1]

    defschema(test: {[:integer], max_items: 5})
  end

  test "get_json_schema を自分で指定する" do
    # 本来なら max_items を超えるので指定不可能な値
    json = %{"test" => [1, 2, 3, 4, 5, 6]}
    expected = %MyStruct5{test: [1, 2, 3, 4, 5, 6]}
    # get_json_schema を指定して maxItems を消す
    get_json_schema = fn schema, opts ->
      js = SimpleSchema.Schema.to_json_schema(schema, opts)
      update_in(js["properties"]["test"], &(Map.delete(&1, "maxItems")))
    end
    {:ok, ^expected} = SimpleSchema.from_json(MyStruct5, json, [get_json_schema: get_json_schema])
  end

  defmodule MyStruct6 do
    import SimpleSchema, only: [defschema: 1]

    defschema(
      password: {:string, field: "_password", meta: %{description: "password", min_length: 15}}
    )
  end

  test "meta の情報は無視される" do
    # meta の min_length は無視される
    expected = %MyStruct6{password: "abc"}
    assert {:ok, expected} == SimpleSchema.from_json(MyStruct6, %{"_password" => "abc"})

    expected_json = %{"_password" => "abc"}
    assert {:ok, expected_json} == SimpleSchema.to_json(MyStruct6, expected)
  end
end
