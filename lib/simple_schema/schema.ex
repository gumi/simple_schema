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

  @type opts :: Keyword.t()

  @type boolean_type :: :boolean | {:boolean, opts}
  @type integer_type :: :integer | {:integer, opts}
  @type number_type :: :number | {:number, opts}
  @type null_type :: :null | {:null, opts}
  @type string_type :: :string | {:string, opts}
  @type map_type ::
          %{required(atom) => simple_schema} | {%{required(atom) => simple_schema}, opts}
  @type array_type :: nonempty_list(simple_schema) | {nonempty_list(simple_schema), opts}
  @type any_type :: :any | {:any, opts}
  @type module_type :: module | {module, opts}

  @type simple_schema ::
          boolean_type
          | integer_type
          | number_type
          | null_type
          | string_type
          | map_type
          | array_type
          | any_type
          | module_type

  @primitive_types [:boolean, :integer, :number, :null, :string, :any]

  defp raise_if_unexpected_opts(opts) do
    {_, opts} = Keyword.pop(opts, :field)
    {_, opts} = Keyword.pop(opts, :meta)
    do_raise_if_unexpected_opts(opts)
  end

  defp do_raise_if_unexpected_opts([]), do: :ok

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

  defp pop_optional(type) do
    {false, type}
  end

  @undefined_default :simple_schema_default_undefined

  defp pop_default({type, opts}) do
    {optional, opts} = Keyword.pop(opts, :default, @undefined_default)
    {optional, {type, opts}}
  end

  defp pop_default(type) do
    {@undefined_default, type}
  end

  defp get_field(key, {_, opts}) do
    case Keyword.fetch(opts, :field) do
      :error -> Atom.to_string(key)
      {:ok, value} -> value
    end
  end

  defp get_field(key, _) do
    Atom.to_string(key)
  end

  def simple_schema_implemented?(schema) when is_atom(schema) do
    Code.ensure_loaded(schema)

    schema? = function_exported?(schema, :schema, 1)
    from_json? = function_exported?(schema, :from_json, 3)
    to_json? = function_exported?(schema, :to_json, 3)

    schema? and from_json? and to_json?
  end

  def simple_schema_implemented?(_) do
    false
  end

  def to_json_schema(schema, global_opts \\ [])

  def to_json_schema(:boolean, global_opts), do: to_json_schema({:boolean, []}, global_opts)

  def to_json_schema({:boolean, opts}, _global_opts) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    raise_if_unexpected_opts(opts)

    types = to_types("boolean", nullable)
    %{"type" => types}
  end

  def to_json_schema(:integer, global_opts), do: to_json_schema({:integer, []}, global_opts)

  def to_json_schema({:integer, opts}, _global_opts) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {maximum, opts} = Keyword.pop(opts, :maximum, :undefined)
    {minimum, opts} = Keyword.pop(opts, :minimum, :undefined)
    {enum, opts} = Keyword.pop(opts, :enum, :undefined)
    raise_if_unexpected_opts(opts)

    types = to_types("integer", nullable)
    xs = [{"type", types}]
    xs = add_if_not_undefined(xs, "maximum", maximum)
    xs = add_if_not_undefined(xs, "minimum", minimum)
    xs = add_enum_if_not_undefined(xs, enum)
    Enum.into(xs, %{})
  end

  def to_json_schema(:number, global_opts), do: to_json_schema({:number, []}, global_opts)

  def to_json_schema({:number, opts}, _global_opts) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {maximum, opts} = Keyword.pop(opts, :maximum, :undefined)
    {minimum, opts} = Keyword.pop(opts, :minimum, :undefined)
    raise_if_unexpected_opts(opts)

    types = to_types("number", nullable)
    xs = [{"type", types}]
    xs = add_if_not_undefined(xs, "maximum", maximum)
    xs = add_if_not_undefined(xs, "minimum", minimum)
    Enum.into(xs, %{})
  end

  def to_json_schema(:null, global_opts), do: to_json_schema({:null, []}, global_opts)

  def to_json_schema({:null, []}, _global_opts) do
    %{"type" => "null"}
  end

  def to_json_schema(:string, global_opts), do: to_json_schema({:string, []}, global_opts)

  def to_json_schema({:string, opts}, _global_opts) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {max_length, opts} = Keyword.pop(opts, :max_length, :undefined)
    {min_length, opts} = Keyword.pop(opts, :min_length, :undefined)
    {enum, opts} = Keyword.pop(opts, :enum, :undefined)
    {format, opts} = Keyword.pop(opts, :format, :undefined)
    raise_if_unexpected_opts(opts)

    types = to_types("string", nullable)
    xs = [{"type", types}]
    xs = add_if_not_undefined(xs, "maxLength", max_length)
    xs = add_if_not_undefined(xs, "minLength", min_length)
    xs = add_enum_if_not_undefined(xs, enum)
    xs = add_format_if_not_undefined(xs, format)
    Enum.into(xs, %{})
  end

  def to_json_schema(:any, global_opts), do: to_json_schema({:any, []}, global_opts)

  def to_json_schema({:any, opts}, _global_opts) do
    raise_if_unexpected_opts(opts)

    # permit any types
    %{"type" => ["array", "boolean", "integer", "null", "number", "object", "string"]}
  end

  def to_json_schema(%{} = schema, global_opts), do: to_json_schema({schema, []}, global_opts)

  def to_json_schema({%{} = schema, opts}, global_opts) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {tolerance, opts} = Keyword.pop(opts, :tolerant, false)
    raise_if_unexpected_opts(opts)

    properties =
      for {key, type} <- schema, into: %{} do
        {_optional, type} = pop_optional(type)
        {_default, type} = pop_default(type)
        key = get_field(key, type)
        {key, to_json_schema(type, global_opts)}
      end

    required =
      schema
      |> Enum.filter(fn {_key, type} ->
        {optional, _type} = pop_optional(type)
        {default, _type} = pop_default(type)
        not optional && default == @undefined_default
      end)
      |> Enum.map(fn {key, type} ->
        get_field(key, type)
      end)
      |> Enum.sort()

    types = to_types("object", nullable)

    xs = [
      {"type", types},
      {"additionalProperties", tolerance},
      {"properties", properties}
    ]

    xs =
      case required do
        [] -> xs
        [_ | _] -> [{"required", required} | xs]
      end

    Enum.into(xs, %{})
  end

  def to_json_schema([_type] = array, global_opts), do: to_json_schema({array, []}, global_opts)

  def to_json_schema({[type], opts}, global_opts) do
    {nullable, opts} = Keyword.pop(opts, :nullable, false)
    {max_items, opts} = Keyword.pop(opts, :max_items, :undefined)
    {min_items, opts} = Keyword.pop(opts, :min_items, :undefined)
    {unique_items, opts} = Keyword.pop(opts, :unique_items, :undefined)
    raise_if_unexpected_opts(opts)

    types = to_types("array", nullable)
    xs = [{"type", types}, {"items", to_json_schema(type, global_opts)}]
    xs = add_if_not_undefined(xs, "maxItems", max_items)
    xs = add_if_not_undefined(xs, "minItems", min_items)
    xs = add_if_not_undefined(xs, "uniqueItems", unique_items)
    Enum.into(xs, %{})
  end

  def to_json_schema({schema, opts}, global_opts) when is_atom(schema) do
    if not simple_schema_implemented?(schema) do
      raise "#{schema} is not exported a function schema/1"
    end

    case Keyword.fetch(global_opts, :struct_converter) do
      {:ok, struct_converter} ->
        struct_converter.(schema, opts)
      :error ->
        {schema2, opts2} =
          case schema.schema(opts) do
            {schema2, opts2} -> {schema2, opts2}
            schema2 -> {schema2, []}
          end

        to_json_schema({schema2, opts2}, global_opts)
    end
  end

  def to_json_schema(schema, global_opts) when is_atom(schema), do: to_json_schema({schema, []}, global_opts)

  defp split_opts({schema, opts}), do: {schema, opts}
  defp split_opts(schema), do: {schema, []}

  defp reduce_results(results, opts \\ []) do
    result =
      results
      |> Enum.reduce({:ok, []}, fn
        {:ok, value}, {:ok, values} -> {:ok, [value | values]}
        {:error, error}, {:ok, _} -> {:error, [error]}
        {:ok, _}, {:error, errors} -> {:error, errors}
        {:error, error}, {:error, errors} -> {:error, [error | errors]}
      end)

    reverse = Keyword.get(opts, :reverse, false)

    if reverse do
      case result do
        {:ok, values} -> {:ok, Enum.reverse(values)}
        {:error, errors} -> {:error, Enum.reverse(errors)}
      end
    else
      result
    end
  end

  @doc """
  Convert validated JSON to a simple schema value.

  If validation is passed, The JSON key should be all known atom except `:any` type.
  So the key can be converted by `String.to_existing_atom/1`.

      iex> schema = %{foo: %{bar: :integer}}
      iex> SimpleSchema.Schema.from_json(schema, %{"foo" => %{"bar" => 10}})
      {:ok, %{foo: %{bar: 10}}}

  However, `:any` can contains an arbitrary key, so do not convert a value of `:any`.

      iex> schema = %{foo: :any}
      iex> SimpleSchema.Schema.from_json(schema, %{"foo" => %{"bar" => 10}})
      {:ok, %{foo: %{"bar" => 10}}}
  """
  def from_json(schema, value) do
    {schema, opts} = split_opts(schema)
    do_from_json(schema, value, opts)
  end

  defp do_from_json(%{} = schema, map, opts) do
    lookup_field =
      schema
      |> Enum.map(fn {atom_key, schema} ->
        {_, opts} = split_opts(schema)
        field = Keyword.get(opts, :field, Atom.to_string(atom_key))
        {field, atom_key}
      end)
      |> Enum.into(%{})

    # drop unknown lookup_field keys from map if :tolerant opts is `true`
    map =
      if Keyword.get(opts, :tolerant, false) do
        map |> Map.take(lookup_field |> Map.keys())
      else
        map
      end

    # Use default value if :default opts is specified
    default_value =
      schema
      |> Enum.reduce([], fn {key, schema}, results ->
        {_, opts} = split_opts(schema)

        case Keyword.fetch(opts, :default) do
          {:ok, default} -> [{key, default} | results]
          :error -> results
        end
      end)
      |> Enum.into(%{})

    result =
      map
      |> Enum.map(fn {key, value} ->
        case Map.fetch(lookup_field, key) do
          :error ->
            {:error, {:key_not_found, key, lookup_field}}

          {:ok, atom_key} ->
            schema = Map.fetch!(schema, atom_key)
            {_default, schema} = pop_default(schema)

            case from_json(schema, value) do
              {:ok, result} -> {:ok, {atom_key, result}}
              {:error, reason} -> {:error, reason}
            end
        end
      end)
      |> reduce_results()

    case result do
      {:ok, results} -> {:ok, Enum.into(results, default_value)}
      {:error, errors} -> {:error, errors}
    end
  end

  defp do_from_json([element_schema], array, _opts) do
    array
    |> Enum.map(fn value ->
      from_json(element_schema, value)
    end)
    |> reduce_results(reverse: true)
  end

  defp do_from_json(schema, value, _opts) when is_atom(schema) and schema in @primitive_types do
    {:ok, value}
  end

  defp do_from_json(schema, value, opts) when is_atom(schema) do
    if not simple_schema_implemented?(schema) do
      raise "#{schema} is not implemented SimpleSchema behaviour."
    end

    schema.from_json(schema.schema(opts), value, opts)
  end

  @doc """
  Convert a simple schema value to JSON value.
  """
  def to_json(schema, value) do
    {schema, opts} = split_opts(schema)
    do_to_json(schema, value, opts)
  end

  defp do_to_json(%{} = schema, map, _opts) do
    result =
      schema
      |> Enum.map(fn {key, type} ->
        case Map.fetch(map, key) do
          :error ->
            # get default value if :default opts is specified
            {default, type} = pop_default(type)

            if default == @undefined_default do
              {:error, {:key_not_found, key}}
            else
              case to_json(type, default) do
                {:error, reason} ->
                  {:error, reason}

                {:ok, json} ->
                  key = get_field(key, type)
                  {:ok, {key, json}}
              end
            end

          {:ok, value} ->
            {_default, type} = pop_default(type)

            case to_json(type, value) do
              {:error, reason} ->
                {:error, reason}

              {:ok, json} ->
                key = get_field(key, type)
                {:ok, {key, json}}
            end
        end
      end)
      |> reduce_results()

    case result do
      {:ok, results} -> {:ok, Enum.into(results, %{})}
      {:error, errors} -> {:error, errors}
    end
  end

  defp do_to_json([element_schema], array, _opts) do
    array
    |> Enum.map(fn value ->
      to_json(element_schema, value)
    end)
    |> reduce_results(reverse: true)
  end

  defp do_to_json(schema, value, _opts) when is_atom(schema) and schema in @primitive_types do
    {:ok, value}
  end

  defp do_to_json(schema, value, opts) when is_atom(schema) do
    if not simple_schema_implemented?(schema) do
      raise "#{schema} is not implemented SimpleSchema behaviour."
    end

    schema.to_json(schema.schema(opts), value, opts)
  end
end
