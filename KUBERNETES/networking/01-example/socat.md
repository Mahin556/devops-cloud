Yes, you **can** use `socat` to create a tunnel between the two servers, and it is a valid approach for establishing connectivity. However, it is a more complex solution than simply fixing the routing configuration.

`socat` can create virtual network interfaces (TUN for Layer 3, TAP for Layer 2) and "wire" them together over a UDP or TCP connection. This effectively creates a point-to-point link between the two machines.

### How it would work for your setup

1.  **Create the Tunnel:** On each server, you would run a `socat` command that creates a TUN interface and connects it to the other server over UDP.
2.  **Assign IPs:** You would assign new IP addresses (e.g., `10.0.0.1` and `10.0.0.2`) to these new TUN interfaces on each server. These addresses would be in a separate, private subnet.
3.  **Add Routes:** You would then add routes on each server to direct traffic for the *other* server's bridge subnet (`172.16.1.0/24` on Server Two, `172.16.0.0/24` on Server One) through the new TUN interface.

### Example Commands

Here is a conceptual example. **You would need to run these as root (`sudo`) on each respective server.**

**On Server One (with the problematic gateway):**
```bash
# This creates a TUN interface (tun0) with address 10.0.0.1 and connects to Server Two over UDP
sudo socat -d -d UDP-LISTEN:9000,reuseaddr TUN:10.0.0.1/24,up
```

**On Server Two:**
```bash
# This connects to Server One and creates a TUN interface (tun0) with address 10.0.0.2
sudo socat -d -d UDP:192.168.56.11:9000 TUN:10.0.0.2/24,up
```

After both `socat` commands are running, you would need to add the routing rules. For example, on **Server One**:
```bash
sudo ip route add 172.16.1.0/24 via 10.0.0.2 dev tun0
```

### Important Considerations

*   **Protocol:** You must use UDP for this, not TCP. TCP can merge or split packets, which breaks the packet boundaries that TUN/TAP interfaces rely on. UDP is preferred for this reason.
*   **Complexity vs. Simplicity:** While `socat` works, it adds an extra layer of abstraction. The original error you encountered (`Nexthop has invalid gateway`) is a standard routing issue. The cleanest solution is almost always to ensure the gateway IP is on a directly connected subnet, as was suggested in the previous analysis.
*   **Not a "Simple" Bridge:** `socat` is not a simple bridge. It creates a point-to-point tunnel. You still need to configure IP addresses and routing rules on the TUN interfaces for traffic to flow between the different subnets.
*   **Permissions:** Creating TUN/TAP devices typically requires root privileges.
*   **Use Case:** `socat` is an excellent tool for building lightweight, ad-hoc VPNs or for tunneling when the underlying network topology cannot be easily changed. However, for a simple routing fix between two directly connected servers, adjusting the IP addresses is the more straightforward approach.

In summary, `socat` is a viable workaround if you cannot change the IP configuration of your servers. But if you have the ability to adjust the IPs on `enp0s8` to be on the same subnet, that is the simpler and recommended solution.