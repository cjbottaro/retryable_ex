defmodule RetryableTest do
  use ExUnit.Case
  doctest Retryable

  import Mox
  import Retryable

  setup :verify_on_exit!

  test "retries on all exceptions" do
    expect FooMock, :foo, fn ->
      raise ArgumentError, message: "bad args"
    end

    expect FooMock, :foo, fn -> :ok end

    result = retryable fn ->
      FooMock.foo
    end

    assert result == :ok
  end

  test "retries on certain messages" do
    expect FooMock, :foo, fn ->
      raise ArgumentError, message: "bad args"
    end

    expect FooMock, :foo, fn -> :ok end

    retryable [message: "bad"], fn -> FooMock.foo end

    expect FooMock, :foo, fn ->
      raise ArgumentError, message: "good args"
    end

    assert_raise ArgumentError,  fn ->
      retryable [message: "bad"], fn -> FooMock.foo end
    end
  end

  test "retries on regex message" do
    expect FooMock, :foo, fn ->
      raise ArgumentError, message: "bad args"
    end

    expect FooMock, :foo, fn -> :ok end

    retryable [message: ["blah", ~r/bad/]], fn -> FooMock.foo end

    expect FooMock, :foo, fn ->
      raise ArgumentError, message: "good args"
    end

    assert_raise ArgumentError, fn ->
      retryable [message: ["blah", ~r/bad/]], fn -> FooMock.foo end
    end
  end

  test "retries on certain exceptions" do
    FooMock
      |> expect(:foo, fn -> raise ArithmeticError end)
      |> expect(:foo, fn -> raise ArgumentError end)
      |> expect(:foo, fn -> :ok end)

    assert_raise ArithmeticError, fn ->
      retryable [on: ArgumentError], &FooMock.foo/0
    end

    assert :ok == retryable([on: ArgumentError], &FooMock.foo/0)
  end

  test "retries on :error" do
    FooMock
      |> expect(:foo, fn -> :error end)
      |> expect(:foo, fn -> {:ok, "success"} end)

    assert {:ok, "success"} = retryable [on: :error], &FooMock.foo/0
  end

  test "retries on {:error, reason}" do
    FooMock
      |> expect(:foo, fn -> {:error, "fail"} end)
      |> expect(:foo, fn -> {:ok, "success"} end)

    assert {:ok, "success"} = retryable [on: :error], &FooMock.foo/0
  end

  test "retries on {:error, reason, extra}" do
    FooMock
      |> expect(:foo, fn -> {:error, "fail", "extra"} end)
      |> expect(:foo, fn -> {:ok, "success"} end)

    assert {:ok, "success"} = retryable [on: :error], &FooMock.foo/0
  end

  test "retries on {:failure, reason}" do
    FooMock
      |> expect(:foo, fn -> {:failure, "fail"} end)
      |> expect(:foo, fn -> {:ok, "success"} end)

    shape = fn
      {:failure, _} -> true
      _ -> false
    end

    assert {:ok, "success"} = retryable [on: {:error, shape}], &FooMock.foo/0
  end


  test "gives up on :error" do
    FooMock
      |> expect(:foo, 2, fn -> {:error, "no"} end)

    assert {:error, "no"} = retryable [on: :error], &FooMock.foo/0
  end

  test "sleep works with a function" do
    FooMock
      |> expect(:foo, 3, fn -> raise ArgumentError end)
      |> expect(:foo, fn 0 -> 0.001 end)
      |> expect(:foo, fn 1 -> 0.001 end)

    assert_raise ArgumentError, fn ->
      retryable [sleep: &FooMock.foo/1, tries: 2], &FooMock.foo/0
    end
  end

  test "after gets invoked once" do
    FooMock
      |> expect(:foo, fn -> raise ArithmeticError end)
      |> expect(:foo, fn -> :ok end)
      |> expect(:foo, fn :done -> nil end)

    assert :ok = retryable [after: fn -> FooMock.foo(:done) end], &FooMock.foo/0
  end

  test "it retries multiple times" do
    expect(FooMock, :foo, 3, fn -> raise ArgumentError end)
    assert_raise ArgumentError, fn ->
      retryable([tries: 2], &FooMock.foo/0)
    end
  end

  test "it works with named configs" do
    FooMock
      |> expect(:foo, fn -> raise ArgumentError, message: "foobar" end)
      |> expect(:foo, fn -> raise ArgumentError, message: "barfoo" end)

    assert_raise ArgumentError, fn ->
      retryable(:test, &FooMock.foo/0)
    end
  end

end
