defmodule SimpleSchema.Validator do
  @callback validate(json_schema :: any, json :: any, cache_key :: any) :: :ok | {:error, any}

  def validate(json_schema, json, cache_key) do
    validator = Application.get_env(:simple_schema, :validator, SimpleSchema.Validator.ExJsonSchema)
    validator.validate(json_schema, json, cache_key)
  end
end
