defmodule SimpleSchema.Type.DateTime do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(opts) do
    merged_opts = Keyword.merge(opts, format: :datetime)

    {:string, merged_opts}
  end

  @impl SimpleSchema
  def to_json(schema, value, opts) do
    do_to_json(schema, value, opts)
  end

  @impl SimpleSchema
  def from_json(schema, value, opts) do
    do_from_json(schema, value, opts)
  end

  defp do_to_json(_schema, nil, _opts), do: {:ok, nil}

  defp do_to_json(_schema, value, _opts) do
    {:ok, DateTime.to_iso8601(value)}
  end

  defp do_from_json(_schema, nil, _opts), do: {:ok, nil}

  defp do_from_json(_schema, value, _opts) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, reason} -> {:error, reason}
    end
  end
end
