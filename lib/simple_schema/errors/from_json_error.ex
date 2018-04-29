defmodule SimpleSchema.FromJsonError do
  defexception [:reason]

  def message(exception) do
    msg = "failed from_json/2"

    if exception.reason != nil do
      msg <> ": #{inspect(exception.reason)}"
    else
      msg
    end
  end
end
