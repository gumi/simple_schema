# Changelog

## 1.1.10

- ex_json_schema を0.6.2 にアップデートしました。 これによってElixir 1.9.0 で warning が出る問題が解決されました。

## 1.1.9

- Elixir 1.9.0 に対応(Thanks @hiromoon !)

ただし Elixir 1.9.0 では ex_json_schema に[問題](https://github.com/jonasschmidt/ex_json_schema/pull/43) があり、warning が出てしまうため、必要であれば以下のようにして ex_json_schema を上書きすること。

```elixir
defp deps do
  [
    {:simple_schema, "~> 1.1.9"},
    # これを追加
    {:ex_json_schema, git: "https://github.com/gumi/ex_json_schema.git", tag: "v0.6.2-hotfix", override: true}
  ]
end
```

## 1.1.8

- 英語に疲れたので日本語にする
- `SimpleSchema.from_json/3` や `SimpleSchema.to_json/3` に `:get_json_schema` オプションを追加
- 依存ライブラリの更新

## 1.1.7

- Update dependencies

## 1.1.6

- Add `:struct_converter` global opts in `SimpleSchema.Schema.to_json_schema/2` to convert to any JSON like `{"$ref", "#/schemas/MyStruct1"}`.
- Add `.tool-version` file for [asdf](https://github.com/asdf-vm/asdf).
- Update dependencies

## 1.1.5

- Add `:unique_items` restriction for array simple schema.

## 1.1.4

- Update dependencies

## 1.1.3

- `SimpleSchema.Type.json_to_struct/3` and `SimpleSchema.Type.struct_to_json/3` can be nullable.

## 1.1.2

- Update dependencies

## 1.1.1

- `SimpleSchema.Type.DateTime` can be nullable.

## 1.1.0

- Add `:tolerant` option to allow non-specified keys.

## 1.0.3

- Apply elixir formatter
- Update dependencies

## 1.0.2

- Implement `:default` opts to map schema.
- Update documents.
