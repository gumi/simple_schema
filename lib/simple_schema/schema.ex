defmodule SimpleSchema.Schema do
  @moduledoc """
  A module to convert a simple schema to JSON Schema

  Basic:

  ```
  iex> schema = %{name: :string,
  ...>            value: {:integer, optional: true},
  ...>            array: [:string],
  ...>            map: {%{x: :integer, y: :integer}, optional: true},
  ...>            param: {:any, optional: true}}
  iex> SimpleSchema.Schema.to_json_schema(schema)
  %{
    "type" => "object",
    "required" => ["array", "name"],
    "additionalProperties" => false,
    "properties" => %{
      "name" => %{"type" => "string"},
      "value" => %{"type" => "integer"},
      "array" => %{
        "type" => "array",
        "items" => %{"type" => "string"},
      },
      "map" => %{
        "type" => "object",
        "required" => ["x", "y"],
        "additionalProperties" => false,
        "properties" => %{
          "x" => %{"type" => "integer"},
          "y" => %{"type" => "integer"},
        },
      },
      "param" => %{
        "type" => ["array", "boolean", "integer", "null", "number", "object", "string"],
      },
    },
  }
  ```

  With restrictions:

  ```
  iex> schema = %{name: {:string, min_length: 8},
  ...>            value: {:integer, optional: true, nullable: true, maximum: 10},
  ...>            array: {[{:string, enum: ["aaa", "bbb"]}], min_items: 1}}
  iex> SimpleSchema.Schema.to_json_schema(schema)
  %{
    "type" => "object",
    "required" => ["array", "name"],
    "additionalProperties" => false,
    "properties" => %{
      "name" => %{
        "type" => "string",
        "minLength" => 8,
      },
      "value" => %{
        "type" => ["integer", "null"],
        "maximum" => 10,
      },
      "array" => %{
        "type" => "array",
        "minItems" => 1,
        "items" => %{
          "type" => "string",
          "enum" => [
            "aaa",
            "bbb",
          ],
        }
      },
    },
  }
  ```
  """

  @type boolean_opt :: {:nullable, boolean} | {:optional, boolean}
  @type boolean_opts :: [boolean_opt]
  @type boolean_type :: :boolean | {:boolean, boolean_opts}

  @type integer_opt :: {:nullable, boolean} | {:maximum, integer} | {:minimum, integer} | {:enum, [integer, ...]} | {:optional, boolean}
  @type integer_opts :: [integer_opt]
  @type integer_type :: :integer | {:integer, integer_opts}

  @type number_opt :: {:nullable, boolean} | {:maximum, float} | {:minimum, float} | {:optional, boolean}
  @type number_opts :: [number_opt]
  @type number_type :: :number | {:number, number_opts}

  @type null_opt :: {:optional, boolean}
  @type null_opts :: [null_opt]
  @type null_type :: :null | {:null, null_opts}

  @type string_format :: :datetime | :email
  @type string_opt :: {:nullable, boolean} | {:max_length, non_neg_integer()} | {:min_length, non_neg_integer()} | {:enum, [String.t, ...]} | {:format, string_format} | {:optional, boolean}
  @type string_opts :: [string_opt]
  @type string_type :: :string | {:string, string_opts}

  @type map_opt :: {:nullable, boolean} | {:optional, boolean}
  @type map_opts :: [map_opt]
  @type map_prim_type :: %{required(atom) => simple_schema}
  @type map_type :: map_prim_type | {map_prim_type, map_opts}

  @type array_opt :: {:nullable, boolean} | {:max_items, non_neg_integer()} | {:min_items, non_neg_integer()} | {:optional, boolean}
  @type array_opts :: [array_opt]
  @type array_type :: nonempty_list(simple_schema)

  @type any_opt :: {:optional, boolean}
  @type any_opts :: [any_opt]
  @type any_type :: :any | {:any, any_opts}

  @type module_opts :: Keyword.t
  @type module_type :: module | {module, module_opts}

  @type simple_schema :: boolean_type | integer_type | number_type | null_type | string_type | map_type | array_type | any_type | module_type

  @primitive_types [:boolean, :integer, :number, :null, :string, :any]

  defp raise_if_not_empty([]), do: :ok

  defp to_types(type, nullable)
  defp to_types(type, true), do: [type, "null"]
  defp to_types(type, false), do: type

  defp add_if_not_undefined(xs, _key, :undefined), do: xs
  defp add_if_not_undefined(xs, key, value), do: [{key, value} | xs]

  defp add_enum_if_not_undefined(xs, :undefined), do: xs
  defp add_enum_if_not_undefined(xs, [_ | _] = enum), do: [{"enum", enum} | xs]

  defp add_format_if_not_undefined(xs, :undefined), do: xs
  defp add_format_if_not_undefined(xs, :datetime), do: [{"format", "date-time"} | xs]
  defp add_format_if_not_undefined(xs, :email), do: [{"format", "email"} | xs]

  defp pop_optional({type, opts}) do
    {optional, opts} = Keyword.pop(opts, :optional, false)
    {optional, {type, opts}}
  end
  defp pop_optional(type), do: {false, type}

  def simple_schema_implemented?(schema) when is_atom(schema) do
    Code.ensure_loaded(schema)
    function_exported?(schema, :schema, 1) and function_exported?(schema, :convert, 2)
  end
  def simple_schema_implemented?(_) do
    false
  end

  def to_json_schema(:boolean), do: to_json_schema({:boolean, []})
  def to_json_schema({:boolean, opts}) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    raise_if_not_empty(opts)

    types = to_types("boolean", nullable)
    %{"type" => types}
  end

  def to_json_schema(:integer), do: to_json_schema({:integer, []})
  def to_json_schema({:integer, opts}) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {maximum, opts} = Keyword.pop(opts, :maximum, :undefined)
    {minimum, opts} = Keyword.pop(opts, :minimum, :undefined)
    {enum, opts} = Keyword.pop(opts, :enum, :undefined)
    raise_if_not_empty(opts)

    types = to_types("integer", nullable)
    xs = [{"type", types}]
    xs = add_if_not_undefined(xs, "maximum", maximum)
    xs = add_if_not_undefined(xs, "minimum", minimum)
    xs = add_enum_if_not_undefined(xs, enum)
    Enum.into(xs, %{})
  end

  def to_json_schema(:number), do: to_json_schema({:number, []})
  def to_json_schema({:number, opts}) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {maximum, opts} = Keyword.pop(opts, :maximum, :undefined)
    {minimum, opts} = Keyword.pop(opts, :minimum, :undefined)
    raise_if_not_empty(opts)

    types = to_types("number", nullable)
    xs = [{"type", types}]
    xs = add_if_not_undefined(xs, "maximum", maximum)
    xs = add_if_not_undefined(xs, "minimum", minimum)
    Enum.into(xs, %{})
  end

  def to_json_schema(:null), do: to_json_schema({:null, []})
  def to_json_schema({:null, []}) do
    %{"type" => "null"}
  end

  def to_json_schema(:string), do: to_json_schema({:string, []})
  def to_json_schema({:string, opts}) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {max_length, opts} = Keyword.pop(opts, :max_length, :undefined)
    {min_length, opts} = Keyword.pop(opts, :min_length, :undefined)
    {enum, opts} = Keyword.pop(opts, :enum, :undefined)
    {format, opts} = Keyword.pop(opts, :format, :undefined)
    raise_if_not_empty(opts)

    types = to_types("string", nullable)
    xs = [{"type", types}]
    xs = add_if_not_undefined(xs, "maxLength", max_length)
    xs = add_if_not_undefined(xs, "minLength", min_length)
    xs = add_enum_if_not_undefined(xs, enum)
    xs = add_format_if_not_undefined(xs, format)
    Enum.into(xs, %{})
  end

  def to_json_schema(:any), do: to_json_schema({:any, []})
  def to_json_schema({:any, opts}) do
    raise_if_not_empty(opts)

    # permit any types
    %{"type" => ["array", "boolean", "integer", "null", "number", "object", "string"]}
  end

  def to_json_schema(%{} = schema), do: to_json_schema({schema, []})
  def to_json_schema({%{} = schema, opts}) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    raise_if_not_empty(opts)

    properties =
      for {key, value} <- schema, into: %{} do
        {_optional, type} = pop_optional(value)
        {Atom.to_string(key), to_json_schema(type)}
      end

    required =
      schema
      |> Enum.reject(fn {_key, value} ->
           {optional, _type} = pop_optional(value)
           optional
         end)
      |> Enum.map(fn {key, _value} ->
           Atom.to_string(key)
         end)
      |> Enum.sort()

    types = to_types("object", nullable)
    xs = [
      {"type", types},
      {"additionalProperties", false},
      {"properties", properties},
    ]
    xs = case required do
      [] -> xs
      [_ | _] -> [{"required", required} | xs]
    end
    Enum.into(xs, %{})
  end

  def to_json_schema([_type] = array), do: to_json_schema({array, []})
  def to_json_schema({[type], opts}) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {max_items, opts} = Keyword.pop(opts, :max_items, :undefined)
    {min_items, opts} = Keyword.pop(opts, :min_items, :undefined)
    raise_if_not_empty(opts)

    types = to_types("array", nullable)
    xs = [{"type", types}, {"items", to_json_schema(type)}]
    xs = add_if_not_undefined(xs, "maxItems", max_items)
    xs = add_if_not_undefined(xs, "minItems", min_items)
    Enum.into(xs, %{})
  end

  def to_json_schema({schema, opts}) when is_atom(schema) do
    if not simple_schema_implemented?(schema) do
      raise "#{schema} is not exported a function schema/1"
    end
    {schema2, opts2} =
      case schema.schema(opts) do
        {schema2, opts2} -> {schema2, opts2}
        schema2 -> {schema2, []}
      end
    to_json_schema({schema2, opts2})
  end
  def to_json_schema(schema) when is_atom(schema), do: to_json_schema({schema, []})

  defp split_opts({schema, opts}), do: {schema, opts}
  defp split_opts(schema), do: {schema, []}

  @doc """
  Convert validated JSON to a simple schema value.

  If validation is passed, The JSON key should be all known atom except `:any` type.
  So the key can be converted by `String.to_existing_atom/1`.

      iex> schema = %{foo: %{bar: :integer}}
      iex> SimpleSchema.Schema.convert(schema, %{"foo" => %{"bar" => 10}})
      {:ok, %{foo: %{bar: 10}}}

  However, `:any` can contains an arbitrary key, so do not convert a value of `:any`.

      iex> schema = %{foo: :any}
      iex> SimpleSchema.Schema.convert(schema, %{"foo" => %{"bar" => 10}})
      {:ok, %{foo: %{"bar" => 10}}}
  """
  def convert(schema, value) do
    {schema, opts} = split_opts(schema)
    do_convert(schema, value, opts)
  end
  defp do_convert(%{} = schema, map, _opts) do
    result =
      Enum.reduce(map, {:ok, []}, fn {key, value}, acc ->
        atom_key = String.to_existing_atom(key)
        schema = Map.fetch!(schema, atom_key)
        case {acc, convert(schema, value)} do
          {{:ok, results}, {:ok, value}} -> {:ok, [{atom_key, value} | results]}
          {{:ok, _}, {:error, reason}} -> {:error, [reason]}
          {{:error, errors}, {:ok, _}} -> {:error, errors}
          {{:error, errors}, {:error, reason}} -> {:error, [reason | errors]}
        end
      end)
    case result do
      {:ok, results} -> {:ok, Enum.into(results, %{})}
      {:error, errors} -> {:error, errors}
    end
  end
  defp do_convert([element_schema], array, _opts) do
    result =
      Enum.reduce(array, {:ok, []}, fn value, acc ->
        case {acc, convert(element_schema, value)} do
          {{:ok, results}, {:ok, value}} -> {:ok, [value | results]}
          {{:ok, _}, {:error, reason}} -> {:error, [reason]}
          {{:error, errors}, {:ok, _}} -> {:error, errors}
          {{:error, errors}, {:error, reason}} -> {:error, [reason | errors]}
        end
      end)
    case result do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      {:error, errors} -> {:error, errors}
    end
  end
  defp do_convert(schema, value, _opts) when is_atom(schema) and schema in @primitive_types do
    {:ok, value}
  end
  defp do_convert(schema, value, opts) when is_atom(schema) do
    if not simple_schema_implemented?(schema) do
      raise "#{schema} is not implemented SimpleSchema behaviour."
    end

    case schema.convert(schema.schema(opts), value) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  end
end
