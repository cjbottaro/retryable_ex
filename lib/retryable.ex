defmodule Retryable do
  @moduledoc """
  Retry code with simple, intuitive options. No metaprogramming.

  A simple example...
  ```elixir
  Retryable.retryable [on: TimeoutError, tries: 5, sleep: 2], fn ->
    SomeApi.call
  end
  ```

  You can configure the defaults with `Mix.Config`...
  ```elixir
  use Mix.Config

  config :retryable, :defaults,
    tries: 10,
    sleep: fn n -> :math.pow(2, n) end
  ```

  You can make named configurations to be used later...
  ```elixir
  use Mix.Config

  config :retryable, :aws,
    message: ["timeout", ~r/throttling/i]
    tries: 5,
    sleep: 2

  Retryable.retryable(:aws, fn -> make_aws_call() end)
  ```
  """

  @defaults [
    on: [],
    tries: 1,
    sleep: 1,
    message: [],
  ]

  @typedoc """
  `options` for retryable.
  """
  @type options :: Keyword.t | %{optional(atom) => term}

  @typedoc """
  What to retry on (exceptions or :error).
  """
  @type on :: module | :error | [on]

  @typedoc """
  Exception message(s) to retry.
  """
  @type message :: String.t | Regex.t | [message]

  @typedoc """
  What number retry we're on. Zero based (first retry is 0).
  """
  @type count :: integer

  @typedoc """
  How many times to retry.
  """
  @type tries :: integer

  @typedoc """
  Time in seconds to sleep between retries.
  """
  @type sleep :: integer | float | (count -> integer | float)

  @typedoc """
  Function to run exactly once (similar to `after` in a `try` block).
  """
  @type after_fn :: (() -> any)

  @doc """
  Maybe retry some code.

  Return value is that of the given function.

  ## Options
  * `on` : Retry on exception or `:error`. Can be a list. Default `[]` (retry on any exception)
  * `message` : Only retry if exception message matches. Default `[]` (retry on any message)
  * `tries` : How many times to retry. Default `1`
  * `sleep` : How long to sleep (in seconds) between retries. Can be a function. Default: `1`
  * `after` : Code to run (exactly once) no matter how many retries (zero or more). Default: `nil`

  See the [types](#types) in this module for exact specifications of the `options`.

  When `:message` is specified the `=~` operator is used (e.g. regex or string contains).

  ## Named config

  You can set defaults and named configurations.
  ```elixir
  use Mix.Config

  config :retryable, :defaults,
    on: ArgumentError

  config :retryable, :my_config,
    tries: 10

  # Both these calls have the same effect.
  retryable(:my_config, fn -> ... end)
  retryable([on: ArgumentError, tries: 10], fn -> ... end)
  ```

  ## Examples

  Retry on specific exception(s):
  ```elixir
  retryable([on: ArgumentError], fn -> ... end)
  retryable([on: [ArgumentError, ArithmeticError]], fn -> ... end)
  ```

  Retry on a specific exception message(s):
  ```elixir
  retryable([message: "some substring"], fn -> ... end)
  retryable([message: ~r/some regex/], fn -> ... end)
  retryable([message: ["foo", ~r/bar/]], fn -> ... end)
  ```

  Retry on error (notice we are wrapping with our own `:ok` or `:error`):
  ```elixir
  retryable [on: :error], fn ->
    case something() do
      {:ok, _} = result -> {:ok, result} # Success, don't retry
      {:error, _} = result -> {:error, result} # Error, do retry
    end
  end
  ```

  Retry on error or exception:
  ```elixir
  retryable [on: [:error, ArgumentError]], fn ->
    case something() do
      {:ok, _} = result -> {:ok, result} # Success, don't retry
      {:error, _} = result -> {:error, result} # Error, do retry
    end
  end
  ```

  Retry with exponential backoff:
  ```elixir
  retryable [sleep: &(:math.pow(2, &1))], fn -> ... end
  ```
  """
  @spec retryable(options, (() -> term)) :: term
  @spec retryable(name :: atom, (() -> term)) :: term
  def retryable(options \\ [], func)

  def retryable(named_config, func)

  def retryable(options, func) when is_list(options) do
    config(:defaults)
      |> Keyword.merge(options)
      |> Map.new
      |> normalize_options(:on)
      |> normalize_options(:message)
      |> normalize_options(:after)
      |> retryable(func, 0)
  end

  def retryable(name, func) when is_atom(name) do
    name |> config |> retryable(func)
  end

  defp retryable(options, func, count) do
    try do
      func.() |> handle_error(options, func, count)
    rescue
      e -> handle_exception(e, options, func, count)
    after
      handle_after(options, count)
    end
  end

  defp handle_exception(e, options, func, count) do
    cond do
      count == options[:tries] ->
        reraise e, System.stacktrace
      !exception_match?(options, e) ->
        reraise e, System.stacktrace
      !message_match?(options, e.message) ->
        reraise e, System.stacktrace
      true ->
        sleep(options, count)
        retryable(options, func, count+1)
    end
  end

  defp handle_error(value, %{error: false}, _, _), do: value
  defp handle_error({:ok, value}, _, _, _), do: value
  defp handle_error({:error, value}, %{tries: tries}, _, count) when tries == count, do: value
  defp handle_error(_value, options, func, count) do
    sleep(options, count)
    retryable(options, func, count+1)
  end

  defp handle_after(%{after: after_fn}, 0), do: after_fn.()
  defp handle_after(_, _), do: nil

  defp sleep(%{sleep: sleep}, count) when is_function(sleep) do
    sleep.(count) * 1000 |> round |> :timer.sleep
  end

  defp sleep(%{sleep: sleep}, _) do
    (sleep * 1000) |> round |> :timer.sleep
  end

  defp normalize_options(options, :on) do
    on = List.wrap(options.on) |> Enum.uniq
    options
      |> Map.put(:error, Enum.member?(on, :error))
      |> Map.put(:on, List.delete(on, :error))
  end

  defp normalize_options(options, :message) do
    message = List.wrap(options.message) |> Enum.uniq
    Map.put(options, :message, message)
  end

  defp normalize_options(options, :after) do
    Map.put_new(options, :after, fn -> nil end)
  end

  defp exception_match?(%{on: []}, _), do: true
  defp exception_match?(%{on: exceptions}, e) do
    Enum.member?(exceptions, e.__struct__)
  end

  defp message_match?(%{message: []}, _), do: true
  defp message_match?(%{message: messages}, message) do
    Enum.any?(messages, &(message =~ &1))
  end

  defp config(:defaults) do
    defaults = Application.get_env(:retryable, :defaults, [])
    Keyword.merge(@defaults, defaults)
  end

  defp config(name) do
    Application.get_env(:retryable, name, [])
  end

end
