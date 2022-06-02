# aclip

This project is made up of two major components:
- `frontend`: This is the frontend for the project, made with Flutter. todo
- `move`: This is where the core logic lives, on the [Aptos Blockchain](https://aptoslabs.com). todo

In addition to the core feature components, there is also code for deploying the project under `deployment` and `.github`.

Each of these components has their own README explaining how to develop and deploy them.

## Setting up this repo
When first pulling this repo, add this to `.git/hooks/pre-commit` and make it executable:
```
#!/bin/bash

cd frontend 
./bump_version.sh
git add pubspec.yaml
```