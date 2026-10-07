### Comparison with env
| Feature            | `env`              | `envFrom`                       |
| ------------------ | ------------------ | ------------------------------- |
| Single key mapping | ✅                  | ❌ (maps all keys)               |
| Multiple keys      | ❌ (repeat `env`)   | ✅ (all keys automatically)      |
| Optional keys      | ✅ (via `optional`) | ✅ (via `optional`)              |
| Prefix support     | ❌                  | ✅ (prefix for all keys)         |
| Explicit control   | ✅ (per key)        | ❌ (maps everything from source) |

