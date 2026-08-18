Example 10 — Job with a logging-friendly setup

A simple Job:

apiVersion: batch/v1
kind: Job
metadata:
  name: batch-processing


spec:
  ttlSecondsAfterFinished: 300


  template:
    metadata:
      labels:
        app: batch-processing


    spec:
      containers:
        - name: processor
          image: busybox
          command:
            - sh
            - -c
            - |
              echo "Job started"
              echo "Processing data..."
              sleep 10
              echo "Job completed successfully"


      restartPolicy: Never

Architecture:

             Job
              |
           Pod created
              |
        processor container
              |
        stdout / stderr
              |
       Node logging agent
              |
       Centralized logging

After the Job completes:

Pod → Completed
Job → Complete

Then after 300 seconds:

Job → deleted

Depending on your retention/collection setup, the centralized logging system can still contain the application's logs.