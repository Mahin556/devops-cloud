```bash
# Start a single etcd node

docker run -d \
  --name etcd \
  -p 2379:2379 \
  -p 2380:2380 \
  -v etcd_data:/etcd-data \
  quay.io/coreos/etcd:v3.5.30 \
  etcd \
    --name node1 \
    --data-dir /etcd-data \
    --listen-client-urls http://0.0.0.0:2379 \
    --advertise-client-urls http://etcd:2379 \
    --listen-peer-urls http://0.0.0.0:2380 \
    --initial-advertise-peer-urls http://etcd:2380 \
    --initial-cluster node1=http://etcd:2380

# Put a key-value pair
docker exec etcd etcdctl put greeting "Hello from etcd"

# Get the value
docker exec etcd etcdctl get greeting

# List all keys
docker exec etcd etcdctl get "" --prefix --keys-only

docker rm -f etcd
```
```bash
# Start the cluster
docker compose up -d

# Verify cluster health
docker exec etcd1 etcdctl endpoint health \
  --endpoints=etcd1:2379,etcd2:2379,etcd3:2379

# Check cluster members
docker exec etcd1 etcdctl member list --write-out=table

docker compose down -v
```

Key-Value Operations
etcd organizes data in a flat key space. Prefix-based queries give you hierarchical behavior.

```bash
# Store configuration values with a hierarchical key structure
docker exec etcd1 etcdctl put /config/database/host "db.example.com"
docker exec etcd1 etcdctl put /config/database/port "5432"
docker exec etcd1 etcdctl put /config/database/name "myapp"
docker exec etcd1 etcdctl put /config/cache/host "redis.example.com"
docker exec etcd1 etcdctl put /config/cache/port "6379"

# Get all database config keys
docker exec etcd1 etcdctl get /config/database/ --prefix

# Get all config keys
docker exec etcd1 etcdctl get /config/ --prefix --keys-only

# Delete a key
docker exec etcd1 etcdctl del /config/cache/port

# Delete all keys under a prefix
docker exec etcd1 etcdctl del /config/cache/ --prefix
```

Watching for Changes

The watch feature lets clients react to key changes in real time. This is fundamental for service discovery and configuration management.
```bash
# In one terminal, start watching a key prefix
docker exec etcd1 etcdctl watch /services/ --prefix

# In another terminal, update the key
docker exec etcd1 etcdctl put /services/api-gateway '{"host":"10.0.1.5","port":8080,"status":"healthy"}'
docker exec etcd1 etcdctl put /services/auth-service '{"host":"10.0.1.6","port":8081,"status":"healthy"}'

# The watch terminal will show each change as it happens
```

Leases and TTLs

Leases let you attach time-to-live (TTL) values to keys. When the lease expires, all associated keys are deleted. This is perfect for service heartbeats.

```bash
# Grant a lease with a 30-second TTL
docker exec etcd1 etcdctl lease grant 30
# Output: lease 694d8284e21b2b0e granted with TTL(30s)

# Put a key with the lease (use the lease ID from above)
docker exec etcd1 etcdctl put /services/worker-01 '{"status":"alive"}' --lease=694d8284e21b2b0e

# Check the lease TTL
docker exec etcd1 etcdctl lease timetolive 694d8284e21b2b0e --keys

# Keep the lease alive (like a heartbeat)
docker exec etcd1 etcdctl lease keep-alive 694d8284e21b2b0e

# If you stop keeping the lease alive, the key auto-deletes after TTL
```

Distributed Locking
etcd supports distributed locks for coordinating processes across nodes.
```bash
# Acquire a lock (blocks until available)
docker exec etcd1 etcdctl lock /locks/migration-runner

# In another terminal, try to acquire the same lock (will block)
docker exec etcd1 etcdctl lock /locks/migration-runner
```

Fault Tolerance Testing
With three nodes, the cluster survives one node failure.
```bash
# Kill one node
docker stop etcd3

# Cluster still works (2 of 3 nodes form a quorum)
docker exec etcd1 etcdctl put /test/fault-tolerance "cluster still works"
docker exec etcd1 etcdctl get /test/fault-tolerance

# Check cluster health (one endpoint will be unhealthy)
docker exec etcd1 etcdctl endpoint health \
  --endpoints=etcd1:2379,etcd2:2379,etcd3:2379

# Bring the node back
docker start etcd3
```

Backup and Restore

```bash
# Create a snapshot backup
docker exec etcd1 etcdctl snapshot save /etcd-data/backup.db

# Copy backup to host
docker cp etcd1:/etcd-data/backup.db ./etcd-backup.db

# Check snapshot status
docker exec etcd1 etcdutl --write-out=table snapshot status /etcd-data/backup.db
```

Monitoring
```bash
# Cluster endpoint status
docker exec etcd1 etcdctl endpoint status \
  --endpoints=etcd1:2379,etcd2:2379,etcd3:2379 \
  --write-out=table

# Metrics endpoint (Prometheus format)
curl http://localhost:2379/metrics | head -50

# Check the current leader
docker exec etcd1 etcdctl endpoint status --write-out=json | python3 -m json.tool
```