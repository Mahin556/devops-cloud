```bash
docker run -d --name my-nginx-container --memory 512m --cpus 1 nginx

CONTAINER_PID=$(ps aux | grep '[n]ginx' | sort -n -k 2 | head -n 1 | awk '{print $2}')

lsns -p $CONTAINER_PID

systemd-cgls --no-pager
systemd-cgtop
systemd-cgls /system.slice/docker-5ba642ac2146b6d7f2c538d673a480f2ab6a4cec8142eae034286fdefcb5d024.scope

cat /sys/fs/cgroup/system.slice/docker-5ba642ac2146b6d7f2c538d673a480f2ab6a4cec8142eae034286fdefcb5d024.scope/memory.stat

kubectl run nginx --image=nginx 
```
```bash
# View memory limit (hard limit)
cat /sys/fs/cgroup/system.slice/ssh.service/memory.max

# View CPU quota (format: "max 100000" means no limit; "50000 100000" means 50% of a CPU core)
cat /sys/fs/cgroup/system.slice/ssh.service/cpu.max
```
```bash
# Memory limit (max)
cat /sys/fs/cgroup/system.slice/docker-543dd4e96c046c3575c6e1da83a85be03f3299a5351674755493dd70e15e25d2.scope/memory.max

# Memory current usage
cat /sys/fs/cgroup/system.slice/docker-543dd4e96c046c3575c6e1da83a85be03f3299a5351674755493dd70e15e25d2.scope/memory.current

# Memory statistics (detailed)
cat /sys/fs/cgroup/system.slice/docker-543dd4e96c046c3575c6e1da83a85be03f3299a5351674755493dd70e15e25d2.scope/memory.stat

# CPU limit (quota/period)
cat /sys/fs/cgroup/system.slice/docker-543dd4e96c046c3575c6e1da83a85be03f3299a5351674755493dd70e15e25d2.scope/cpu.max

# CPU usage stats
cat /sys/fs/cgroup/system.slice/docker-543dd4e96c046c3575c6e1da83a85be03f3299a5351674755493dd70e15e25d2.scope/cpu.stat
```
```bash
systemctl show docker-543dd4e96c046c3575c6e1da83a85be03f3299a5351674755493dd70e15e25d2.scope | grep -E "MemoryMax|MemoryHigh|CPUQuota|TasksMax"
```
```bash
# Show configured limits (human-readable)
docker inspect 543dd4e96c04 --format='Memory Limit: {{.HostConfig.Memory}} bytes | CPU Quota: {{.HostConfig.CpuQuota}} | CPU Period: {{.HostConfig.CpuPeriod}}'

# Show real-time usage
docker stats 543dd4e96c04 --no-stream
```