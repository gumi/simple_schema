defmodule SimpleSchema.Type.DateTime do
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
