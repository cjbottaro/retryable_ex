use Mix.Config

config :retryable, :defaults,
  sleep: 0.001

config :retryable, :test,
  message: "foobar",
  tries: 2
