if Code.ensure_loaded?(Plug) do
  defmodule JaSerializer.Deserializer do
    @moduledoc """
    This plug "deserializes" params to underscores.

    For example these params:

        %{
          "data" => %{
            "attributes" => %{
              "foo-bar" => true
            }
          }
        }

    are transformed to:

        %{
          "data" => %{
            "attributes" => %{
              "foo_bar" => true
            }
          }
        }

    ## Usage

    Just include in your plug stack _after_ a json parser:

        plug Plug.Parsers, parsers: [:json], json_decoder: Poison
        plug JaSerializer.Deserializer

    """

    @behaviour Plug

    def init(opts), do: opts
    def call(conn, _opts) do
      conn
      |> Map.put(:params, format_keys(conn.params))
      |> Map.put(:query_params, format_query_params(conn.query_params))
    end

    defp format_keys(%{"data" => data} = params) do
      Map.merge(params, %{
        "data" => %{
          "type" => data["type"],
          "attributes" => do_format_keys(data["attributes"]),
          "relationships" => do_format_keys(data["relationships"])
        }
      })
    end
    defp format_keys(params), do: params

    def format_query_params(query_params) do
      do_deep_format_keys(query_params)
    end

    def do_deep_format_keys(map) when is_map(map) do
      Enum.reduce(map, %{}, &format_key_value/2)
    end
    def do_deep_format_keys(other), do: other

    defp format_key_value({key, value}, accumulator) when is_map(value) do
      Map.put(accumulator, format_key(key), do_deep_format_keys(value))
    end
    defp format_key_value({key, value}, accumulator) do
      Map.put(accumulator, format_key(key), value)
    end

    defp do_format_keys(map) when is_map(map) do
      Enum.reduce map, %{}, fn({k, v}, a) ->
        Map.put_new(a, format_key(k), v)
      end
    end
    defp do_format_keys(other), do: other

    #TODO: Support custom de-serialization (eg, camelcase)
    def format_key(key) do
      case Application.get_env(:ja_serializer, :key_format, :dasherized) do
        :dasherized -> dash_to_underscore(key)
        :underscored -> key
        _ -> key
      end
    end

    defp dash_to_underscore(key), do: String.replace(key, ~r/-/, "_")
  end
end
