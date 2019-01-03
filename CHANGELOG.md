# retryable changes

## 1.1.0
-----------
* `on: error` no longer needs to be "wrapped" and considers the following return value shapes to be failures: `:error`, `{:error, reason}`, `{:error, reason, ...}`

## 1.0.0
-----------
* Initial release
