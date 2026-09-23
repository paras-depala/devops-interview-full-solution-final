# Node Web API

This is my solution to the DevOps technical challenge: a Node.js API running as an AWS Lambda
function, with the data stored in an RDS SQL Server database. Everything's built with Terraform
and deployed through GitHub Actions. Note this is not a fully productionised repo but exists as poc.

Requests go: client → API Gateway → Lambda (in private subnets) → RDS SQL Server.

## How the repo is laid out

The repo is split into three folders:

- `app` - the Lambda code, its tests and the RDS certificate bundle
- `infra` - the environment infrastructure (network, db, and the Lambda and API)
- `bootstrap` - the foundational bits for the AWS account, which I apply by hand

## Bootstrap

Bootstrap sets up what the pipeline needs before it can run anything: a versioned S3 bucket for
Terraform state, the GitHub OIDC provider, and two roles that GitHub Actions can assume. That
means there are no AWS keys stored in GitHub.

The deploy role can only be assumed from `main`. It has PowerUserAccess plus some limited IAM
permissions - it can only create roles under the `/node-web-api/` path, only if they have the
permissions boundary attached, and it can only pass them to Lambda. The plan role can only be
assumed from prs and is read-only.

The permissions boundary is the most any role the pipeline creates is allowed to do (write logs,
attach to the VPC and read RDS secrets). It's not what the Lambda actually gets.

Bootstrap's own state lives in the bucket too, under `bootstrap/`. I've denied both roles access
to it so the pipeline can't touch the state that controls its own permissions.

## App

The API is an Express app. `serverless-http` converts API Gateway events into normal HTTP
requests, so the same code runs locally and in Lambda.

There are three routes: `GET /health`, `POST /users` and `GET /users/:id`. Input is validated
and it returns status codes (400 for bad input, 404 if something doesn't exist, 500
for anything unexpected).

The db password comes from Secrets Manager. On the first connection the app creates the
db and table if they aren't there yet. RDS rotates the password every 7 days, so if a
connection fails the app rebuilds its connection pool with the new password and tries again.

## Infra

- `network` - VPC with two private subnets and no internet gateway or NAT. The security
  groups only let the Lambda talk to the db on 1433 and to a Secrets Manager endpoint
  on 443.
- `sql-server` - RDS SQL Server Express on `db.t3.medium`, encrypted and not publicly
  accessible. RDS manages the password in Secrets Manager. Used Express because Standard
  isn't available on `db.t3.medium`.
- `lambda-api` - zips up `app/`, runs it on Node.js 22 in the private subnets and puts an API
  Gateway HTTP API in front of it, throttled to 50 requests a second. The zip only changes when
  the code or dependencies change, so the Lambda only gets redeployed when it needs to.

## Pipeline

On a pr, pipeline runs app tests (against a real SQL Server container), the
Terraform checks (fmt, validate, test and TFLint), a read-only `terraform plan` so you can see
what would change, and a dependency review.

`main` is protected : changes have to go through a pr, and pipeline has to pass before it can be merged.

On a push to `main`, pipeline runs again, then plans, applies and smoke tests the
live API.

Each code change publishes a new Lambda version. API Gateway calls a `live` alias, the
pipeline decides which version it points at: Terraform creates the alias but ignores its version
after that. Before applying, the pipeline records which version is live. If the apply published
a new version, it points `live` at it and runs the smoke test. If the smoke test fails, it points
`live` back at the previous version. Terraform doesn't track the alias's version, a
rollback doesn't cause drift, and a later deploy with no code change won't re-release the broken
version. This only rolls back the Lambda code; infrastructure changes like the db aren't rolled
back automatically.

There's also a manual Destroy workflow - run it from the Actions tab on `main` and type
`destroy` to confirm.

## Setting it up

Bootstrap only needs doing once per AWS account. After that, everything goes through the
pipeline.

### What you need

- An AWS account, with admin credentials set up for the AWS CLI (for example with
  `aws configure`)
- Terraform 1.10 or later (the pipeline uses 1.14.9)
- AWS CLI v2
- GitHub CLI, logged in with `gh auth login`
- A GitHub repo with this code in it, cloned locally
- On Windows, Git Bash. All the commands below are bash. Don't just type `bash` in PowerShell,
  as that can open WSL, which won't have your AWS credentials.

### 1. Check you're pointing at the right AWS account

```bash
aws sts get-caller-identity
```

The `Account` it shows is where everything will be created.

### 2. Get your repository ID

The deploy and plan roles only trust your repo, identified the way GitHub writes it into its
OIDC token (swap in your own `OWNER/NAME`):

```bash
gh api repos/OWNER/NAME --jq '"\(.owner.login)@\(.owner.id)/\(.name)@\(.id)"'
```

You'll get something like
`paras-depala@118982653/devops-interview-full-solution-final@1383726763`. Use that wherever it
says `<repo id>` below.

### 3. Check for an existing GitHub OIDC provider

An AWS account can only have one GitHub OIDC provider:

```bash
aws iam list-open-id-connect-providers
```

If the list has one ending in `token.actions.githubusercontent.com`, you'll import it in step 5.
If it's empty, you can skip step 5.

### 4. Initialise with local state

The state bucket doesn't exist yet, so the first run has to use local state. Delete `backend.tf`
for now; the script in step 7 puts it back exactly as it was.

```bash
cd bootstrap
rm backend.tf
terraform init
```

### 5. Import the existing OIDC provider (only if step 3 found one)

Swap in your AWS account ID from step 1:

```bash
terraform import -var "github_repository=<repo id>" aws_iam_openid_connect_provider.github arn:aws:iam::<account id>:oidc-provider/token.actions.githubusercontent.com
```

### 6. Apply bootstrap

```bash
terraform apply -var "github_repository=<repo id>"
```

Check the plan. Everything goes in eu-west-2 by default; add `-var "aws_region=<region>"`
to use a different region.

### 7. Move bootstrap's state into S3

I have included this script just in case you try to set this up in a different repo as both the bootstrap and infra are linked.

```bash
bash move-state-to-s3.sh
```

The script:

- reads the bucket name and region from the bootstrap outputs
- checks the bucket exists, and stops if there's already state in it for bootstrap
- writes `backend.tf` back and copies the state to `bootstrap/terraform.tfstate` in the bucket
- checks the copy in S3 has the same number of resources as the local one
- keeps the old local state as `terraform.tfstate.before-s3`, which you can delete once you're
  happy

### 8. Add the repository variables

Still in the `bootstrap` folder, inside your clone of the repo:

```bash
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw aws_role_arn)"
gh variable set AWS_PLAN_ROLE_ARN --body "$(terraform output -raw aws_plan_role_arn)"
gh variable set AWS_REGION --body "$(terraform output -raw aws_region)"
gh variable set TF_STATE_BUCKET --body "$(terraform output -raw tf_state_bucket)"
gh variable list
```

These are variables, not secrets, as none of them are sensitive. You can also add them by hand
under Settings → Secrets and variables → Actions → Variables.

### 9. Deploy

Push to `main`, or run the CI/CD workflow from the Actions tab. The first deploy takes around
30 minutes, mostly waiting for the db. The smoke test at the end calls the live API, so if
it passes, everything's working.

### Working on bootstrap later

Bootstrap's state is in S3 from step 7 onwards, so on any other machine, initialise it with:

```bash
terraform init -backend-config="bucket=<tf_state_bucket>" -backend-config="region=<aws_region>"
```

## Running the tests locally

```bash
cd app
npm ci
npm test
```

The SQL Server tests get skipped unless `DB_HOST`, `DB_USER`, `DB_PASSWORD` and
`DB_TRUST_SERVER_CERTIFICATE=true` point at a SQL Server. The easiest way is to run one in
Docker.

## A few notes

- I haven't used Terraform workspaces as there's only one environment. If I added more, each
  would get its own state and ideally its own AWS account.

These were fine for the challenge, but I'd change them for production:

- The app connects as the RDS master user. I would normally give it its own login that can only read and write the `Users`
  table.
- Normally I'd add an API Gateway authorizer, e.g. JWT with Cognito in front to add some form of auth.
- The database is Single-AZ, so if its availability zone goes down, so does the database.
  Multi-AZ needs Standard edition, which isn't available on `db.t3.medium` - specified version in coding test brief.
- Logs go to CloudWatch but nobody gets alerted. I'd add CloudWatch alarms
  for Lambda errors and database health, sent to an SNS topic.
- The smoke test leaves a "Smoke Test" user in the database on every deploy. They can be cleaned up post smoke test but it's a poc
