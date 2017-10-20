defmodule SimpleSchema.Validator.ExJsonSchema do
  @behaviour SimpleSchema.Validator

  defp resolve(get_json_schema, cache_key) do
    Memoize.Cache.get_or_run({__MODULE__, :resolve, [cache_key]}, fn ->
      json_schema = get_json_schema.()
      ExJsonSchema.Schema.resolve(json_schema)
    end)
  end

  @impl SimpleSchema.Validator
  def validate(get_json_schema, json, cache_key) do
    resolved_schema = resolve(get_json_schema, cache_key)
    ExJsonSchema.Validator.validate(resolved_schema, json)
  end
end
