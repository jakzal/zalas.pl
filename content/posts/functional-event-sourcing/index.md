---
title: "Functional event sourcing"
date: "2023-10-19T21:14:25Z"
draft: true
series: ["Event Sourcing"]
tags: ["kotlin", "event sourcing", "ddd", "functional programming"]
keywords: ["kotlin", "event sourcing", "functional event sourcing", "ddd", "functional programming", "domain-driven design", "dddesign", "decider"]
cover:
  image: "functional-event-sourcing-cover.svg"
  alt: "Functional event sourcing"
summary: Let's consider how functional domain model might work in practice by applying the **event sourcing** pattern.
---

In [the previous post](/functional-domain-model/), we looked at the benefits of a **domain model** implemented in a **purely functional** code.

This time, we’ll consider how it might work in practice by applying the **event sourcing** pattern to a functional domain model.

As it turns out the two go very well together.

> [!SERIES] This article is part of the [event sourcing](/series/event-sourcing) series:
>
> * [Functional domain model](/functional-domain-model/)
> * Functional event sourcing
> * [Functional event sourcing example in Kotlin](/functional-event-sourcing-example-in-kotlin/)
> * [Deriving state from events](/deriving-state-from-events/)
> * [Object-Oriented event sourcing](/object-oriented-event-sourcing/)

## Event sourcing

The idea behind event sourcing is to:

> *Capture all changes to an application state as a sequence of events.*
{cite="https://martinfowler.com/eaaDev/EventSourcing.html" caption="Martin Fowler on <a href=\"https://martinfowler.com/eaaDev/EventSourcing.html\" alt=\"Event sourcing\">Event Sourcing</a>"}

{{< figure src="event-sequence.svg" caption="Sequence of events" >}}

## Commands in, events out

At the fundamental level, we only need one function for each [aggregate root](https://martinfowler.com/bliki/DDD_Aggregate.html) to handle its behaviours.
The function will calculate a sequence of events in response to a command. Command is an intention to trigger a behaviour.

{{< figure src="execute-command.svg" caption="Command in, events out" >}}

Let's call this function **Execute** since its job is to execute the command.

```kotlin {caption="Execute function type alias"}
typealias Execute<COMMAND, EVENT> = (COMMAND) -> NonEmptyList<EVENT>
```

> [!NOTE]
> I chose `Execute` as the name for the function following one of the naming strategies for aggregate methods found in
> "[Learning Domain-Driven Design](https://www.goodreads.com/book/show/59383590-learning-domain-driven-design)" by Vladik Khononov. 
> I'm going to talk about functions as a unit of behaviour for simplicity, but most of it applies to objects as well.
> After all, objects can be thought of as functions with some context encapsulated.
> 
> Jeremie Chassaing prefers to call this function `Decide` in his definition of the [Decider Pattern](https://thinkbeforecoding.com/post/2021/12/17/functional-event-sourcing-decider).

## History is not forgotten

As we execute commands for any given aggregate, events will be appended to a journal (event store).
Past events will be also needed to handle future commands for that aggregate.

For example, a game cannot be played before it is started or after it is lost. Or, once an order has shipped it can no longer be amended.

We will look into the history to make decisions.

Therefore, the *Execute* function will also need the past events. That list will be empty when the first command for a given aggregate is executed.

{{< figure src="execute-command-with-past-events.svg" caption="Event history takes part in decision making" >}}

Here's the updated type definition of *Execute*:

```kotlin {caption="Execute function type alias"}
typealias Execute<COMMAND, EVENT> = (COMMAND, List<EVENT>) -> NonEmptyList<EVENT>
```

## Protecting invariants

That's going well, but what about error cases?

As I pointed out in [the last post](/functional-domain-model/), I prefer to be explicit about domain errors.
That's why we'll make them one of the possible outcomes:

{{< figure src="execute-command-with-explicit-errors.svg" caption="Errors become one of the possible outcomes" >}}

The *Execute* function will need to either return an error or a non-empty list of events:

```kotlin {caption="Execute function type alias"}
typealias Execute<COMMAND, ERROR, EVENT> =
  (COMMAND, List<EVENT>) -> Either<ERROR, NonEmptyList<EVENT>>
```

> [!NOTE]
> I use [Arrow](https://arrow-kt.io/learn/typed-errors/) for typed errors, specifically the `Either` and `NonEmptyList` types.
> However, any type-safe error-handling library would work.
> [Result4k](https://github.com/fork-handles/forkhandles/tree/trunk/result4k) is a nice alternative to Arrow.

## The matter of state

As we defined it so far, the *Execute* function is the minimum we need to implement an event-sourced domain model.

Here's an example of a further unidentified game pending the implementation:

```kotlin
typealias Game = List<GameEvent>

fun execute(command: GameCommand, game: Game): Either<GameError, NonEmptyList<GameEvent>> = 
  when(command) {
    is JoinGame -> TODO()
    is MakeGuess -> TODO()
  }
```

Let's assume we don't want to allow to make guesses once the game is won. The game is considered won when the *GameWon* event is published.
In such a case, any *MakeGuess* command should be rejected with an error.

As I suggested before, we will need to look at the history of events to make decisions.
Having the list of events passed to the *Execute* function we can scan it for facts:

```kotlin
events.filterIsInstance<GameWon>().isNotEmpty()
```

Furthermore, we can name any concept by defining an extension function for it:

```kotlin
private fun Game.isWon(): Boolean = filterIsInstance<GameWon>().isNotEmpty()
```

Remember the `Game` here is actually a `List<GameEvent>`.

Thanks to extension functions and our previously defined type alias for the Game (as a list of events), it becomes very natural to use:

```kotlin
if (game.isFinished()) {
  return GameAlreadyFinished(gameId).left()
}

// Note: `.left()` wraps the result in an `Either.Left` 
// that represents the error branch.
```

Just as if we had the *Game* class defined.

It is just a list of events though.

It will work rather well for short streams of events. However, scanning long streams might get expensive, especially if we make decisions based on a lot of factors.
For such scenarios, we can introduce an optimisation in the form of a computed **state** (projection).

**The entity's state can be derived from its history of events.**

The difference between using a computed state and scanning events history is that when we reconstruct the state object every event is applied only once to update the state.
Then, we can access it however many times we need. In the case of event scanning, the scan is performed every time we need to access a bit of information.

> [!NOTE]
> We can go a long way without having to introduce a computed state if we treat the history of events as the state and scan it for information as shown above.
>
> I often use this technique as an intermediate step. It helps me to learn what the properties of the state object should look like.
> It sometimes turns out to be a different view than I thought of before the implementation.

### Execute with state

Let's redefine the `Execute` function one last time to account for the possibility of the state being any kind of type (not just an events list).

{{< figure src="execute-command-with-state.svg" caption="Final form of the Execute function" >}}

Here's the final revision of the *Execute* function type alias:

```kotlin {caption="Final definition of the Execute function type alias"}
typealias Execute<COMMAND, STATE, ERROR, EVENT> =
  (COMMAND, STATE) -> Either<ERROR, NonEmptyList<EVENT>>
```

This way we can still use a sequence of events as a state:

```kotlin
fun execute(command: GameCommand, game: Game): Either<GameError, NonEmptyList<GameEvent>>
  = TODO()

typealias Game = NonEmptyList<GameEvent>

private fun Game.isWon(): Boolean = filterIsInstance<GameWon>().isNotEmpty()
```

but we can also decide to implement it as a dedicated data class:

```kotlin
fun execute(command: GameCommand, game: Game?): Either<GameError, NonEmptyList<GameEvent>>
  = TODO()

data class Game(val isWon: Boolean)
```

The state is made nullable as it won't exist when the first command is executed.

Alternatively, we could model the initial state as a special type. The choice depends on the use case.
Sometimes it's natural to have a dedicated initial state object;
while in other cases it makes more sense for the initial state to be `null` (as no natural initial state exists).
As we know, in Kotlin we **don't** need to **be afraid of nulls**.

## State reconstruction

We will need a way to reconstruct the state with events we got from the event store so that we can pass it to the *Execute* function.

Instead of scanning through the history of events to access every bit of information, we will instead build the state by applying events to it one by one.

> Current state is a left fold of previous behaviours.
{caption="Greg Young in many of his talks"}

To calculate the state, we will start with `null` (or other initial state), and fold events with an `applyEvent` function.

```kotlin {caption="Left fold of previous events"}
val state = events.fold(null, ::applyEvent)
```

The `applyEvent` function, or simply `Apply`, should take the state, an event, and return a new state.

{{< figure src="apply.svg" caption="Apply calculates a new state for the given state and event" >}}

In other words, it will calculate the new state based on the previous state and an event.

Here's the type alias for the *Apply* function:

```kotlin {caption="Apply function type alias"}
typealias Apply<STATE, EVENT> = (STATE, EVENT) -> STATE
```

Here’s how it could look like for a further unidentified game:

```kotlin
fun applyEvent(game: Game?, event: GameEvent): Game? = when(event) {
    is GameStarted -> Game(event.secret, Outcome.UNRESOLVED)
    is GuessMade -> TODO()
    is GameLost -> game?.copy(outcome = Outcome.LOST)
    is GameWon -> game?.copy(outcome = Outcome.WON)
}
```

Folding events over the state means that the *Apply* function is called on the initial state and the first event, to calculate a new state.
The new state is in turn passed to the next invocation of *Apply* with the next event.
This process is repeated until we run out of events and return the final version of the state.

{{< figure src="folding-events.svg" caption="Fold of events illustrated" >}}

## All together now

The command will usually come from a user in one way or another (sometimes from other systems, in reaction to events or other commands etc).

Events will be loaded from an event store.

These two are not compatible parameters for the *Execute* function if we decide to use a computed state.

We will need to convert:

{{< figure src="execute-command-with-state.svg" caption="Execute with a computed state" >}}

To:

{{< figure src="execute-command-with-explicit-errors.svg" caption="Execute with a sequence of events as state" >}}

The conversion of one type to another isn’t too complicated. We can implement a creational function that takes one version of `Execute` and returns the desired one:

```kotlin
fun <COMMAND : Any, EVENT : Any, ERROR : Any, STATE> handlerFor(
    execute: Execute<COMMAND, STATE, ERROR, EVENT>,
    applyEvent: Apply<STATE, EVENT>,
    initialState: () -> STATE,
): Execute<COMMAND, List<EVENT>, ERROR, EVENT> =
  { command, events -> execute(
      command,
      events.fold(initialState(), applyEvent)
  )}
```

Apart from `Execute` we will also need to pass `Apply` to fold events and build the state.

Additionally, it’s just too easy to support any initial state, not just nulls. That’s the job for the `initialState` function.

{{< figure src="execute-type-change.svg" caption="Changing the type of `Execute` to match received parameters" >}}

## Inspirations

Before I started a project with this approach I did a lot of reading on functional programming techniques for event sourcing.
One notable read I remember is [Functional event sourcing decider](https://thinkbeforecoding.com/post/2021/12/17/functional-event-sourcing-decider) by Jeremie Chassaing.
An attentive reader will notice that what I described here comes very close to Jeremie's decider pattern.

I didn't set out to implement the decider pattern, but it kind of happened anyway. Kind of. Not really. Maybe?

Depends on how far you'll allow us to diverge from the pattern.

The decider pattern is made of the following parts:

```kotlin
class Decider<COMMAND: Any, EVENT: Any, STATE: Any>(
  val decide: (COMMAND, STATE) -> List<EVENT>,
  val evolve: (STATE, EVENT) -> STATE,
  val initialState: STATE,
  val isTerminal: (STATE) -> Boolean
)
```

The approach I've taken is:


```kotlin
class Handler<COMMAND : Any, EVENT : Any, ERROR : Any, STATE: Any?>(
  val execute: (COMMAND, STATE) -> Either<ERROR, NonEmptyList<EVENT>>,
  val applyEvent: (STATE, EVENT) -> STATE,
  val initialState: () -> STATE,
)
```

Apart from naming conventions (Execute/Apply vs Decide/Evolve), there are a few other differences:

* I accept `null` as a valid initial state.
* I’m in favour of explicit domain errors rather than using exceptions.
* I treat evolve and initial state parts as optional.
* I have not found the need for the terminal state (yet?).


Now go and read Jeremie’s article or listen to one of his talks.

## Summary

We have applied the event sourcing pattern in a functional domain model.

Next time, we will discuss an [example implementation](/functional-event-sourcing-example-in-kotlin/) before moving on to the outer layers of the application.

## Resources

* [Event Sourcing by Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html)
* [A Beginner’s Guide to Event Sourcing](https://www.kurrent.io/event-sourcing)
* [Functional event sourcing decider by Jeremie Chassaing](https://thinkbeforecoding.com/post/2021/12/17/functional-event-sourcing-decider)

<!-- https://excalidraw.com/#json=EmSdF6GOL-8pr2dx_vXVo,y_W6WljqAfRmzHqiKX6Hfw -->
