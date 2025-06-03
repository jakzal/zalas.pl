---
title: "Functional domain model"
date: "2023-10-13T20:20:51Z"
draft: false
series: ["Event Sourcing"]
series_weight: 1
tags: ["kotlin", "functional programming", "ddd"]
keywords: ["kotlin", "functional programming", "ddd", "domain-driven design", "dddesign"]
cover:
  image: "functional-domain-model-cover.svg"
  alt: "Functional Domain Model"
summary: A **functional domain model** is made of **pure functions** and **immutable** types. As Domain Driven Design teaches us, it should be expressed in the **language shared** by everyone involved in the project.
---

A **functional domain model** is made of **pure functions** and **immutable** types.
As Domain Driven Design teaches us, it should be expressed in the **language shared** by everyone involved in the project.

> [!SERIES] This article is part of the [event sourcing](/series/event-sourcing/) series:
>
> * Functional domain model
> * [Functional event sourcing](/functional-event-sourcing/)
> * [Functional event sourcing example in Kotlin](/functional-event-sourcing-example-in-kotlin/)
> * [Deriving state from events](/deriving-state-from-events/)
> * [Object-Oriented event sourcing](/object-oriented-event-sourcing/)

## Pure functions

A [pure function](https://en.wikipedia.org/wiki/Pure_function) always returns the same result given the same arguments.

{{< figure src="pure-function.svg" caption="Pure function" >}}

> Here are the fundamental properties of a pure function:
>
> 1. A function returns exactly the same result every time it's called with the same set of arguments. In other words a function has no state, nor can it access any external state. Every time you call it, it behaves like a newborn baby with blank memory and no knowledge of the external world.
>
> 2. A function has no side effects. Calling a function once is the same as calling it twice and discarding the result of the first call.
{cite="https://www.schoolofhaskell.com/user/school/starting-with-haskell/basics-of-haskell/3-pure-functions-laziness-io" caption="Bartosz Milewski, School of Haskell"}

Pure functions are [calculations](https://ericnormand.me/podcast/what-is-a-calculation).

Here's an example of a pure function:

```kotlin {caption="Pure function example"}
fun execute(command: Command): Event = when(command) {
    is SayHello -> MessagePublished("Hello ${command.recipientName}.")
    is SayGoodbye -> MessagePublished("See you later ${command.recipientName}!")
}
```

It doesn’t matter how many times we call the `execute` function above,
as long as we call it with the same command we will always get the same message back.

```kotlin {caption="Pure function properties"}
assert(execute(SayHello("Alice")) == execute(SayHello("Alice")))
assert(execute(SayHello("Alice")) != execute(SayHello("Bob")))
```

## Immutable types

An [immutable](https://en.wikipedia.org/wiki/Immutable_object) data structure cannot be changed after its instance was created.

Here's an example of an immutable type:

```kotlin {caption="Immutable type example"}
data class MessagePublished(val message: String) : Event
```

Once initialised, its properties cannot be changed:

```kotlin
val event = MessagePublished("Hello!")

// Won't compile: "Val cannot be reassigned"
event.message = "New message"
```

Since we used `val` to store the reference to the object, it cannot be reassigned either:

```kotlin
val event = MessagePublished("Hello!")

// Won't compile: "Val cannot be reassigned"
event = MessagePublished("Bye")
```

Instead of modifying an immutable instance we need to create a new one:

```kotlin {caption="Modifying immutable data"}
val event = MessagePublished("Hello!")

val newEvent = event.copy(message = "Bye!")
// or:
// val newEvent = MessagePublished("Bye")

assert(MessagePublished("Hello!") == event)
assert(MessagePublished("Bye!") == newEvent)
```

## Testing

Nothing gets close to the joy of writing tests for pure functions that work with immutable data structures.

We pass the input and then verify the output.

The good old Arrange-Act-Assert, a.k.a. Given-When-Then, is so evident.

```kotlin {caption="Test examples"}
@Test
fun `it says hello`() {
    val command = SayHello("John")

    val event = execute(command)

    assertEquals(MessagePublished("Hello John."), event)
}

@Test
fun `it says goodbye`() {
    val command = SayGoodbye("Sue")

    val event = execute(command)

    assertEquals(MessagePublished("See you later Sue!"), event)
}
```

This kind of tests are easiest to write, a joy to read, and the fastest to execute.

## Reasoning scope

When considered in a narrow scope of a single function call,
neither mutable types nor functions with side effects have a big impact on our reasoning or testing.
They're manageable with a bit of discipline.

{{< figure src="function-with-mutable-state.svg" caption="Function accessing a mutable state" >}}

However, it gets more complicated in the wider context of the application.

{{< figure src="functions-sharing-mutable-state.svg" caption="Multiple functions sharing mutable state" >}}

If mutable data or its reference is shared, it could be changed from (m)any part(s) of the application.
Similarly, if a function has side effects, its effects can be seen elsewhere.
The order of calls starts to matter as well.

Immutable types and pure functions narrow down the scope of change.
State changes are local to the place that triggered them and need to be explicitly passed up or down.

That helps with reasoning, as in our head we can now confidently replace the function call with its result
(see [referential transparency](https://ericnormand.me/podcast/what-is-referential-transparency) and equational reasoning).


{{< figure src="referential-transparency.svg" caption="Referential transparency illustrated" >}}

## Error handling

One last thing to consider in a functional domain model is our attitude to error cases.

A common approach is to use exceptions.

Unfortunately, exceptions cripple our reasoning ability, similarly to mutable types or side-effect functions,
as they break referential transparency.
Exceptions are in a way [a form of non-local GOTO](https://web.archive.org/web/20140430044213/http://c2.com/cgi-bin/wiki?DontUseExceptionsForFlowControl)
since they allow to jump up the stack out of the normal execution flow. These properties go against our functional model.

{{< figure src="exception-bubbling-up.svg" caption="An exception seen breaking an application" >}}

Therefore, it's good to make a distinction between **domain errors**, and **infrastructure or panic errors**
(see [types of errors](https://fsharpforfunandprofit.com/posts/against-railway-oriented-programming/#when-should-you-use-result)).
The first are **expected** while the latter are *mostly* **exceptions**.

Unchecked exceptions are not part of the function's signature, so without looking into the function's body we won't know
what kind of errors to expect. The caller could be totally oblivious and ignore exceptions altogether.

```kotlin {caption="Exception example"}
fun execute(command: Command): Event = throw DisallowedCommand()
```

Exceptions are implicit and unexpected (unless checked).

Errors, on the other hand, need to be explicitly defined as part of the function's signature.

```kotlin {caption="Explicit error result example"}
fun execute(command: Command): Either<Error, Event> = Left(DisallowedCommand())
```

{{< figure src="error-result.svg" caption="Explicit error result" >}}

The caller needs to either deal with the error or pass it up to the caller.

```kotlin {caption="Dealing with errors example"}
val response = game
  .execute(SayGoodbye("Bob"))
  .map(::toResponse)
  .getOrElse(::toErrorResponse)
```

## Rich domain model

Domain Driven Design teaches us to express the domain model in the language shared by everyone involved in the project.

If we make the domain types and functions rich in domain vocabulary, there's no translation needed in discussions with the business.
In fact, using the same vocabulary we put into the code to talk to the stakeholders is a form of validating the domain model.
They’ll catch any discrepancies in the language we use.

Furthermore, if we make illegal states unrepresentable, types become self-documenting.
Limited options encoded in a rich model make for an improved ability to reason about it, and therefore maintain or change it.

## Summary

The domain model is arguably the most important layer in an application. It should also be where complexity is tackled.
After all, that's where business decisions live and that's what makes our application distinctive.

Making the domain model functional helps to reduce the complexity and concentrate it inside the model.
Any impure operations will be pushed to the boundaries of the system.
What's pushed outside might not be necessarily trivial, but it will be mostly business-decision-free code
that deals with side effects.

{{< figure src="io-sandwich.svg" caption="I/O Sandwich" >}}

Hopefully, we'll end up with a code base that's less prone to errors, easier to understand and maintain,
and effortless to test.

I find that a functional domain model plays really well with event sourcing.
That's what we're going to look at in [the next post](/functional-event-sourcing/).

## Resources

* [Domain Modeling Made Functional by Scott Wlaschin](https://pragprog.com/titles/swdddf/domain-modeling-made-functional/)
* [F# for Fun and Profit](https://fsharpforfunandprofit.com/)
* [Grokking Simplicity by Eric Normand](https://www.manning.com/books/grokking-simplicity)
* [What is referential transparency? by Eric Normand](https://ericnormand.me/podcast/what-is-referential-transparency)
* [MIT Software Construction course, Mutability & Immutability](https://web.mit.edu/6.005/www/fa15/classes/09-immutability/)
* [Functional core, imperative shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)

<!-- https://excalidraw.com/#json=2XoMJhiMT1WaVgUV3x7ff,epo5XkiNLnXaKAbvg5Tcig -->
<!-- https://excalidraw.com/#json=MuVylWROzvzJG5HfAvVeW,ol5EXquCw0ihsgrsmatizQ -->
