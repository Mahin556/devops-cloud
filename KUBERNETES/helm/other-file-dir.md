# Complete Helm Chart Structure and File Descriptions

## requirements.yaml

The 'requirements.yaml' file is used to declare dependencies for your Helm chart. It specifies other charts that your chart depends on, including the chart name, version constraints, and any additional settings.

**Key Components:**
- **dependencies** is a list of dependencies that your chart relies on.
- **name** is the name of the dependency chart.
- **version** is the version constraint for the dependency. Helm will attempt to use a version that satisfies this constraint.
- **repository** is the URL of the Helm chart repository where the dependency can be found.

---

### Example: File: mychart/requirements.yaml
```yaml
dependencies:
- name: nginx
  version: "1.2.3"
  repository: "https://charts.example.com/stable"
```

---

## helpers.tpl

The _helpers.tpl file in a Helm chart is a template helper file that contains reusable template snippets or functions. It allows you to define reusable pieces of code that can be included in other template files in your Helm chart.

The filename typically starts with an underscore (_) to indicate that it's a helper file and not meant to be rendered as a standalone Kubernetes resource.

---

### Example: File: mychart/templates/_helpers.tpl
```go-template
{{/*  
Create a helper function to generate labels for resources.  
Usage: {{ include "mychart.labels" $labels | indent 4 }}  
*/}}  

{{/*  
define "mychart.labels" -}}  
{{- $labels := .Values.labels | merge .Chart.labels | merge $}}  
{{- with .Values.podLabels -}}  
{{- $labels = $labels | merge . -}}  
{{- end -}}  

labels:  
{{- range $key, $value := $labels }}  
{{- $key }}: {{ quote $value }}  
{{- end -}}  
{{- end -}}
```

---

## NOTES.txt

- The NOTES.txt file in a Helm chart is used to provide post-installation notes or information that is displayed to the user after a Helm chart is deployed. These notes can include instructions, tips, or any other relevant information that users should be aware of after the deployment process.

- When users install your Helm chart, Helm will automatically display the content of the NOTES.txt file in the command line. Users can follow the provided instructions and notes to access and interact with the deployed application.

---

### Example: NOTES.txt
```
Thank you for using MyChart!

To access your application, use the following commands:

1. Get the application URL by running:
   ```bash
   export SERVICE_IP=$(kubectl get svc --namespace
   default mychart-mypapp-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo "Application URL: http://$SERVICE_IP:${.Values.service.port}"
   ```

2. Open your browser and navigate to the provided URL.

3. If you encounter any issues, check the application logs:
   ```bash
   kubectl logs --namespace default -l app=mypapp
   ```

Happy deploying!
```

---

## LICENSE

In a Helm chart, the LICENSE file typically contains information about the licensing terms and conditions for the Helm chart. It provides users and developers with details about how they can use, modify, and distribute the chart.

**Key Components:**
- **MIT License**: Specifies the type of license (in this case, the MIT License).
- **Copyright**: States the copyright holder or holders.
- **Permission is hereby granted...**: Outlines the permissions granted to users under the license.
- **The above copyright notice and this permission notice...**: Specifies that the license terms must be included in all copies or substantial portions of the software.
- **The SOFTWARE IS PROVIDED "AS IS"...**: Includes a disclaimer of warranty.
- **IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS...**: Includes a limitation of liability.

---

### Example: MIT License
```
MIT License

Copyright (c) [year] [author]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS"... WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

---

## tests/

- In a Helm chart, the `tests/` directory is commonly used to store test files and scripts that can be run to verify the correctness and functionality of the Helm chart. These tests are often automated and can be executed as part of a continuous integration (CI) pipeline or manually by users.
- `tests/` is a directory containing test scripts.
- `test-connection.sh`, `test-deployment.sh` and `test-service.sh` are examples of test scripts that can verify aspects of the chart, such as connectivity, deployment, and service accessibility.

---

### Directory Structure Example:
```
mychart/
- charts/  
  - templates/  
  - values.yaml  
  - Chart.yaml  
  - tests/  
    - test-connection.sh  
    - test-deployment.sh  
    - test-service.sh  
    - helminqore  
    - LICENSE.md
```

These scripts might include commands like `kubectl` to interact with the deployed resources, check logs, or make requests to the deployed application.

---

## .helmignore

- It specifies patterns of files and directories that Helm should ignore when packaging the chart. Helm uses the `.helmignore` file to determine which files to exclude when creating a chart package (tar.gz file) using the helm package command.

- `node_modules/`, `dist/`, and `build/` are directories that might be generated during development or build processes and are typically not needed in the packaged Helm chart.

- `.vscode/` and `.idea/` are directories specific to Visual Studio Code and IntelliJ IDEA, respectively, and are not necessary in the packaged Helm chart.

- `*.swp` and `*~` are examples of temporary files created by certain editors and are generally not needed in the packaged Helm chart.

---

### Example: .helmignore
```
# Ignore files and directories generated during development or build
node_modules/
dist/
build/

# Ignore editor-specific files
.vscode/
.idea/

# Ignore temporary files
*.swp
*~
```

---

## README.md

- The README.md file in a Helm chart serves as documentation to provide users with information about the chart, its purpose, how to use it, and any other relevant details.

### Example: README.md
```
# MyChart
MyChart is a Helm chart for deploying and managing MyApplication on Kubernetes.

## Installation
To install MyChart, use the following Helm command:
helm install my-release ./mychart

- Replace my-release with the desired release name.
```

---

## Summary of Helm Chart Files

| File/Directory | Purpose |
|----------------|---------|
| **requirements.yaml** | Declares chart dependencies |
| **_helpers.tpl** | Contains reusable template functions |
| **NOTES.txt** | Post-installation messages for users |
| **LICENSE** | Licensing terms and conditions |
| **tests/** | Test scripts for chart validation |
| **.helmignore** | Files to exclude from chart packaging |
| **README.md** | Chart documentation |

---

## Additional Notes

- **Chart.yaml**: Contains metadata about the chart (name, version, description, etc.)
- **values.yaml**: Default configuration values for the chart
- **templates/**: Directory containing Kubernetes resource templates
- **charts/**: Directory for dependent charts (subcharts)

These files work together to create a complete, well-structured Helm chart that can be easily distributed, installed, and maintained.