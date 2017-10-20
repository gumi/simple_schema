defmodule SimpleSchema.Validator do
  @callback validate(get_json_schema :: (() -> any), json :: any, cache_key :: any) :: :ok | {:error, any}

  def validate(get_json_schema, json, cache_key) do
    validator = Application.get_env(:simple_schema, :validator, SimpleSchema.Validator.ExJsonSchema)
    validator.validate(get_json_schema, json, cache_key)
  end
end
