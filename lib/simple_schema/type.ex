defmodule SimpleSchema.Type do
  def struct(type, schema, value) do
    case SimpleSchema.Schema.convert(schema, value) do
      {:error, reason} ->
        {:error, reason}
      {:ok, fields} ->
        {:ok, struct(type, fields)}
    end
  end
end
