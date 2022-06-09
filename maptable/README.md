# MapTable

Publishing MapTable alongside the other module leads to issues because I'd have to rename both at the same time, even though this module never changes. To address this, I publish this under a different address. The easiest way to do this is to keep a `.aptos` directory right here (it's ignored by git) and run the CLI from in this directory, to publish to the address specified in Move.toml.
