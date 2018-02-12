use Mix.Config

config :retryable_ex, :defaults,
  sleep: 0.001

config :retryable_ex, :test,
  message: "foobar",
  tries: 2
