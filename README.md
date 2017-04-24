# One micro-service, multiple deployment options

This project contains one simple micro-service that gets deployed:
* as a Cloud Foundry application,
* as a container in a Kubernetes cluster,
* and as an OpenWhisk action.

  <img src="architecture.png" width="600" />

## Requirements

* IBM Bluemix account. [Sign up][bluemix_signup_url] for Bluemix, or use an existing account.
* [Bluemix CLI](http://clis.ng.bluemix.net/)
* [OpenWhisk CLI](https://console.ng.bluemix.net/openwhisk/learn/cli)
* [Bluemix Container Registry plugin](https://console.ng.bluemix.net/docs/cli/plugins/registry/index.html)
* [Bluemix Container Service plugin](https://console.ng.bluemix.net/docs/containers/cs_cli_devtools.html)
* Node.js 6.9.1
* Kubernetes CLI version 1.5.3 or later
* Docker CLI version 1.9. or later

## About the micro-service

The micro-service used in this project computes Fibonacci numbers.

From [Wikipedia](https://en.wikipedia.org/wiki/Fibonacci_number), *In mathematics, the Fibonacci numbers are the numbers in the following integer sequence, called the Fibonacci sequence, and characterized by the fact that every number after the first two is the sum of the two preceding ones:*

  ```
  0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, ...
  ```

The implementation of the Fibonacci sequence is done in **[service/lib/fibonacci.js](service/lib/fibonacci.js)**. The same implementation is used across all deployment options.

## Deploying the service automatically in Bluemix

The toolchain is setup to automatically deploy the service to Cloud Foundry and OpenWhisk.

**Deploying to Kubernetes requires a few manual steps.**
1. Assuming that latest version of the Bluemix CLI is installed and configured to run Kubectl commands. [Click for instructions on installing and configuring the CLI to run Kubectl commands](https://console.ng.bluemix.net/docs/containers/cs_cli_install.html#cs_cli_install)
1. Verify that you have the *container-registry* and the *container-service* plugins installed by using  `bluemix plugin list`   
    
1. Create a Kubernetes cluster in Bluemix
   ```
   bx cs cluster-create --name fibonacci-cluster
   ```
    > Note: It takes approximately 15 minutes for the cluster to be fully provisioned and ready to accept the sample pods.   
    > You can also use an existing cluster if you have one already.

1. Use `bx cs clusters` to view defined clusters  
1. Use `bx cs workers fibonacci-cluster` to view provisioned workers.
   > Note: The state of your cluster should be in a **Ready** state.

TODO - add steps to build and push the docker image...

-----


1. Ensure your organization has enough quota for one web application using 256MB of memory, one Kubernetes cluster, and one OpenWhisk action.

1. Click ***Create toolchain*** to start the Bluemix DevOps wizard:

   [![Deploy To Bluemix](https://console.ng.bluemix.net/devops/graphics/create_toolchain_button.png)](https://console.ng.bluemix.net/devops/setup/deploy/?repository=https://github.com/IBM-Bluemix/multiple-deployment-options&branch=dev)

1. Select the **GitHub** box.

1. Decide whether you want to clone or fork the repository.

1. If you decide to Clone, set a name for your GitHub repository.

1. Select the **Delivery Pipeline** box.

1. Select the region, organization and space where you want to deploy the web application.

   :warning: Make sure the organization and the space have no space in their names.

   :warning: Only the US South region is currently supported.

1. Set the name of the Cloud Foundry application. You can keep the default. A random route will be created for the application.

1. Optionally set the Bluemix API key. If you don't set the key, the Kubernetes service will NOT be deployed and you will need to use the manual instructions.

   > Obtain a Bluemix API key using `bx iam api-key-create for-toolchain`

1. Optionally set the name of an existing Kubernetes cluster to use.  

1. Add your docker image namespace. 
   > Obtain the docker image namespace using `bx cr namespace-list`

1. Click **Create**.

1. Select the Delivery Pipeline.

1. Wait for the DEPLOY stage to complete.

1. The services are ready. Review the [Service API](#Service_API) to call the services.

## Deploying the service manually in Bluemix

Follow [these instructions](./DEPLOY_MANUALLY.md).

## Service API

Once deployed, the service implements 3 API calls:
  * compute the Fibonacci number after *n* iterations,
  * let the computation run for *t* milliseconds,
  * and simulate a crash of the service.

Depending on which compute option you are using, use the following cURL calls:

| Endpoint Type | Endpoint  | URL |
| ---           |   ---     | --- |
| Cloud Foundry | iteration | `curl -v http://fibonacci-service-<random-string>.mybluemix.net/fibonacci?iteration=1000` |
|               | duration  | `curl -v http://fibonacci-service-<random-string>.mybluemix.net/fibonacci?duration=5000` |
|               | crash     | `curl -v -X POST http://fibonacci-service-<random-string>.mybluemix.net/fibonacci?crash=true` |
| Kubernetes    | iteration | `curl -v http://<cluster-ip>:30080/fibonacci?iteration=1000` |
|               | duration  | `curl -v http://<cluster-ip>:30080/fibonacci?duration=5000` |
|               | crash     | `curl -v -X POST http://<cluster-ip>:30080/fibonacci?crash=true` |
| OpenWhisk     | iteration | `curl -v https://openwhisk.ng.bluemix.net/api/v1/web/<namespace>/default/fibonacci?iteration=1000` |
|               | duration  | `curl -v https://openwhisk.ng.bluemix.net/api/v1/web/<namespace>/default/fibonacci?duration=5000` |
|               | crash     | `curl -v -X POST https://openwhisk.ng.bluemix.net/api/v1/web/<namespace>/default/fibonacci?crash=true` |

## Code Structure

### Cloud Foundry application

| File | Description |
| ---- | ----------- |
| [app.js](service/app.js) | Main application, start the express web server and expose the service API|
| [lib/fibonacci.js](service/lib/fibonacci.js) | The implementation of the Fibonacci sequence, shared by all deployment options|
| [package.json](service/package.json) | List the packages required by the application |
| [manifest.yml](service/manifest.yml) | Description of the application to be deployed |
| [.cfignore](service/.cfignore) | List files to ignore when deploying the application to Cloud Foundry |

### Kubernetes deployment

| File | Description |
| ---- | ----------- |
| [app.js](service/app.js) | Main application, start the express web server and expose the service API|
| [lib/fibonacci.js](service/lib/fibonacci.js) | The implementation of the Fibonacci sequence, shared by all deployment options|
| [package.json](service/package.json) | List the packages required by the application |
| [Dockerfile](service/Dockerfile) | Description of the Docker image |
| [fibonacci-deployment.yml](service/fibonacci-deployment.yml) | Specification file for the deployment of the service in Kubernetes |

### OpenWhisk action

The OpenWhisk action is deployed as a [zip action](https://console.ng.bluemix.net/docs/openwhisk/openwhisk_actions.html#openwhisk_create_action_js) where several files are packaged into a zip file and the zip file is passed to OpenWhisk as the implementation for the action. **[deploy.js](service/deploy.js)** takes care of packaging the zip file.

| File | Description |
| ---- | ----------- |
| [handler.js](service/action/handler.js) | Implementation of the OpenWhisk action |
| [lib/fibonacci.js](service/lib/fibonacci.js) | The implementation of the Fibonacci sequence, shared by all deployment options |
| [package.json](service/action/package.json) | Specify the action entry point (handler.js) |
| [deploy.js](service/deploy.js) | Helper to deploy and undeploy the OpenWhisk action |

### Tester web app

Under the `tester` directory is a simple web application to register and test the deployed micro-services. It can be pushed to Bluemix with `cf push` or simply executed locally with `python -m SimpleHTTPServer 28080` as example.

## Contribute

Please create a pull request with your desired changes.

## Troubleshooting

### Cloud Foundry

  Use
  ```
  cf logs fibonacci-service
  ```
  to look at the live logs for the web application.

### Kubernetes

  Use
  ```
  kubectl proxy
  ```
  and look at the status of the resources in the console.

### OpenWhisk

  Use
  ```
  wsk activation poll
  ```
  and perform an invocation of the action.

## License

See [License.txt](License.txt) for license information.

[bluemix_signup_url]: https://console.ng.bluemix.net/?cm_mmc=GitHubReadMe
