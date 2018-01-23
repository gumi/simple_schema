defmodule SimpleSchema.Type do
  def json_to_struct(type, schema, value) do
    case SimpleSchema.Schema.from_json(schema, value) do
      {:error, reason} ->
        {:error, reason}

      {:ok, fields} ->
        {:ok, struct(type, fields)}
    end
  end

  def struct_to_json(type, schema, value) do
    if type == value.__struct__ do
      SimpleSchema.Schema.to_json(schema, value)
    else
      {:error, {:unexpected_struct, value.__struct__}}
    end
  end
end
