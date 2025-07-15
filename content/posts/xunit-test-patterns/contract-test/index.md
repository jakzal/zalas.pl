---
title: "Contract Test"
date: "2025-07-15T09:45:47Z"
draft: true
tags: ["test patterns", "contract tests", testing, xunit, kotlin]
keywords: ["test patterns", "contract tests", testing, xunit, junit, kotlin, "ports and adapters", hexagonal]
cover:
  image: "contract-tests-cover.png"
  alt: "Contract Tests"
  hiddenInSingle: true
summary: Contract Tests are examples that describe the behaviour of an abstraction by expressing what cannot be encoded in the type system. These are typically helpful in testing adapters as defined in the Ports & Adapters architecture.
---

This is a definition of the Contract Test pattern in a format inspired by
[xUnit Test Patterns: Refactoring Test Code](https://learning.oreilly.com/library/view/xunit-test-patterns/9780131495050/).

---

Name: Contract Test

Also known as:

*Tests for an Interface, Role Test, Testcase Superclass, Abstract Testcase, Abstract Test Fixture, Testcase Baseclass*.

*How to describe the behaviour of an abstraction that cannot be encoded in the type system?*

**Derive tests from a partially-abstract module, while providing the implementation-specific details.**

{{< figure src="contract-tests-pattern-diagram-inheritance.svg" caption="Contract Test Pattern (Inheritance Variant)" >}}

An external system is any system that the team cannot change, like a service maintained by another team, or a third-party library or a product.
Since external systems are out of the team's control, those are often hidden behind the team's own abstraction.
The new abstraction almost always narrows the Contract made with the external system.
While the abstraction describes the contract made with an external system, it's also not complete, as not all behaviour can be described in a type system.

Contract tests are examples that describe the behaviour of an abstraction by expressing what cannot be encoded in the type system.

The Contract Test pattern was first called an [Abstract Testcase](https://wiki.c2.com/?AbstractTestCases),
or the [Testcase Superclass](http://xunitpatterns.com/Testcase%20Superclass.html).
What makes the Contract Test different from the Testcase Superclass pattern is a more specific intent.
The goal of Testcase Superclass is to reuse test utility methods, while Contract Tests specifically describe a Contract to be implemented.

Contract Tests are typically helpful in testing adapters as defined in the Ports & Adapters architecture (a.k.a. Hexagonal architecture),
but are not limited to them.

In Collaboration Tests, the Contract is implemented with test doubles. Contract Tests complement Collaboration Tests
by verifying test doubles implement behaviours that are in fact possible.

The [Testcase Superclass](http://xunitpatterns.com/Testcase%20Superclass.html) is not the only way to implement the Contract Test.
Composition can be used as well to embed [parametrised](http://xunitpatterns.com/Parameterized%20Test.html) Contract Tests into a new test case.

{{< figure src="contract-tests-pattern-diagram-composition.svg" caption="Contract Test Pattern (Composition Variant)" >}}


## How It Works

A Contract Test is defined as a partially-abstract module. It holds tests that describe the contract,
and it defers implementation details that can only be provided by a particular implementation of the module.

The contract can be defined as an interface, an abstract class, or it could be implicit in dynamically typed languages with no such concepts.

The abstract Contract Test module is then used to implement tests for a concrete implementation of the contract.
Implementation details that were deferred by the Contract Test module need to be provided by the implementor.

The most common implementation detail that needs to be provided is the creation method for [SUT](http://xunitpatterns.com/SUT.html) (System Under Test).
The SUT needs to be made available to the abstract Contract Test module for the tests to exercise it. It can be done in a number of ways, including the test case constructor, an abstract creation method that is overridden in the concrete test case or passed to the [parametrised test](http://xunitpatterns.com/Parameterized%20Test.html).

Contract Tests tend to be used in combination with the [Test Utility Method](http://xunitpatterns.com/Test%20Utility%20Method.html)
or [Test Helper Method](http://xunitpatterns.com/Test%20Helper.html) in order to setup fixtures, create the SUT, exercise the SUT,
provide finder methods, or custom assertion and verification methods.

## When to Use It

Contract Tests are used as integration micro-tests for an external system, abstracted behind the team's own interface.
An external system is anything written by other people.

Contract Tests can also be used to prove alternative implementations of the same interface are equivalent and substitutable.

There's a number of variations of the pattern, each offering varying degrees of convenience or familiarity,
depending on the programming language and the xUnit implementation.

### Variation: Abstract Testcase

Testcase Superclass, or Abstract Testcase, is the most convenient way to implement Contract Tests in xUnit flavours
that promote inheritance to reuse tests or test utility methods.

### Variation: Parametrised Contract Test

Contract Tests can be implemented without inheritance by leveraging composition and the
[parametrised test](http://xunitpatterns.com/Parameterized%20Test.html) pattern.
It's a good way to avoid the single-inheritance constraint.

### Variation: Contract Test Trait

Contract Tests can be defined as traits or mixins in languages that support them.
That may be a good alternative to avoid the single-inheritance constraint.

## Implementation Notes

Any variation of the pattern usually starts with tests for the concrete implementation of the contract.
Implementation-specific operations, like creating the SUT, can then be extracted to methods with intention revealing names.
These methods will later be made abstract.
Concrete test implementations need to derive the tests from the Contract Test module and provide the abstracted implementation-specific operations.

## Motivating Example

The following tests are an example of an integration test for a database repository.
The database is started before all the tests are run, and the database schema is freshly re-created before each test.
Each test follows a consistent pattern of setting up the database state, creating the repository (SUT), invoking it, and verifying the outcome.

```kotlin
@Testcontainers(disabledWithoutDocker = true)
class ExposedTradeOrderRepositoryTests {

    companion object {
        @Container
        private val postgresql = PostgreSQLContainer(DockerImageName.parse("postgres:17-alpine"))
    }

    @BeforeTest
    fun createSchema(): Unit = transaction(postgresql.connection) {
        addLogger(StdOutSqlLogger)
        SchemaUtils.drop(TradeOrders)
        SchemaUtils.create(TradeOrders)
    }

    @Test
    fun `returns the TradeOrder if it exists for the given tracking ID`() {
        val matching = tradeOrder(trackingId = TrackingId("t456"))

        val existingTradeOrders = listOf(
            tradeOrder(trackingId = trackingIdOtherThan("t456")),
            matching,
            tradeOrder(trackingId = trackingIdOtherThan("t456"))
        )
        transaction(postgresql.connection) {
            addLogger(StdOutSqlLogger)
            TradeOrders.batchInsert(existingTradeOrders) {
                this[TradeOrders.trackingId] = it.trackingId.value
                this[TradeOrders.brokerageAccountId] = it.brokerageAccountId.value
                this[TradeOrders.type] = it.type
                this[TradeOrders.security] = it.security.value
                this[TradeOrders.numberOfShares] = it.numberOfShares
                this[TradeOrders.status] = it.status
            }
        }

        val repository = ExposedTradeOrderRepository(postgresql.connection)

        val found = repository.forTrackingId(TrackingId("t456"))

        assertEquals(matching, found)
    }

    @Test
    fun `returns null if the TradeOrder is not found for the given tracking ID`() {
        // ...
    }

    @Test
    fun `returns an empty list if no TradeOrder was found for the given account ID`() {
        // ...
    }

    @Test
    fun `returns all outstanding TradeOrders for the given account ID`() {
        // ...
    }
}
```

The test is not a contract test as it's littered with implementation details of the chosen persistence mechanism.
Only one test is shown, but there would be a certain degree of duplication between the tests,
in the setup code in particular where data is persisted before the SUT is invoked.

## Refactoring Notes

Implementation-specific details need to be first separated from implementation-agnostic ones.
Specifically, tests need to be made unaware of the implementation to become Contract Tests.
The opportunity can be taken to make the tests more expressive as well.

Test Utility Methods with intention revealing names should be extracted to move implementation-specific details out from the tests.

```kotlin
@Testcontainers(disabledWithoutDocker = true)
class ExposedTradeOrderRepositoryTests {

    companion object {
        @Container
        private val postgresql = PostgreSQLContainer(DockerImageName.parse("postgres:17-alpine"))
    }

    @BeforeTest
    fun createSchema(): Unit = transaction(postgresql.connection) {
        addLogger(StdOutSqlLogger)
        SchemaUtils.drop(TradeOrders)
        SchemaUtils.create(TradeOrders)
    }

    @Test
    fun `returns the TradeOrder if it exists for the given tracking ID`() {
        val matching = tradeOrder(trackingId = TrackingId("t456"))

        val repository = tradeOrderRepositoryWith(
            tradeOrders = listOf(
                tradeOrder(trackingId = trackingIdOtherThan("t456")),
                matching,
                tradeOrder(trackingId = trackingIdOtherThan("t456"))
            )
        )

        val found = repository.forTrackingId(TrackingId("t456"))

        assertEquals(matching, found)
    }

    @Test
    fun `returns null if the TradeOrder is not found for the given tracking ID`() {
        // ...
    }

    @Test
    fun `returns an empty list if no TradeOrder was found for the given account ID`() {

        // ...
    }

    @Test
    fun `returns all outstanding TradeOrders for the given account ID`() {
        // ...
    }

    private fun tradeOrderRepositoryWith(tradeOrders: List<TradeOrder>): TradeOrderRepository {
        transaction(postgresql.connection) {
            addLogger(StdOutSqlLogger)
            TradeOrders.batchInsert(tradeOrders) {
                this[TradeOrders.trackingId] = it.trackingId.value
                this[TradeOrders.brokerageAccountId] = it.brokerageAccountId.value
                this[TradeOrders.type] = it.type
                this[TradeOrders.security] = it.security.value
                this[TradeOrders.numberOfShares] = it.numberOfShares
                this[TradeOrders.status] = it.status
            }
        }
        return ExposedTradeOrderRepository(postgresql.connection)
    }
}
```

What happens next depends on the chosen variation of the pattern.

Tests need to be moved to a new class so that it could be used by the concrete test case that implements the Contract Test.

In case of inheritance, tests will be pulled up to the Contract Test superclass together with abstract Test Utility Methods.

In case of composition, tests will be extracted to a new class depending on a Test Helper interface for abstracted implementation-specific operations.

In any case, Test Utility Methods that are implementation-agnostic can be kept with the tests.

## Example: Contract Test as an Abstract Testcase

The tests and abstract test utility methods are pulled up to the Contract Test. The move leaves the tests implementation agnostic.

```kotlin
abstract class TradeOrderRepositoryContract {
    @Test
    fun `returns the TradeOrder if it exists for the given tracking ID`() {
        val matching = tradeOrder(trackingId = TrackingId("t456"))

        val repository = tradeOrderRepositoryWith(
            tradeOrders = listOf(
                tradeOrder(trackingId = trackingIdOtherThan("t456")),
                matching,
                tradeOrder(trackingId = trackingIdOtherThan("t456"))
            )
        )

        val found = repository.forTrackingId(TrackingId("t456"))

        assertEquals(matching, found)
    }

    @Test
    fun `returns null if the TradeOrder is not found for the given tracking ID`() {
        // ...
    }

    @Test
    fun `returns an empty list if no TradeOrder was found for the given account ID`() {
        // ...
    }

    @Test
    fun `returns all outstanding TradeOrders for the given account ID`() {
        // ...
    }

    protected abstract fun tradeOrderRepositoryWith(tradeOrders: List<TradeOrder>): TradeOrderRepository
}
```

Tests for specific implementations of the Contract need to extend the Contract Test, and provide implementations for any abstract test utility methods.
It may happen that additional test hooks need to be provided to setup the environment for tests.
These remain in the concrete implementation of the tests and the Contract Test should be unaware of them.

```kotlin
@Testcontainers(disabledWithoutDocker = true)
class ExposedTradeOrderRepositoryTests : TradeOrderRepositoryContract() {

    companion object {
        @Container
        private val postgresql = PostgreSQLContainer(DockerImageName.parse("postgres:17-alpine"))
    }

    @BeforeTest
    fun createSchema(): Unit = transaction(postgresql.connection) {
        addLogger(StdOutSqlLogger)
        SchemaUtils.drop(TradeOrders)
        SchemaUtils.create(TradeOrders)
    }

    override fun tradeOrderRepositoryWith(tradeOrders: List<TradeOrder>): TradeOrderRepository {
        persistTradeOrders(tradeOrders)
        return ExposedTradeOrderRepository(postgresql.connection)
    }

    private fun persistTradeOrders(tradeOrders: List<TradeOrder>) = transaction(postgresql.connection) {
        addLogger(StdOutSqlLogger)
        TradeOrders.batchInsert(tradeOrders) {
            this[TradeOrders.trackingId] = it.trackingId.value
            this[TradeOrders.brokerageAccountId] = it.brokerageAccountId.value
            this[TradeOrders.type] = it.type
            this[TradeOrders.security] = it.security.value
            this[TradeOrders.numberOfShares] = it.numberOfShares
            this[TradeOrders.status] = it.status
        }
    }
}
```

Additional implementations can now be provided and conform to the Contract by passing the same Contract Tests.

```kotlin
class InMemoryTradeOrderRepositoryTests : TradeOrderRepositoryContract() {
    override fun tradeOrderRepositoryWith(tradeOrders: List<TradeOrder>) 
        = InMemoryTradeOrderRepository(tradeOrders)
}
```

## Example: Contract Test as a Parametrised Test

The tests are parametrised with a Test Helper and moved to a new Contract Test class.
The Test Helper could be an interface, or in languages that support it, a function type.
All tests are listed in the `allTests` method as dynamic tests, so that implementors could easily derive them.

```kotlin
class TradeOrderRepositoryContract {

    fun `returns the TradeOrder if it exists for the given tracking ID`(
        tradeOrderRepositoryWith: (List<TradeOrder>) -> TradeOrderRepository
    ) {
        val matching = tradeOrder(trackingId = TrackingId("t456"))

        val repository = tradeOrderRepositoryWith(
            listOf(
                tradeOrder(trackingId = trackingIdOtherThan("t456")),
                matching,
                tradeOrder(trackingId = trackingIdOtherThan("t456"))
            )
        )

        val found = repository.forTrackingId(TrackingId("t456"))

        assertEquals(matching, found)
    }

    fun `returns null if the TradeOrder is not found for the given tracking ID`(
        tradeOrderRepositoryWith: (List<TradeOrder>) -> TradeOrderRepository
    ) {
        // ...
    }

    fun `returns an empty list if no TradeOrder was found for the given account ID`(
        tradeOrderRepositoryWith: (List<TradeOrder>) -> TradeOrderRepository
    ) {
        // ...
    }

    fun `returns all outstanding TradeOrders for the given account ID`(
        tradeOrderRepositoryWith: (List<TradeOrder>) -> TradeOrderRepository
    ) {
        // ...
    }

    fun allTests(
        tradeOrderRepositoryWith: (List<TradeOrder>) -> TradeOrderRepository
    ): List<DynamicTest> = listOf(
        this::`returns the TradeOrder if it exists for the given tracking ID`,
        this::`returns null if the TradeOrder is not found for the given tracking ID`,
        this::`returns an empty list if no TradeOrder was found for the given account ID`,
        this::`returns all outstanding TradeOrders for the given account ID`
    ).map { test ->
        dynamicTest(test.name) { test(tradeOrderRepositoryWith) }
    }
}
```

Any tests for specific implementations of the Contract derive tests from the Contract Test class
(with the `@TestFactory` in the example below) and pass any Test Helpers that the tests need as parameters.
Additional test hooks may also be provided to setup the environment for tests.
These remain in the concrete implementation of the tests and the Contract Test should be unaware of them.

```kotlin
@Testcontainers(disabledWithoutDocker = true)
class ExposedTradeOrderRepositoryTests {

    companion object {
        @Container
        private val postgresql = PostgreSQLContainer(DockerImageName.parse("postgres:17-alpine"))
    }

    @BeforeTest
    fun createSchema(): Unit = transaction(postgresql.connection) {
        addLogger(StdOutSqlLogger)
        SchemaUtils.drop(TradeOrders)
        SchemaUtils.create(TradeOrders)
    }

    @TestFactory
    fun `TradeOrderRepository Contract`() =
        TradeOrderRepositoryContract().allTests(::tradeOrderRepositoryWith)

    private fun tradeOrderRepositoryWith(existingTradeOrders: List<TradeOrder>): TradeOrderRepository {
        persistTradeOrders(existingTradeOrders)
        return ExposedTradeOrderRepository(postgresql.connection)
    }

    private fun persistTradeOrders(existingTradeOrders: List<TradeOrder>) = transaction(postgresql.connection) {
        addLogger(StdOutSqlLogger)
        TradeOrders.batchInsert(existingTradeOrders) {
            this[TradeOrders.trackingId] = it.trackingId.value
            this[TradeOrders.brokerageAccountId] = it.brokerageAccountId.value
            this[TradeOrders.type] = it.type
            this[TradeOrders.security] = it.security.value
            this[TradeOrders.numberOfShares] = it.numberOfShares
            this[TradeOrders.status] = it.status
        }
    }
}
```

Additional implementations can now be provided and conform to the Contract by passing the same Contract Tests.

```kotlin
class InMemoryTradeOrderRepositoryTests {
    @TestFactory
    fun `TradeOrderRepository Contract`() = TradeOrderRepositoryContract()
        .allTests { tradeOrders: List<TradeOrder> ->
            InMemoryTradeOrderRepository(tradeOrders)
        }
}
```

## References

- [xUnit Test Patterns: Refactoring Test Code - Chapter 24 - Testcase Superclass](https://www.oreilly.com/library/view/xunit-test-patterns/9780131495050/ch24.html#ch24lev1sec7) by Gerard Meszaros
- [JUnit Recipes](https://www.manning.com/books/junit-recipes) by J. B. Rainsberger with contributions by Scott Stirling
- [Testcase Superclass](http://xunitpatterns.com/Testcase%20Superclass.html)
- [Test Utility Method](http://xunitpatterns.com/Test%20Utility%20Method.html)
- [Abstract Test](https://wiki.c2.com/?AbstractTest)
- [Abstract Test Cases](https://wiki.c2.com/?AbstractTestCases)
- [Abstract Test Cases, 20 Years Later](https://blog.thecodewhisperer.com/permalink/abstract-test-cases-20-years-later)
- [In brief: Contract Tests](https://blog.thecodewhisperer.com/permalink/in-brief-contract-tests)
- [Contract Test Examples](https://github.com/jakzal/contract-test-examples)
