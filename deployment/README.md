# Deployment

This repo provide a Pulumi program to configure the necessary pieces for deploying the web UI. I just use GCP for now.

## Setting up

First, follow the steps here to get the necessary tooling set up: https://www.pulumi.com/docs/get-started/gcp/begin/. Below is a summary of those steps.

Make a project in GCP. In this example, it's called `personaltest`.

Set up tooling:
```
brew install pulumi/tap/pulumi
brew install google-cloud-sdk

# Login with the Pulumi CLI.
# For this personal project I'm just using the Pulumi service.
pulumi login

# Login with the gcloud CLI.
gcloud init
gcloud auth application-default login
```

## Setting configuration / secrets
You'll want to set up your config values something like this:
```
$ pulumi config
KEY                    VALUE
gcp:project            aclip-352104
gcp:region             us-west3
```

You can do that with commands like these:
```
pulumi config set gcp:region us-west1
pulumi config set account_private_key --secret 0x342423432432babaffabababff
```

You need to do this locally and commit the stack file before the CI will work. In short, when CI runs, it runs `pulumi up` in each of these projects. This first logs in to the Pulumi service, where the secrets are held.
