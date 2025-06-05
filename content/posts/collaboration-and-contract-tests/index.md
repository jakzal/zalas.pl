---
title: "Collaboration and contract tests"
date: "2022-08-16T09:31:46Z"
draft: false
tags: ["tdd", "bdd", "testing", "contract tests", "collaboration tests"]
keywords: ["tdd", "bdd", "testing", "contract tests", "collaboration tests"]
cover:
  image: "/collaboration-and-contract-tests/cover.png"
  alt: "Contract and collaboration tests"
  hiddenInSingle: true
summary: A **collaboration test** is an example of interactions between the subject of the test and its collaborators often replaced with test doubles. A **contract test** confirms assumptions made in test doubles.
---

A **collaboration test** is an example of interactions between the subject of the test and its collaborators.
For convenience, speed, reliability, or isolation, collaborators are often replaced with test doubles.

A **contract test** confirms assumptions made in test doubles.
**Contract tests** are examples that describe the behaviour of an abstraction
and express what cannot be encoded in the type system.

----------------------------------

Writing tests for pure functions or methods with no side effects is straightforward.

Given the input, when the behaviour is invoked, let me verify the expected outcome matches the actual outcome.

{{< figure src="pure-function.svg" caption="Pure function" >}}

No matter how many times we invoke the behaviour, the outcome will be the same as long as the input doesn't change.

Behaviours that depend on external services are more challenging. An example of an external service might be any I/O operation, like reading to or writing from a database or a filesystem, or a network call to a REST API.

{{< figure src="function-with-side-effects.svg" caption="Function with side effects" >}}

The external service will make us **split the focus** of the test between two separate concerns - business logic and infrastructure (I/O). Eventually, it will be hard to tell one from the other.

The external service will make our test **less reliable**. Sometimes it will respond slowly. Sometimes it will go down. Sometimes it will fail to respond with the expected outcome.

The external service will make it harder to **reproduce** some scenarios in a test.

Finally, the external service will make our test **slower** than it would be without the external call. With tools available today we're talking about tens or hundreds of ms vs a few ms per test, but it adds up rather quickly. Especially if the service is used in many places.

All of this will not only impede my TDD flow but will also make the build server cause me a lot of pain.

My remedy for the problems above is to separate the business logic from the infrastructure concerns.

## Collaboration tests

We first need to replace the direct I/O operation(s) in the actor with a collaborator that will take over the I/O operation(s).

The collaborator will be bound by a contract. We will test-drive the interactions between the actor and its collaborators in a collaboration test.

{{< figure src="introducing-collaborator.svg" caption="Introducing a collaborator" >}}

The contract will in most cases be an abstraction like an interface or a function type. Something that can have multiple implementations.

Having the contract in place, we will be able to replace the real implementation in a test with a test double (a fake for example).

{{< figure src="providing-a-fake.svg" caption="Providing a fake implementation in a test" >}}

Test doubles make our tests predictable since the behaviour is pre-programmed or simplified. We can explicitly say in the test what should be the outcome of a method call on the test double (stub). We can also verify which methods on the test double were called (mock).

The pre-programmed behaviour also enables us to reproduce any scenario.

Test doubles make our tests fast since it's all pure code with no I/O involved.

Last but not least, test doubles let us focus our tests on collaboration.

## Contract tests

Once we pushed the I/O operation(s) out to the boundaries it's time to write tests to cover interactions with the external service.

Mocking the database or network calls is not something that gives us confidence in integration with an external service. We will need an integration test for that.

A **contract test** is a narrow integration test that confirms assumptions made in test doubles by exercising the external service.

{{< figure src="providing-an-implementation.svg" caption="Providing the real implementation" >}}

In the contract test, we will actually call the external service (as much as it is possible). That means we will perform database queries that will hit the database, or we will make HTTP requests that will hit the REST endpoint.

In collaboration tests, we assumed the contract is implemented as expected. In contract tests, we will verify if that is the case.

{{< figure src="contract-and-collaboration-tests.svg" caption="Contract and collaboration tests" >}}

If a collaboration test relied on a repository to return an entity for a given ID, we will need at least one contract test that verifies the entity is returned from the database.

If a collaboration test relied on the repository to save the entity, there will be at least one contract test to confirm the entity is persisted in the database.

Contract tests will also cover any exceptional and erroneous scenarios. What happens if the connection isn't available? What if the entity isn't found?

Note that the contract isn't limited to the method or function signatures. It also covers rules of the behaviour. For example, given we added something to the repository, we need to be able to take it out.

## Final thoughts

If we choose to test-drive the contract from a client's perspective (the collaboration test), it's more likely it will be a rather simple contract. Otherwise, the collaboration test would be a pain to write and maintain.

A simple contract will also make the implementation and its contract tests rather straightforward and less prone to errors.

By pushing side effects and infrastructure concerns to the boundaries of our system we will greatly limit the number of tests that depend on I/O and require the infrastructure. This is critical to having a fast and reliable test suite.

{{< figure src="contract-vs-collaboration-tests.svg" caption="Contract vs collaboration tests" >}}

## Credits

I've been using this approach for years and I don't recall where I've learned it from. I guess it was a series of lessons over the years. An evolution.

However, I do remember I have learned the vocabulary of collaboration and contract tests from [J. B. Rainsberger](https://www.jbrains.ca/). Their blog is a great TDD resource. The ["Integrated tests are a scam"](https://blog.thecodewhisperer.com/series#integrated-tests-are-a-scam) series is especially worth mentioning in the context of contract and collaboration tests.

<!-- https://excalidraw.com/#json=gZa8rSCMjWXFdVa3kaLpz,prmQ3Ninf2tQbd_Ui0370g -->
