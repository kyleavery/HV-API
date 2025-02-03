# HV-API

A simple REST API for managing Hyper-V VMs. Meant to run on the Hyper-V host itself so you can interact with VMs over HTTP. Includes HTTP Basic authentication, but could be vulnerable as I'm parsing it myself ¯\_(ツ)_/¯

## Routes

These are the routes available in the API (for now). If you want more, please submit a PR.

### POST /api/v1/vm

Create a VM. The request body should contain the following JSON object:

```json
{
    "name": "Test",
    "memory": 8,
    "cpu": 4,
    "switch": "Default Switch",
    "os": "WIN_11",
    "tpm": true
}
```

### GET /api/v1/vm/{vm_name}

Retrieve information about the VM:

```json
{
    "guest_services": true,
    "ip": "192.168.0.1",
    "state": "Running"
}
```

### DELETE /api/v1/vm/{vm_name}

Delete a VM.

### POST /api/v1/vm/{vm_name}/start

Start a VM.

### POST /api/v1/vm/{vm_name}/stop

Stop a VM.

### POST /api/v1/vm/{vm_name}/reboot

Reboot a VM.

### PUT /api/v1/vm/{vm_name}/file

Upload a file to a VM. Use the `Destination-Path` header to specify the output file path in the VM.

### POST /api/v1/vm/{vm_name}/execute

Execute a PowerShell script in a VM. Put your script in the request body. Use the `args` parameter to pass arguments to your script. Pass VM credentials in the `VM-Username` and `VM-Password` headers. Any output will be returned in the response body.
