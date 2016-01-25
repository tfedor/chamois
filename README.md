Chamois is a simple deployment tool.

Chamois let's you define multiple deployment stages (e.g. dev and production), which consist of one or more targets. Each target can have assigned specific rules for which files to deploy. That is useful if you are running multiple servers with different setup and different goal, for example your API server probably does not need all front end code, or your frontend server to have all scripts that are run by cron.

This way the deployment should be faster and safer.

Installation

Example

License