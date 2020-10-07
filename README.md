# SimpleSchema

<!-- MDOC !-->

SimpleSchema は JSON の検証と各データ構造への設定を行うライブラリです。

- [hex.pm](https://hex.pm/packages/simple_schema)

## 動機

HTTP の API サーバを書いていると、よく HTTP の POST リクエストで JSON を受け取ることがありますが、この値が正しいフォーマットかどうかを検証したいことがあります。
検証だけなら、[JSON Schema](http://json-schema.org/) を使うという手があり、幸いなことに Elixir には JSON Schema を実装した [ExJsonSchema](https://github.com/jonasschmidt/ex_json_schema) というライブラリがあります。

しかし、JSON Schema は手で書くのが大変です。もう少し機能を絞った単純なスキーマを使いたいところです。

また、JSON Schema は検証しか行わないため、データにアクセスするのに手間が掛かります。

```elixir
json = Poison.decode!(conn.body_param)
:ok = validate(json)

hp = json["player"]["hp"]
# → json.player.hp と書きたい

datetime = json["datetime"]                       # 文字列を取り出して
{:ok, datetime, _} = DateTime.from_iso8601(value) # DateTime 型に変換する
# → json.datetime した段階で DateTime 型であって欲しい
```

このように、特に `DateTime` に変換するといった処理が必要な場合、検証と同時に変換まで済ませたいのです。

そこで、簡単にスキーマを書けるようして、検証を行い、それらのデータを変換するライブラリとして、SimpleSchema というライブラリを作りました。

## 使い方

以下のように使います。

```elixir
# defschema/1 を使ってスキーマを定義する
defmodule Person do
  import SimpleSchema, only: [defschema: 1]

  defschema [
    name: :string,
    age: {:integer, minimum: 0},
  ]
end

# JSON 文字列をデコードしたデータを…
json = %{
  "name" => "John Smith",
  "age" => 42,
}

# Person と一緒に from_json!/2 すると、Person 構造体に値が設定される
person = SimpleSchema.from_json!(Person, json)

assert person.name == "John Smith"
assert person.age == 42
```

このように、`defschema/1` でスキーマを定義して、`SimpleSchema.from_json!/2` にそのスキーマと JSON オブジェクトを渡すと、JSON オブジェクトを検証し、指定したスキーマにデータを入れてくれます。

JSON オブジェクトが `Person` スキーマを満たしていない場合、以下のようにエラーがでます。

```elixir
bad_json = %{
  "name" => 100, # 文字列ではない
  "age" => -10, # 無効な年齢
  "__additional_key__" => 0, # 余分なキー
}

# from_json/2 は失敗する
{:error, reason} = SimpleSchema.from_json(Person, bad_json)
IO.inspect reason
```

出力:

```
[{"Expected the value to be >= 0", "#/age"},
 {"Type mismatch. Expected String but got Integer.", "#/name"},
 {"Schema does not allow additional properties.", "#/__additional_key__"}]
```

この `Person` を内包するスキーマを定義することもできます。
つまりスキーマはネスト可能です。

```elixir
# Person を内包する Group
defmodule Group do
  import SimpleSchema, only: [defschema: 1]

  defschema [
    group_name: :string,
    persons: [Person],
  ]
end

json = %{
  "group_name" => "A Group",
  "persons" => [%{
    "name" => "John Smith",
    "age" => 42,
  }, %{
    "name" => "YAMADA Taro",
    "age" => 20,
  }],
}

group = SimpleSchema.from_json!(Group, json)

assert group.group_name == "A Group"
assert Enum.fetch!(group.persons, 1).age == 20
```

`Group` スキーマを `defschema/1` で定義していますが、`:group_name` が文字列であり、`:persons` が `Person` の配列であることが、見ればすぐに分かるでしょう。

これによって、共通するスキーマに名前を付けて再利用することができます。

## シンプルスキーマ

もう少し詳細に SimpleSchema の機能を説明します。

SimpleSchema ライブラリが定義している、`SimpleSchema.from_json/2` の第１引数に渡せるスキーマのことを **シンプルスキーマ** と呼びます。
JSON Schema と比べると大分単純で直感的な構文になっているので「シンプル」と名付けています。

例えば、`:integer` はシンプルスキーマです。

```elixir
value = SimpleSchema.from_json!(:integer, 10)
assert value == 10
```

`:integer` シンプルスキーマは、渡された値が整数であるかを確認し、整数であればその値を戻り値にします。
整数に制約を付け加えることも可能です。

```elixir
value = SimpleSchema.from_json!({:integer, minimum: 10, maximum: 20}, 5)
# RuntimeError: [{"Expected the value to be >= 10", "#"}]
```

`{:integer, opts}` という書き方もシンプルスキーマになります。
これは渡された値が整数であり、かつ10から20の範囲内であるかを確認し、正しければその値を戻り値にします。

`%{}` という書き方もシンプルスキーマであり、各フィールドには、更にシンプルスキーマを渡すことができます。

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

このシンプルスキーマは、渡された値がマップであるかを確認し、渡された値の各フィールドが、指定したシンプルスキーマのフィールドと合っているかどうか確認します。
正しければ、渡されたマップのキーを atom にした上で戻り値にします。

また、`:value` フィールドに `optional: true` という制約を付与しました。
これはマップのフィールドに渡すシンプルスキーマのみに指定可能で「このフィールドが無くてもエラーにしない」という意味になります。
そのため `data` に `"value"` キーが存在していなくても `SimpleSchema.from_json!/2` が成功しています。

### シンプルスキーマの一覧

シンプルスキーマは、以下のいずれかである必要があります。

- `:boolean` または `{:boolean, opts}`
- `:integer` または `{:integer, opts}`
- `:number` または `{:number, opts}`
- `:null` または `{:null, opts}`
- `:string` または `{:string, opts}`
- `:any` または `{:any, opts}`
- `%{...}` または `{%{...}, opts}`
- `[...]` または `{[...], opts}`
- `SimpleSchema` ビヘイビアを実装したモジュール、または `{Module, opts}`

`opts` には各制約をキーワードリストで指定します。

### 制約の一覧

制約の一覧は以下の通りです。

- `{:nullable, boolean}`: もし `true` なら `nil` を許可する。`:null` 以外のシンプルスキーマに指定可能。
- `{:minimum, integer}`: 最小値。`:integer` と `:number` に指定可能。
- `{:maximum, integer}`: 最大値。`:integer` と `:number` に指定可能。
- `{:min_items, non_neg_integer}`: 最小の要素数。`:array` に指定可能。
- `{:max_items, non_neg_integer}`: 最大の要素数。`:array` に指定可能。
- `{:unique_items, boolean}`: もし `true` なら配列がユニークであることを要求される。`:array` に指定可能。
- `{:min_length, non_neg_integer}`: 最小の長さ。`:string` に指定可能。
- `{:max_length, non_neg_integer}`: 最大の長さ。`:string` に指定可能。
- `{:enum, [...]}`: 要素に指定可能な値のリスト。`:integer` と `:string` に指定可能。
- `{:format, :datetime | :email}`: 事前に定義されたフォーマットで検証する。`:string` に指定可能。
- `{:optional, boolean}`: もし `true` なら、`%{...}` の子要素として必須では無い。`%{...}` の子要素のみ指定可能。
- `{:tolerant, boolean}`: もし `true` なら、生成される JSON Schema に `"additionalProperties"` が設定される。つまり子要素に指定されてない要素を許可するようになる。`%{...}` に指定可能。デフォルトは `false`。
- `{:default, any}`: フィールドのデフォルト値。渡された JSON にこのフィールドが存在しなかった場合はこの値になる。`%{...}` の子要素のみ指定可能。
- `{:field, string}`: 対応する JSON のフィールド名。`%{...}` の子要素のみ指定可能。

### メタ情報

シンプルスキーマや制約以外の情報は `opts` に `:meta` キーを使って追加します。

```elixir
schema = %{
  value: {:integer, optional: true},
  point: %{
    x: {:integer, meta: %{description: "x座標"}},
    y: {:integer, meta: %{description: "y座標"}},
  },
}
```

## `SimpleSchema` ビヘイビア

`SimpleSchema` ビヘイビアを実装したモジュールは、シンプルスキーマになります。
これを使うことで、特定のスキーマに名前を付けたり、特定の構造体に変換できるようになります。

例えば、`"2017-11-27T11:49:50+09:00"` といった ISO 8601 に従った日付を `DateTime` 型として取得するには、以下のように定義します。

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

`DateTimeSchema` は `SimpleSchema` ビヘイビアを実装しているためシンプルスキーマになります。
そのため、以下のように `SimpleSchema.from_json!/2` に渡すことができます。

```elixir
datetime = SimpleSchema.from_json!(DateTimeSchema, "2017-11-27T11:49:50+09:00")
# datetime == #DateTime<2017-11-27 02:49:50Z>
```

このように `SimpleSchema` ビヘイビアを実装することで、特定のスキーマに `DateTimeSchema` というを付け、`DateTime` 型の構造体に変換して利用できるようになります。
なお、上記の `DateTimeSchema` に相当する機能は既に `SimpleSchema.Type.DateTime` に入っています。

`SimpleSchema` ビヘイビアが要求する関数は、以下の通りです。

```elixir
@callback schema(opts :: Keyword.t) :: simple_schema
@callback from_json(schema :: simple_schema, json :: any, opts :: Keyword.t) :: {:ok, any} | {:error, any}
@callback to_json(schema :: simple_schema, value :: any, opts :: Keyword.t) :: {:ok, any} | {:error, any}
```

`schema/1` で、そのモジュールが要求するシンプルスキーマを定義します。

`from_json/3` で、`value` を任意の型に変換して返します。
`value` は `schema/1` で返したシンプルスキーマによる検証が済んでいて、例えば上記の `DateTimeSchema.from_json/3` に渡された `value` は、`{:string, format: :datetime}` で検証されています。
そのため `value` が文字列であり、`:datetime` のフォーマットであることが保証されています。

ただし、`SimpleSchema.from_json/2` に `optimistic: true` が指定されていた場合、検証を行いません。この場合、正しい値を渡す責任はユーザにあります。

`to_json/3` で、変換された値をシンプルスキーマの満たす文字列に変換します。
`from_json/3` と逆の変換を行います。
この関数は `SimpleSchema.to_json/2` の内部で利用される関数なので、不要であれば常に `{:error, "not implemented"}` でも構いません。

## `defschema/1`

`defschema/1` は、`defstruct/1` による構造体の定義と、`SimpleSchema` ビヘイビアの実装を行います。

```elixir
defmodule Person do
  import SimpleSchema, only: [defschema: 1]

  defschema [
    name: :string,
    age: {:integer, minimum: 0},
  ]
end
```

このコードは、以下の様に変換されます。

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

`schema/1` で、`:name` と `:age` を持つマップとしてシンプルスキーマを定義しています。
渡された JSON のオブジェクトがこのシンプルスキーマの構造になっているかを検証した後、`Person.from_json/3` を呼び出して、`value` を `Person` 構造体に変換しています。
JSON のオブジェクトを特定の構造体に変換するためのヘルパーとして `SimpleSchema.Type.json_to_struct/3` があるので、これを使うと簡単に変換できます。
