

| Type                | Meaning                    | Behavior                                  |
| ------------------- | -------------------------- | ----------------------------------------- |
| `""` (Empty string) | Default                    | No checks → Pod mounts whatever exists    |
| `DirectoryOrCreate` | Create dir if missing      | Creates directory (0755) owned by kubelet |
| `Directory`         | MUST already exist         | Pod fails if not a directory              |
| `FileOrCreate`      | Create file if missing     | Creates regular file (0644)               |
| `File`              | MUST already exist         | Pod fails if missing                      |
| `Socket`            | Must exist and be a socket | Used for docker.sock                      |
| `CharDevice`        | Must be character device   | e.g., `/dev/null`                         |
| `BlockDevice`       | Must be block device       | e.g., `/dev/sda`                          |

---

```bash
hostPath:
  path: /data/app
  type: Directory
```