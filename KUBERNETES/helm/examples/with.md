Absolutely! Let's dive deep into Helm's `with` statement, using the example you provided as a foundation. I'll cover the syntax, how it works, common patterns, pitfalls, and best practices – all with practical examples.

---

## What is `with` in Helm?

`with` is a **control structure** in Helm (Go templates) that **changes the scope** (the current context, represented by `.`) for a block of code. It lets you refer to nested fields without repeating the full path, making templates cleaner and more maintainable.

### Basic Syntax

```go
{{- with .Values.some.nested.path }}
  # Inside this block, `.` refers to `.Values.some.nested.path`
  {{ .field1 }}
  {{ .field2 }}
{{- end }}
```

- `{{-` and `-}}` trim whitespace (recommended to avoid extra blank lines).
- The block executes **only if** the provided context is **non‑empty** (i.e., not `nil`, `false`, `0`, `""`, or an empty collection).  
  If the context is empty, the block is **skipped** entirely (no error, just nothing rendered).

---

## How `with` Changes the Scope (the Dot)

In Helm, `.` (the dot) always refers to the **current context**.  
- At the top level, `.` is the root object (containing `.Values`, `.Release`, `.Chart`, etc.).  
- When you use `{{- with .Values.envVariables }}`, inside the block `.` becomes **`envVariables`**.  
  So you can write `{{ .name }}` instead of `{{ .Values.envVariables.name }}`.

### Example from Your File

Your `values.yaml` includes:

```yaml
envVariables:
  - name: DATABASE_URL
    value: "your-database-url"
  - name: API_KEY
    value: "your-api-key"
  - name: DEBUG_MODE
    value: "true"
```

In `deployment.yaml`, you used:

```yaml
{{- with .Values.envVariables }}
env:
  {{- range . }}
  - name: {{ .name }}
    value: {{ .value | quote }}
  {{- end }}
{{- end }}
```

**What happens:**
1. `with` checks if `.Values.envVariables` exists and is non‑empty (it is, because it's a list with items).
2. Inside the `with` block, `.` now refers to that **list**.
3. The `range .` loops over that list – each iteration sets `.` to each element (a dictionary with `name` and `value`).
4. So `{{ .name }}` works directly.

The result is exactly what you saw in the final rendered YAML.

---

## When to Use `with` (and When Not)

### ✅ Good use cases:
- **Nested configuration blocks** – e.g., database settings, TLS, resources, probes.
- **Conditional inclusion of sections** – only render a block if the nested value is defined.
- **Simplifying loops over nested lists** – like your `envVariables`.

### ❌ Avoid when:
- You need to **access the outer scope** (e.g., `.Release.Name`) inside the `with` block – you can use `$` to refer to the root, but it's less intuitive.
- The nested path might be **empty** and you still want to render something (use `if` instead, or combine with `default`).
- You have multiple nested levels and need to preserve the original context – use `with` carefully or consider `range`/`if`.

---

## Common Pitfalls and How to Avoid Them

### 1. Empty Context → Block is Skipped
If `.Values.envVariables` is missing or an empty list, the entire `with` block will not render. This is often intentional, but if you need a fallback, use `if` instead:

```yaml
{{- if .Values.envVariables }}
  env: ...
{{- else }}
  env: []   # default empty array
{{- end }}
```

### 2. Losing Access to Outer Variables
Inside a `with` block, `.` changes, so you cannot directly access `.Values.other` or `.Release.Name`.  
**Solution:** Use `$` which always points to the **root context**:

```yaml
{{- with .Values.envVariables }}
env:
  {{- range . }}
  - name: {{ .name }}
    value: {{ .value | quote }}
    # Suppose we need the release name:
    release: {{ $.Release.Name }}
  {{- end }}
{{- end }}
```

### 3. Using `with` with a Map – Accessing Keys
If `envVariables` were a map (not a list), you could do:

```yaml
{{- with .Values.env }}
  DATABASE_URL: {{ .databaseUrl }}
  API_KEY: {{ .apiKey }}
{{- end }}
```

### 4. Nested `with` Blocks
You can nest `with` statements, but the inner block's `.` overrides the outer one. Use `$` to keep the outer context accessible.

---

## Comparison with `if` and `range`

| Construct | Purpose | Changes Scope? |
|-----------|---------|----------------|
| `if`      | Conditional rendering | ❌ No – `.` stays the same |
| `range`   | Iteration over lists/maps | ✅ Yes – inside loop, `.` is the current element |
| `with`    | Set context for a block | ✅ Yes – `.` becomes the given value |

You can combine them:

```yaml
{{- with .Values.envVariables }}
  {{- if gt (len .) 0 }}
    env:
    {{- range . }}
    - name: {{ .name }}
      value: {{ .value }}
    {{- end }}
  {{- end }}
{{- end }}
```

---

## Advanced Example: with + default

Sometimes you want to set a default if the context is empty. Since `with` skips empty values, you can use `default` outside:

```yaml
{{- $envVars := .Values.envVariables | default list }}
{{- with $envVars }}
env:
  {{- range . }}
  - name: {{ .name }}
    value: {{ .value }}
  {{- end }}
{{- end }}
```

Or use `if` for more control.

---

## Complete Working Example (Your File's Context)

Let’s expand the `deployment.yaml` snippet to include a typical `with` usage for **resources** and **probes**:

```yaml
containers:
  - name: {{ .Chart.Name }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
    ports:
      - containerPort: {{ .Values.service.port }}
    {{- with .Values.envVariables }}
    env:
      {{- range . }}
      - name: {{ .name }}
        value: {{ .value | quote }}
      {{- end }}
    {{- end }}
    {{- with .Values.resources }}
    resources:
      {{- toYaml . | nindent 10 }}
    {{- end }}
    {{- with .Values.livenessProbe }}
    livenessProbe:
      {{- toYaml . | nindent 10 }}
    {{- end }}
```

And in `values.yaml`:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
```

This will render only if those sections are defined – keeping the template clean.

---

## Best Practices

1. **Use `with` to reduce repetition** – if you refer to the same nested path multiple times, wrap it in `with`.
2. **Keep blocks short** – if a block becomes too long, consider splitting into helper templates.
3. **Be explicit about empty values** – if you want to always render a section (even with empty content), use `if` with a `default` fallback instead of `with`.
4. **Comment your `with` blocks** – especially when using `$` to access the root, to avoid confusion.
5. **Test with `helm template --debug`** – this shows the exact rendered output and helps catch scope issues.

---

## Summary Table of `with` Behaviour

| Input Context | `with` Block Execution | Inside `.` refers to |
|---------------|------------------------|-----------------------|
| Non‑empty (map, list, string, number, bool true) | ✅ Renders | The given value |
| Empty (`nil`, `false`, `0`, `""`, `[]`, `{}`) | ❌ Skipped | (not entered) |

---

## Final Thoughts

The `with` statement is a powerful tool for writing **DRY** (Don’t Repeat Yourself) Helm templates. It shines when you have deeply nested structures, environment variables, or configuration sections that are optional. Just remember the scope change and use `$` when you need the outer context.

Your example with `envVariables` perfectly illustrates its typical use: conditionally adding a list of environment variables if they are defined, without repeating `.Values.envVariables` every time.

If you have any further questions (e.g., combining `with` with `range` over maps, or using `with` in helpers), feel free to ask!