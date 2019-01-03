# retryable changes

## 2.0.0
-----------
* `on: error` no longer needs to be "wrapped" and considers the following return value shapes to be failures: `:error`, `{:error, term}`, `{:error, term, ...}`. The shapes are customizable via a function.

## 1.0.0
-----------
* Initial release
