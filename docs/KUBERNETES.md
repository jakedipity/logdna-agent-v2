# LogDNA Agent on Kubernetes

The agent is compatible with Kubernetes versions 1.9 and greater; however, we always recommend running the latest stable version.

## Table of Contents

* [Installing](#installing)
  * [Installation Prerequisites](#installation-prerequisites)
  * [Installation Steps](#installation-steps)
* [Upgrading](#upgrading)
  * [Upgrading the Configuration](#upgrading-the-configuration)
    * [Upgrading from Configuration v1.x.x or v2.0.x](#upgrading-from-configuration-v1xx-or-v20x)
    * [Upgrading from Configuration v2.1.x](#upgrading-from-configuration-v21x)
  * [Upgrading the Image](#upgrading-the-image)
* [Uninstalling](#uninstalling)
* [Run as Non-Root](#run-as-non-root)
* [Collecting Node Journald Logs](#collecting-node-journald-logs)
  * [Enabling Journald on the Node](#enabling-journald-on-the-node)
  * [Enabling Journald Monitoring on the Agent](#enabling-journald-monitoring-on-the-agent)

## Installing

The agent can be effortless installed in your cluster using a set of yamls we provide. These yamls contain the minimum necessary Kubernetes Objects and settings to run the agent. Teams should review and modify these yamls for the specific needs of their clusters.

### Installation Prerequisites

* LogDNA Account - Create an account with LogDNA by following our [quick start guide](https://docs.logdna.com/docs/logdna-quick-start-guide).
* LogDNA Ingestion Key - You can find an ingestion key at the top of [your account's Add a Log Source page](https://app.logdna.com/pages/add-host).
* Kubernetes cluster running at least version 1.9.
* Local clone of this repository.

### Installation Steps

1. Navigate to the root directory of the cloned `logdna-agent` repository.
2. Run the following commands to configure and start the agent:
```console
kubectl apply -f k8s/agent-namespace.yaml
kubectl create secret generic logdna-agent-key -n logdna-agent --from-literal=logdna-agent-key=<YOUR LOGDNA INGESTION KEY>
kubectl apply -f k8s/agent-resources.yaml
```
3. Monitor the pods for startup success:
```console
foo@bar:~$ kubectl get pods -n logdna-agent --watch
NAME                 READY   STATUS    RESTARTS   AGE
logdna-agent-hcvhn   1/1     Running   0          10s
```

> :warning: By default the agent will run as root. To run the agent as a non-root user, check out the [run as non-root section](#run-as-non-root).


## Upgrading

There are two components that can be upgraded independent of each other for each new version of the agent. While not strictly required, we always recommend upgrading both components together.

### Upgrading the Configuration

Not every version update of the agent makes a change to our supplied configuration yamls. These changes will be outlined in our release page to help you determine if you need to update your configuration.

Due to how the agent has evolved over time, certain versions of the agent configuration yamls require different paths to be updated successfully.

If you are unsure of what version of the configuration you have, you can always check the `app.kubernetes.io/version` label of the DaemonSet:

```console
foo@bar:~$ kubectl describe daemonset --all-namespaces -l app.kubernetes.io/name=logdna-agent
Name:           logdna-agent
Selector:       app=logdna-agent
Node-Selector:  <none>
Labels:         app.kubernetes.io/instance=logdna-agent
                app.kubernetes.io/name=logdna-agent
                app.kubernetes.io/version=2.2.0
...
```

Older versions of our configurations do not provide these labels. In that case, each upgrade path belows provides an example of each configuration to be compared to whats running on your cluster.

#### Upgrading from Configuration v1.x.x or v2.0.x

* **Example Configuration Yamls:**
  * [v1.x.x](https://raw.githubusercontent.com/logdna/logdna-agent/master/logdna-agent-ds.yaml)
  * [v2.0.x](https://raw.githubusercontent.com/logdna/logdna-agent/master/logdna-agent-v2.yaml)
* **Differences:** This configuration does not include the new logdna-agent namespace and is lacking a number of new Kubernetes Objects.
* **Upgrade Steps:**
  1. If you have changes you want to persist to the new DaemonSet, backup the old DaemonSet.
     1. Run `kubectl get daemonset -o yaml logdna-agent > old-logdna-agent-daemon-set.yaml`.
     2. Copy any desired changes from `old-logdna-agent-daemon-set.yaml` to the DaemonSet Object in `k8s/agent-resources.yaml`
  2. Remove the old DaemonSet in the default namespace
     1. Run `kubectl delete daemonset logdna-agent`
  3. Install the latest agent by following the [installation steps](#installation-steps)

> :warning: View the warning about backing up the DaemonSet at the bottom of the list of upgrade paths.

#### Upgrading from Configuration v2.1.x

* **Example Configuration Yamls:**
  * [v2.1.x](https://raw.githubusercontent.com/logdna/logdna-agent/master/logdna-agent-v2-beta.yaml)
* **Differences:** This configuration contains the same namespace and Kubernetes Objects. The only differences are some changes to the DaemonSet.
* **Upgrade Steps:**
  1. If you have changes you want to persist to the new DaemonSet, backup the old DaemonSet.
     1. Run `kubectl get daemonset -o yaml -n logdna-agent logdna-agent > old-logdna-agent-daemon-set.yaml`.
     2. Copy any desired changes from `old-logdna-agent-daemon-set.yaml` to the DaemonSet Object in `k8s/agent-resources.yaml`
  2. Apply the latest configuration yaml
     1. Run `kubectl apply -f k8s/agent-resources.yaml`

> :warning: Exporting Kubernetes Objects with "kubectl get \<resource\> -o yaml" includes extra information about the Object's state. This data does not need to be copied over to the new yaml.

### Upgrading the Image

The image contains the actual agent code that is run on the Pods created by the DaemonSet. New versions of the agent always strive to be backwards compatibility with old configuration versions. Any breaking changes will be outlined on our release page. We always recommend upgrading to the latest configuration to get the best feature support for the agent.

The upgrade path for the image depends on which image tag you are using in your DaemonSet.

If your DaemonSet is configured with `logdna/logdna-agent:stable`, our default configuration setting, then you just need to delete the pods to trigger them to recreate and pull down the latest stable version of the logdna-agent image.

```console
kubectl delete pod -n logdna-agent -l app.kubernetes.io/name=logdna-agent
```

Otherwise, if your DaemonSet is configured with a different tag e.g. `logdna/logdna-agent:2.1.7`, you'll need to update the image and tag which will trigger a roll over of all the pods.

```console
kubectl patch daemonset -n logdna-agent logdna-agent --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"logdna/logdna-agent:2.2.0"}]'
```

The specific tag you should use depends on your requirements, we offer a list of tags for varying compatibility:
1. `stable` - Updates with each major, minor, and patch version updates
2. `2` - Updates with each minor and patch version updates under `2.x.x`
3. `2.2` - Updates with each patch version update under `2.2.x`
4. `2.2.0` - Targets a specific version of the agent
5. **Note:** This list isn't exhaustive; for a full list check out the [logdna-agent dockerhub page](https://hub.docker.com/r/logdna/logdna-agent)

## Uninstalling

The default configuration places all of the Kubernetes Objects in a unique namespace. To completely remove all traces of the agent you need to simply delete this namespace:

```console
kubectl delete -f k8s/agent-namespace.yaml
```

If you're sharing the namespace with other applications, you can also remove all traces of the agent by deleting with a label filter. You'll also need to remove the logdna-agent-key secret which doesn't have a label:

```console
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n <NAMESPACE> -l app.kubernetes.io/name=logdna-agent -o name | xargs kubectl delete -n <NAMESPACE>
kubectl delete secret -n <NAMESPACE> logdna-agent-key
```

## Run as Non-Root

By default the agent is configured to run as root. If this behavior is not desired, the DaemonSet can be modified to run the agent as a non-root user.

This is accomplished through Linux Capabilities that makes the agent a "Capability-dumb binary." Specifically, the agent is only allowed global read access with `CAP_DAC_READ_SEARCH`. This capability is already baked into the image and configuration. The only required step is configuring the agent DaemonSet to run as the user and group `5000:5000`.

To update the local configuration file, add two new fields, `runAsUser` and `runAsGroup`, to the `securityContext` section found in the `logdna-agent` container in the `logdna-agent` DaemonSet inside of `k8s/agent-resources.yaml` [`spec.template.spec.containers.0.securityContext`]:

```yaml
securityContext:
  runAsUser: 5000
  runAsGroup: 5000
```

Apply the new updated configuration to your cluster:

```console
kubectl apply -f k8s/agent-resources.yaml
```

Alternatively, to update the DaemonSet configuration directly in your cluster use the following patch command:

```console
kubectl patch daemonset -n logdna-agent logdna-agent --type json -p '[{"op":"add","path":"/spec/template/spec/containers/0/securityContext/runAsUser","value":5000},{"op":"add","path":"/spec/template/spec/containers/0/securityContext/runAsGroup","value":5000}]'
```

## Collecting Node Journald Logs

The agent by default only captures logs generated by the containers running on the Kubernetes clusters container runtime environment. It does not; however, collect system component logs from applications running directly on the node such as the kubelet and container runtime. With some configuration on both the node and the agent, these journald logs can be exposed from the node to the agent.

The agent can access Journald logs from the host node by mounting the logs from `/var/log/journald`. This requires enabling journald log storage in the node as well as configuring the agent to monitor the directory.

### Enabling Journald on the Node

Follow the steps below to ensure journald logs are written to `/var/log/journald`:
1. Gain root access to your node
2. Ensure the `journald.conf`, usually found at `/etc/systemd/`, sets `Storage=persistent`. Look at the [journald.conf documentation](https://www.freedesktop.org/software/systemd/man/journald.conf.html) for more information
3. Create the directory `/var/log/journald`: `mkdir -p /var/log/journald`

### Enabling Journald Monitoring on the Agent

To enable Journald monitoring in the agent, add a new environment variable, `LOGDNA_JOURNALD_PATHS` with a value of `/var/log/journald`, to the logdna-agent DaemonSet:
* If you are updating an already deployed agent:
  1. You can patch the existing agent by running
```console
kubectl patch daemonset -n logdna-agent logdna-agent --type json -p '[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"LOGDNA_JOURNALD_PATHS","value":"/var/log/journald/-"}}]'
```
* If you are modifying a yaml:
  1. Add the new environment variable to the envs section of the DaemonSet Object in `k8s/agent-resources.yaml` [`spec.template.spec.containers.0.env`]
  2. Apply the new configuration file, run `kubectl apply -f k8s/agent-resources.yaml`

 ```yaml
 env:
   - name: LOGDNA_JOURNALD_PATHS
     value: /var/log/journald
 ```