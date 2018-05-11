defmodule SimpleSchema.Type do
  defp split_opts({schema, opts}), do: {schema, opts}
  defp split_opts(schema), do: {schema, []}

  def json_to_struct(type, schema, value) do
    if value == nil do
      {_, opts} = split_opts(schema)
      nullable = Keyword.get(opts, :nullable, false)
      if nullable do
        {:ok, nil}
      else
        {:ok, :unexpected_nil_value}
      end
    else
      case SimpleSchema.Schema.from_json(schema, value) do
        {:error, reason} ->
          {:error, reason}

        {:ok, fields} ->
          {:ok, struct(type, fields)}
      end
    end
  end

  def struct_to_json(type, schema, value) do
    if value == nil do
      {_, opts} = split_opts(schema)
      nullable = Keyword.get(opts, :nullable, false)
      if nullable do
        {:ok, nil}
      else
        {:error, :unexpected_nil_value}
      end
    else
      if type == value.__struct__ do
        SimpleSchema.Schema.to_json(schema, value)
      else
        {:error, {:unexpected_struct, value.__struct__}}
      end
    end
  end
end
