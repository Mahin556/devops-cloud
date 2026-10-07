Customizing the NGINX Ingress Controller via its ConfigMap is a powerful way to apply global settings, like JSON-formatted logs, across all your Ingress resources. Here’s a breakdown of how it works, using your example.

### ⚙️ How ConfigMap Customization Works

The Ingress Controller's ConfigMap is a central place to define global NGINX configurations. When you update this ConfigMap, the controller automatically detects the change and reloads NGINX to apply the new settings without requiring a restart of the controller pod.

### 📝 The ConfigMap Example Explained

Your example shows two key settings for enabling JSON logging:

1.  **`log-format-escape-json: "true"`**: This tells NGINX to escape variables in the log format as JSON strings. This is crucial for producing valid JSON output, as it properly escapes characters like quotes and backslashes within log fields.

2.  **`log-format-upstream: '{ ... }'`**: This defines the custom JSON log format. It uses NGINX's standard variables to include detailed information about each request. The variables you listed, such as `$time_iso8601`, `$remote_addr`, and `$upstream_status`, are all standard NGINX variables that the Ingress Controller makes available.

### 🚀 How to Apply the Changes

You would typically have a separate YAML file for your ConfigMap. Here is an example based on your snippet:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  log-format-escape-json: "true"
  log-format-upstream: '{"time":"$time_iso8601","remote_addr":"$remote_addr","proxy_protocol_addr":"$proxy_protocol_addr","proxy_protocol_port":"$proxy_protocol_port","x_forward_for":"$proxy_add_x_forwarded_for","remote_user":"$remote_user","host":"$host","request_method":"$request_method","request_uri":"$request_uri","server_protocol":"$server_protocol","status":$status,"request_time":$request_time,"request_length":$request_length,"bytes_sent":$bytes_sent,"upstream_name":"$proxy_upstream_name","upstream_addr":"$upstream_addr","upstream_uri":"$uri","upstream_response_length":$upstream_response_length,"upstream_response_time":$upstream_response_time,"upstream_status":$upstream_status,"http_referrer":"$http_referer","http_user_agent":"$http_user_agent","http_cookie":"$http_cookie","http_device_id":"$http_x_device_id","http_customer_id":"$http_x_customer_id"}'
```

**Important**: The name and namespace of the ConfigMap must match the configuration of your Ingress Controller deployment. The default name is often `ingress-nginx-controller` in the `ingress-nginx` namespace.

To apply this configuration, use the `kubectl apply` command:

```bash
kubectl apply -f your-configmap.yaml
```

The controller will automatically detect this change and reload its configuration.

### ✅ How to Verify the Changes

To confirm the new JSON log format is working, you can check the logs of the Ingress Controller pods:

```bash
kubectl -n ingress-nginx logs -l app.kubernetes.io/instance=ingress-nginx
```

You should see log entries in the new JSON format. For more detailed troubleshooting, you can also check the logs of a specific pod:

```bash
kubectl logs <nginx-ingress-pod> -n ingress-nginx
```

**A crucial point**: The `log-format-upstream` value is a string that contains a JSON object. You must ensure the JSON is valid, as any syntax error will cause NGINX to fail to reload. The controller logs will show errors if the reload fails. 