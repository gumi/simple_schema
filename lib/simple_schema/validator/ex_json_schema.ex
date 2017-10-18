defmodule SimpleSchema.Validator.ExJsonSchema do
  def resolve(schema, json_schema) do
    Memoize.Cache.get_or_run({__MODULE__, :resolve, [schema]}, fn ->
      ExJsonSchema.Schema.resolve(json_schema)
    end)
  end

  def validate(schema, json_schema, json) do
    resolved_schema = resolve(schema, json_schema)
    ExJsonSchema.Validator.validate(resolved_schema, json)
  end
end
