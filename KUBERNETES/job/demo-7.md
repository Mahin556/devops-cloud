8. The BIG difference: Never vs OnFailure

This is extremely important for interviews.

restartPolicy: Never
Container fails
      ↓
Pod becomes Failed
      ↓
Job Controller sees failure
      ↓
New Pod

Example:

Pod-1 → Failed
Pod-2 → Failed
Pod-3 → Success
restartPolicy: OnFailure
Container fails
      ↓
Kubelet restarts container
      ↓
Same Pod

Example:

Pod-1
 └── Container
       ├── attempt 1 → Failed
       ├── attempt 2 → Failed
       ├── attempt 3 → Success

So:

Behavior	Never	OnFailure
Container restart by kubelet	❌	✅
Same Pod reused	❌ for failed execution	✅
Job Controller creates replacement Pod	✅ when needed	May not need to if container eventually succeeds
Valid for Job	✅	✅