# Retryable

Simple code retrying (in Elixir) without metaprogramming.

```elixir
Retryable.retryable [on: TimeoutError, sleep: 2, tries: 10], fn ->
  some_flakey_function()
end
```

See the full documentation at [https://hexdocs.pm/retryable_ex](https://hexdocs.pm/retryable_ex).

## Features

* Simple (modeled after Ruby's retryable gem)
* No metaprogramming
* Importing does not clutter your namespace
* User specified default configuration
* User specified named configurations
* Fully documented
* Complete test suite
