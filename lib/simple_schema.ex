defmodule SimpleSchema do
  @callback schema(opts :: Keyword.t) :: SimpleSchema.Schema.type
  @callback convert(SimpleSchema.Schema.type, any) :: {:ok, any} | {:error, any}

  defp pop_default({value, opts}) do
    if Keyword.has_key?(opts, :default) do
      {default, opts} = Keyword.pop(opts, :default)
      {:ok, default, {value, opts}}
    else
      :error
    end
  end
  defp pop_default(_value) do
    :error
  end

  @doc ~S"""

  ```
  defmodule MySchema do
    defschema [
      username: {:string, min_length: 4},
      email: {:string, default: "", optional: true, format: :email},
    ]
  end
  ```

  is converted to:

  ```
  defmodule MySchema do
    @enforce_keys [:username]
    defstruct [:username, email: ""]

    @behaviour SimpleSchema

    @simple_schema %{
      username: {:string, min_length: 4},
      email: {:string, optional: true, format: :email},
    }

    @impl SimpleSchema
    def schema([]) do
      @simple_schema
    end

    @impl SimpleSchema
    def convert(schema, value) do
      SimpleSchema.Type.struct(__MODULE__, schema, value)
    end
  end
  ```
  """
  defmacro defschema(schema) do
    enforce_keys =
      schema
      |> Enum.filter(fn {_key, value} ->
        case pop_default(value) do
          {:ok, _default, _value} -> false
          :error -> true
        end
      end)
      |> Enum.map(fn {key, _} -> key end)
    structs =
      schema
      |> Enum.map(fn {key, value} ->
        case pop_default(value) do
          {:ok, default, _value} -> {key, default}
          :error -> key
        end
      end)
    simple_schema =
      schema
      |> Enum.map(fn {key, value} ->
        case pop_default(value) do
          {:ok, _default, value} -> {key, value}
          :error -> {key, value}
        end
      end)

    quote do
      @enforce_keys unquote(enforce_keys)
      defstruct unquote(structs)

      @behaviour SimpleSchema

      @simple_schema Enum.into(unquote(simple_schema), %{})

      @impl SimpleSchema
      def schema([]) do
        @simple_schema
      end

      @impl SimpleSchema
      def convert(schema, value) do
        SimpleSchema.Type.struct(__MODULE__, schema, value)
      end
    end
  end

  def from_json(schema, json) do
    json_schema = SimpleSchema.Schema.to_json_schema(schema)
    resolved_schema = ExJsonSchema.Schema.resolve(json_schema)
    case ExJsonSchema.Validator.validate(resolved_schema, json) do
      {:error, errors} ->
        {:error, errors}
      :ok ->
        SimpleSchema.Schema.convert(schema, json)
    end
  end
end
