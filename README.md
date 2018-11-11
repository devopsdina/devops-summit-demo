# devops-summit-demo

The contents of this repo represent one of many ways someone or a team may start down a path of automation using the following tools:

- Visual Studio Code
- AzureRM (or Az) cmdlets
- PowerShell
- Azure Resource Manager

Please note that teams should always keep security in mind when developing.  These scripts are meant to examples, not necessarily best
practices.

All scripts in this repo are idempotent.

## Level 0

**The brute force attack**
This minimalist automation approach uses imperative coding to get the job done.

While the script in the repo is idempotent, it may not necessarily produce the results one might expect when discussing
idempotency.

We also do not see the deployment indicator from the Azure portal using this method.

One example of this would be trying to update a value on an already existing resource.  This script will just check to
see if the resource exists and if it does, it will skip the step to create it all together.

### How to run

- From your Administrative PowerShell session, go to the directory where the deploy.ps1 is located and run:
  `.\deploy.ps1 -DeploymentName 'CloudExpo0' -Subscription 'my azure subID'`

## Level 1

**Declarative coding**
Iteration 1 may be to move the resources from level 0 into an ARM template for a declarative deployment.  However, level 0 and
level 1 are *very similar* regarding the maturity level, there are trade offs between the two.  Level 0 you don't have to hardcode values, but
the deployment itself is imperative.  Level 1, the deployment is declarative but you must hard code values.

An example can be found in level 1, as we are forced to give the resourceID of the keyvault and the name of the secret
we want to use in our deployment in order to pass the value in the keyvault as a secure string.  This means the keyvault and
the secret must be in place ahead of your deployment.  Thinking about that on a large scale with many differently name key vaults
in many different resource groups and subscriptions....who wants to update a parameters file manually each deployment??

This follows many examples of azure deployments seen across the internet with an azuredeploy.json and
a parameters file.

We may run into trouble here when our system becomes more complex, for example there is not an easy way to pass
a dynamic value into the parameters.json file (or any json file).  So once you start deploying more dynamic systems
you may want to move to an approach similar to level 2

### How to run

- From your Administrative PowerShell session, go to the directory where the deploy.ps1 is located and run:
  `.\deploy.ps1 -DeploymentName 'CloudExpo1' -Subscription 'my azure subID'`

## Level 2

**Coding Puberty**
Iteration 2 - the maturity phase will start to begin.  One may start to see many issues with the prior two approaches like
being able to dynamically set passwords in a key vault or copying the same code from one script to another

Start to think about how to make a system that is loosely coupled.  For example, instead of copying powershell code
into a bunch of different places, I can publish a module.  This module at first can even be dot sourced locally to help organize
the code base before publishing at a company level.

Another item to think about is naming conventions and how to dynamically build those objects in your deployment scripts.  Notice
I am referencing objects here, this gives us the flexibility to pass dynamically generated values into an ARM template instead of
using a parameters file.

### How to run

- From your Administrative PowerShell session, go to the directory where the deploy.ps1 is located and run:
  `.\deploy.ps1 -DeploymentName 'CloudExpo2' -Subscription 'my azure subID'`

## Level N

Have fun :)

## Considerations

- Deployments should be able to run from developers machines and a CI/CD process.  
  An example would be, kicking off a deploy.ps1 from the command line and the CI also kicking off that deploy.ps1 when a change is committed.  
  Devs and CI/CD systems will likely need parameters configured to support this behavior.

- Don't hardcode passwords, use environment variables

- Write tests!!
