defmodule SimpleSchema.Type.Unique do
  @behaviour SimpleSchema

  @impl SimpleSchema
  def schema(opts) do
    element_type = Keyword.fetch!(opts, :element_type)
    [element_type]
  end

  @impl SimpleSchema
  def from_json(schema, values, opts) do
    case SimpleSchema.from_json(schema, values) do
      {:error, reason} -> {:error, reason}
      {:ok, values} ->
        case Keyword.fetch(opts, :unique_key) do
          :error ->
            {:error, ":unique_key not found in #{inspect opts}"}
          {:ok, unique_key} ->
            uniqued_values = values |> Enum.uniq_by(&Map.fetch!(&1, unique_key))
            if length(values) == length(uniqued_values) do
              {:ok, values}
            else
              {:error, "Duplicate entry: key=#{unique_key}"}
            end
        end
    end
  end

  @impl SimpleSchema
  def to_json(schema, value, _opts) do
    SimpleSchema.Schema.to_json(schema, value)
  end
end
