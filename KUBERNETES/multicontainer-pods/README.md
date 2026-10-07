### PATTERNs

**Sidecar**: no request or response relationship at all, it does not intermediate anyone's call. It just autonomously extends a capability, for example syncing files into a volume. Neither the app nor an external party is calling it.

**Ambassador**: the app inside the Pod is the client. It calls out through the ambassador to reach something external, without knowing the complexity of that external thing.

**Adapter**: something outside the Pod is the client. It calls in expecting a standard interface, and the adapter translates that into whatever native interface the main container actually speaks.