Kyverno policies
=

We use [Kyverno](https://kyverno.io/) to enforce policies in the cluster.
Kyverno is a policy engine for Kubernetes.
It allows you to write policies to enforce custom rules for your Kubernetes resources.

Kyverno policies are have not trivial structure and can be complex.
We recommend you to use the [Kyverno Playground](https://playground.kyverno.io/#/) to develop Kyverno policies.

Elso to check the Kyverno policies, you can use the [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/).

The CLI allows you to check the policies in the cluster, get the policy details, and test the policies.

We wrote several tests for our Kyverno policies. You can find the tests in the `tests` directory.

To launch the tests, you need to run the following command in this directory:

```bash
kyverno test tests/ -v=9 --detailed-results
```

The command will run the tests for all policies in the `tests` directory and show the detailed results.
More information about the command `kyverno test` you can find in
the [official documentation](https://kyverno.io/docs/kyverno-cli/usage/test/).
