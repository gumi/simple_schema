defmodule SimpleSchema do
  @moduledoc """
  #{File.read!("README.md")}
  """

  @type simple_schema :: SimpleSchema.Schema.simple_schema

  @callback schema(opts :: Keyword.t) :: simple_schema
  @callback from_json(schema :: simple_schema, json :: any, opts :: Keyword.t) :: {:ok, any} | {:error, any}
  @callback to_json(schema :: simple_schema, value :: any, opts :: Keyword.t) :: {:ok, any} | {:error, any}

  @undefined_default :simple_schema_default_undefined

  defp get_default({type, opts}) do
    Keyword.get(opts, :default, @undefined_default)
  end
  defp get_default(type) do
    @undefined_default
  end

  @doc ~S"""
  Generate a struct and implement SimpleSchema behaviour by the specified schema.

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
      email: {:string, default: "", optional: true, format: :email},
    }

    @impl SimpleSchema
    def schema(opts) do
      {@simple_schema, opts}
    end

    @impl SimpleSchema
    def from_json(schema, value, _opts) do
      SimpleSchema.Type.json_to_struct(__MODULE__, schema, value)
    end

    @impl SimpleSchema
    def to_json(schema, value, _opts) do
      SimpleSchema.Type.struct_to_json(__MODULE__, schema, value)
    end
  end
  ```
  """
  defmacro defschema(schema) do
    enforce_keys =
      schema
      |> Enum.filter(fn {_key, value} ->
        get_default(value) == @undefined_default
      end)
      |> Enum.map(fn {key, _} -> key end)
    structs =
      schema
      |> Enum.map(fn {key, value} ->
        default = get_default(value)
        if default == @undefined_default do
          key
        else
          {key, default}
        end
      end)
    simple_schema = schema

    quote do
      @enforce_keys unquote(enforce_keys)
      defstruct unquote(structs)

      @behaviour SimpleSchema

      @simple_schema Enum.into(unquote(simple_schema), %{})

      @impl SimpleSchema
      def schema(opts) do
        {@simple_schema, opts}
      end

      @impl SimpleSchema
      def from_json(schema, value, _opts) do
        SimpleSchema.Type.json_to_struct(__MODULE__, schema, value)
      end

      @impl SimpleSchema
      def to_json(schema, value, _opts) do
        SimpleSchema.Type.struct_to_json(__MODULE__, schema, value)
      end
    end
  end

  @doc """
  Convert JSON value to a simple schema value.

  JSON value is validated before it is converted to a simple schema value.

  If `optimistic: true` is specified in `opts`, JSON value is not validated before it is converted.
  """
  def from_json(schema, json, opts \\ []) do
    optimistic = Keyword.get(opts, :optimistic, false)
    cache_key = Keyword.get(opts, :cache_key, schema)
    if optimistic do
      SimpleSchema.Schema.from_json(schema, json)
    else
      get_json_schema = fn -> SimpleSchema.Schema.to_json_schema(schema) end
      case SimpleSchema.Validator.validate(get_json_schema, json, cache_key) do
        {:error, reason} ->
          {:error, reason}
        :ok ->
          SimpleSchema.Schema.from_json(schema, json)
      end
    end
  end

  def from_json!(schema, json, opts \\ []) do
    case from_json(schema, json, opts) do
      {:ok, value} ->
        value
      {:error, reason} ->
        raise "failed from_json/2: #{inspect reason}"
    end
  end

  @doc """
  Convert a simple schema value to JSON value.

  If `optimistic: true` is specified in `opts`, JSON value is not validated after it is converted.
  Otherwise, JSON value is validated after it is converted.
  """
  def to_json(schema, value, opts \\ []) do
    optimistic = Keyword.get(opts, :optimistic, false)
    cache_key = Keyword.get(opts, :cache_key, schema)

    case SimpleSchema.Schema.to_json(schema, value) do
      {:error, reason} -> {:error, reason}
      {:ok, json} ->
        if optimistic do
          {:ok, json}
        else
          get_json_schema = fn -> SimpleSchema.Schema.to_json_schema(schema) end
          case SimpleSchema.Validator.validate(get_json_schema, json, cache_key) do
            {:error, reason} ->
              {:error, reason}
            :ok ->
              {:ok, json}
          end
        end
    end
  end

  def to_json!(schema, value, opts \\ []) do
    case to_json(schema, value, opts) do
      {:ok, json} ->
        json
      {:error, reason} ->
        raise "failed to_json/3: #{inspect reason}"
    end
  end

end
