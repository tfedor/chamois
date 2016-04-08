# Chamois

Chamois is a simple multi-stage, multi-target deployment tool.

Chamois let's you deploy your code to multiple environments defined by stages (e.g. dev, production). Each stage consists of one or more targets, which may further specify rules for uploading files.

## Development

I plan to use Chamois on personal projects and further change it as I see fit, so whole interface and logic may change (but probably won't).

The ability to patch current release, instead of pushing whole code each time will be neccessary feature.

## Installation

```
rake install
```

## Deployment, release, rollback

Whole deployment is separated into two steps: deployment as uploading files and release as setting up last uploaded release as a current one. This allows you to first deploy all your code and check it, make neccessary updates that can't be done via Chamois or just delay release itself.

Command line interface is as follows:

```
chamois deploy STAGE
chamois release STAGE
chamois rollback STAGE
```

And you can also use shorter version of each command:

```
cham dp STAGE
cham rl STAGE
cham rb STAGE
```

## Setup

Chamois uses two yaml files to set up your deployment, one of which is optional. In your project's root create folder `_deploy`. Here you'll put your `stages.yaml` and `rules.yaml` file.

You can run ```chamois init``` or ```cham init``` to run initial setup.

### Stages

Stages define where to upload your files.

`stages.yaml` example:

```
develop:                    # name of stage
  dev:                      # name of target
    host: dev.example.com   # server host
    port: 22                # server port
    user: chamois           # server user
    root: /data/dev/        # where to deploy on the server

prod:                       # prod stage setup
  api:                      # api target definition
    host: example.com
    port: 22
    user: chamois
    root: /data/api/
    rules:                  # list of rulesets that apply for this target
      - api

  prod:                     # target may have same name as stage
    host: example.com
    port: 22
    user: chamois
    root: data/www/
    rules: 
      - prod
      - front
```

In the example you can see that I have set up two stages. Since develop:dev target is missing rules definition, all files will be deployed.

The prod stage consists of two targets, which deploy to different folders on the same server.

Notice that I have not specified password. Chamois currently works only with keys, I have tested it only on Windows with pageant.

### Rules

Rules control which files will be uploaded to different targets. You can use 3 types of rules: `exclude`, `include`, `rename`.

> `exclude` and `include` rules are lists, `rename` is a map

You can use `*` and `/` wildcards. They will be translated to following regexps: `.*`, `(^|/)` respectively.

`rules.yaml` example

```
common:
  exclude:
    - "/."

prod:
  exclude:
    - _deploy/
    - "*.sql"

  rename:
    "config.prod.php": "config.prod"

front:
  exclude:
    - api/
    - cron/

api:
  include:
    - api/
    - classes/

```
