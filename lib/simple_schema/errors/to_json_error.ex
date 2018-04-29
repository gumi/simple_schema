defmodule SimpleSchema.ToJsonError do
  defexception [:reason]

  def message(exception) do
    msg = "failed to_json/3"

    if exception.reason != nil do
      msg <> ": #{inspect(exception.reason)}"
    else
      msg
    end
  end
end
