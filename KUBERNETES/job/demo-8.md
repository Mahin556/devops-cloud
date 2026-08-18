Example 7 — backoffLimit

Consider:

spec:
  backoffLimit: 3

Think of it as:

How many Pod failures/retries can the Job tolerate before the Job is considered failed.

Example:

Job
 │
 ├── Pod-1 → Failed
 │
 ├── Pod-2 → Failed
 │
 ├── Pod-3 → Failed
 │
 └── Pod-4 → Failed
              ↓
          Job Failed

But be careful with saying:

"backoffLimit 3 always means exactly 4 Pods."

That's not a safe statement because Job failure accounting has additional details, including how failures are counted and timing/backoff behavior.

For interview purposes, say:

"backoffLimit specifies the number of retries/failures that a Job can tolerate before Kubernetes marks the Job as failed."