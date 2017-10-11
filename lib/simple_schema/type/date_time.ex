defmodule SimpleSchema.Type.DateTime do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(_opts) do
    {:string, format: :datetime}
  end

  @impl SimpleSchema
  def convert(_schema, value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, reason} -> {:error, reason}
    end
  end
end
