# Retryable

Simply retry code without metaprogramming.

```elixir
Retryable.retryable [on: TimeoutError, sleep: 2, tries: 10], fn ->
  some_flakey_function()
end
```

See the full documentation at [https://hexdocs.pm/retryable_ex](https://hexdocs.pm/retryable_ex).

## Installation

```elixir
def deps do
  [
    {:retryable_ex, "~> 1.0"}
  ]
end
```
