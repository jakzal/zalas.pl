---
title: "On granularity of tests focused on behaviour"
date: "2022-05-17T10:16:05Z"
draft: false
tags: ["testing", "tdd", "bdd"]
keywords: ["testing", "tdd", "bdd", "behaviour", "behavior", "granularity", "layers", "altitude", "levels"]
cover:
  image: "/on-granularity-of-tests-focused-on-behaviour/testing-at-higher-levels.svg"
  alt: "On granularity of tests focused on behaviour"
  hiddenInSingle: true
---

## Behaviour

A function is one of the smallest units of behaviour. Given an input, it returns the output.

{{< figure src="function.svg" caption="Function" >}}

This means that given the context (input), the function's behaviour can be verified by calling the function and looking at the outcome (output).

Notice that the most straightforward outcome to verify is the function's return value, but it's not the only outcome we can look for. Functions can have side effects, modify state, interact with collaborators, etc.

> [!NOTE]
> I'm going to talk about functions as a unit of behaviour for simplicity, but most of it applies to objects as well.
> After all, objects can be thought of as functions with some context encapsulated.

## Composition

Functions can be composed to build more complex behaviours out of the simpler ones.

{{< figure src="function-composition.svg" caption="Function composition" >}}

Composition works all the way up (or down).

{{< figure src="application-composition.svg" caption="Application composition" >}}

It's a simplification, but an application can be thought of as a composition of behaviours. At the top, there's an entry point that the end-user will call. The entry point will in turn call lower levels, that will call even lower levels, that will call [...], all the way to the bottom.

## Altitude and granularity

In my tests, I can choose to verify the behaviour on any altitude with any granularity.

By choosing one of the higher and coarser-grained levels, I'm able to verify the behaviour closer to the end user's experience.
The cost is less pressure put on the design.

{{< figure src="testing-at-higher-levels.svg" caption="Testing coarser behaviours at higher levels" >}}

By going with finer-grained behaviours, and writing tests on many levels, I'm able to verify the behaviour of
components that make up the system and how they interact.
The gain is a better feedback on my design.

{{< figure src="testing-at-lower-levels.svg" caption="Testing finer-grained behaviours at many levels" >}}

The coarser the behaviour I choose to test, the more freedom I get in arranging lower levels.
Since it requires more mental effort to keep myself disciplined and take steps small enough to remain in control, it's not necessarily a good kind of freedom.
Furthermore, at a certain altitude, it will be harder to verify behaviours buried at lower levels.

The finer the behaviour I choose to test, the more organised I am and the smaller steps I take.
Tests will also give me better feedback on my design while being less business-focused, perhaps.
I will sometimes need to refactor them or even replace if I decided to change some components or the way they interact.

## Slicing

In order to write tests for finer-grained behaviours, I need to replace some dependencies with test doubles (i.e. fakes, stubs, mocks, etc.).
I do that, among other reasons, to have a better control over the context in which the behaviour is executed.
Introducing test doubles naturally cuts the behaviour to be finer-grained, and this way reduces the scope of the test.

{{< figure src="replacing-dependencies-in-tests.svg" caption="Replacing dependencies in tests" >}}

However, I do not need to replace all dependencies. I do not need to replace direct dependencies, either.
It's up to me to decide how coarse the unit I'm writing a test for is.

{{< figure src="replacing-some-dependencies-in-tests.svg" caption="Replacing (some) dependencies in tests" >}}

> We get to choose when and where we break the dependency chain for testing.
{cite="https://www.geepawhill.org/2018/01/16/underplayed-the-chain-premise-in-depth/" caption="Micheal \"GeePaw\" Hill"}

## Conclusion

So which way do I prefer?

If I had to choose one, I'd go for the tests for finer-grained behaviours.

I tend to write both kinds though, to make sure both external and internal quality is taken care of.

I like to exercise my acceptance tests for coarser-grained behaviours through one of the higher levels.
I often use them to create a "walking skeleton".
This kind of tests won't execute every possible path. I won't write a lot of them, either.
This kind of tests will exercise big chunks of behaviours to confirm and document the business goals.
These tests will also make sure everything is correctly wired together.
These tests merely supplement the tests that exercise the finer-grained behaviours.

I like to write a lot more tests for finer-grained behaviours. These are smaller, faster to run and write, and more focused.
This kind of tests will exercise very small chunks of behaviour.
These tests will help me to take smaller steps, keep me disciplined, and give me feedback on the quality of my design.

<!-- https://excalidraw.com/#json=dMMOUnqqi_K3H2VigT46k,TtjM5QTethkKb_svrqaLxQ -->
