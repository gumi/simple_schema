defmodule SimpleSchema.Validator do
  @callback validate(schema :: SimpleSchema.Schema.simple_schema, json_schema :: any, json :: any) :: :ok | {:error, any}

  def validate(schema, json_schema, json) do
    validator = Application.get_env(:simple_schema, :validator, SimpleSchema.Validator.ExJsonSchema)
    validator.validate(schema, json_schema, json)
  end
end
