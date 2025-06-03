---
title: "Deriving state from events"
date: "2023-11-10T14:27:31Z"
draft: false
series: ["Event Sourcing"]
series_weight: 4
tags: ["kotlin", "event sourcing", "ddd", "functional programming"]
keywords: ["kotlin", "event sourcing", "functional event sourcing", "ddd", "functional programming", "domain-driven design", "dddesign", "decider"]
cover:
  image: "deriving-state-cover.svg"
  alt: "Deriving state from events"
summary: In event sourcing, the state is derived from events that have happened in the past. In a classic approach, state is persisted while events are lost. In an event-sourced system, it's the events that are persisted while state is derived.
---

Now that we have discussed a [functional approach to event sourcing](/functional-event-sourcing/)
and have chewed over an [example implementation](/functional-event-sourcing-example-in-kotlin/),
let's consider the state in an event-sourced domain model.

> [!SERIES] This article is part of the [event sourcing](/series/event-sourcing/) series:
>
> * [Functional domain model](/functional-domain-model/)
> * [Functional event sourcing](/functional-event-sourcing/)
> * [Functional event sourcing example in Kotlin](/functional-event-sourcing-example-in-kotlin/)
> * Deriving state from events
> * [Object-Oriented event sourcing](/object-oriented-event-sourcing/)

In event sourcing, the **state** is **derived** from **events** that have happened in the past.
In a classic approach, it's the state that is persisted while events are lost.
In an event-sourced system, it's the events that are persisted while state is derived.

> In Event Sourcing, the source of truth is the events, and the state of the application is derived from these events.
{cite="https://www.kurrent.io/event-sourcing" caption="<a href=\"https://www.kurrent.io/event-sourcing\">A Beginner’s Guide to Event Sourcing</a>"}

## Events as state

The most direct thing we can do is to filter events on the fly for the facts that we need to make decisions.

{{< figure src="filtering-events.svg" caption="Filtering events for information" >}}

Indeed, this is exactly what we've done in the last article. We defined a bunch of extension properties and functions that work on the event list.

```kotlin {caption="Example of filtering events for information"}
typealias Game = List<GameEvent>

private val Game.secret: Code?
  get() = filterIsInstance<GameStarted>().firstOrNull()?.secret

private val Game.secretLength: Int
  get() = secret?.length ?: 0

private val Game.secretPegs: List<Code.Peg>
  get() = secret?.pegs ?: emptyList()

private val Game.attempts: Int
  get() = filterIsInstance<GuessMade>().size

private val Game.totalAttempts: Int
  get() = filterIsInstance<GameStarted>().firstOrNull()?.totalAttempts ?: 0

private val Game.availablePegs: Set<Code.Peg>
  get() = filterIsInstance<GameStarted>().firstOrNull()?.availablePegs ?: emptySet()

private fun Game.isWon(): Boolean = filterIsInstance<GameWon>().isNotEmpty()

private fun Game.isLost(): Boolean = filterIsInstance<GameLost>().isNotEmpty()

private fun Game.isStarted(): Boolean = filterIsInstance<GameStarted>().isNotEmpty()

private fun Game.isGuessTooShort(guess: Code): Boolean = guess.length < secretLength

private fun Game.isGuessTooLong(guess: Code): Boolean = guess.length > secretLength

private fun Game.isGuessValid(guess: Code): Boolean = availablePegs.containsAll(guess.pegs)
```

Notice that, since we have no guarantees that certain events are in the stream, we often need to handle missing events
by providing default values (like in `Game.availablePegs`) or returning `null` (like in `Game.secret`).

Other than that, the usage is pretty similar to what we'd have if we had a proper class representing the state.

```kotlin {caption="Extension functions in action"}
private fun startedNotFinishedGame(command: MakeGuess, game: Game): Either<GameError, Game> {
  if (!game.isStarted()) {
    return GameNotStarted(command.gameId).left()
  }
  if (game.isWon()) {
    return GameAlreadyWon(command.gameId).left()
  }
  if (game.isLost()) {
    return GameAlreadyLost(command.gameId).left()
  }
  return game.right()
}
```

This is a good way forward with short streams and a relatively small number of query operations.
It's also a good way to figure out what kind of properties and functions we might need for our state implementation.
Once we learn what's required, we can always refactor to a stream aggregation.

## Event stream aggregation

Event stream aggregation is a process that builds the state from a stream of events.
It starts with an initial value and applies events one by one in order.
Each application of an event returns an updated state.
In other words, stream aggregation is a projection of events to a state.

{{< figure src="folding-events.svg" caption="Event stream aggregation" >}}

What then gets passed to our domain functions is an instance of the built state rather than the stream of events.
Here's an example for our Game.

```kotlin {caption="Example state derived from events"}
data class Game(
  val secret: Code,
  val attempts: Int,
  val totalAttempts: Int,
  val availablePegs: Set<Code.Peg>,
  val outcome: Feedback.Outcome
) {
  val secretLength: Int = secret.length

  val secretPegs: List<Code.Peg> = secret.pegs

  fun isWon(): Boolean = outcome == WON

  fun isLost(): Boolean = outcome == LOST

  fun isGuessTooShort(guess: Code): Boolean = guess.length < secretLength

  fun isGuessTooLong(guess: Code): Boolean = guess.length > secretLength

  fun isGuessValid(guess: Code): Boolean = availablePegs.containsAll(guess.pegs)
}
```

Notice that some of the nullable values or default cases have disappeared.
That should help us simplify some of the code previously needed to handle such cases.
Other than that, if we managed to keep the same public interface while converting extension properties and functions to instance equivalents,
hardly any other code should be required to change.

Deriving the state will usually follow the same pattern. It's a left-fold of previous events.

```kotlin {caption="Deriving state from events"}
fun notStartedGame(): Game? = null

val state = events.fold(notStartedGame(), ::applyEvent)
```

What's going to be different with each model implementation is the `applyEvent()` function.
Its job is to take the state we have so far and calculate the new state by applying the next event.

```kotlin {caption="Transitioning the state by applying an event"}
fun applyEvent(game: Game?, event: GameEvent): Game? = when (event) {
  is GameStarted -> Game(event.secret, 0, event.totalAttempts, event.availablePegs, IN_PROGRESS)
  is GuessMade -> game?.copy(attempts = game.attempts + 1)
  is GameWon -> game?.copy(outcome = WON)
  is GameLost -> game?.copy(outcome = LOST)
}
```

As we can see in the above example, the *GameStarted* event is used to initialise the *Game* state as it should be the first event that happened.
All the other events only modify the previous *Game* state by changing a subset of its properties.

As long as the first event in the stream is *GameStarted*, our *applyEvent()* function will always return a non-null value.
We ignore an event if that's not the case. That's what those `?.` safe calls will take care of. It's not our job to validate anything at this point.
Any validation is done when we execute the command. If the event was generated it must be possible to apply it to the state.

To make this work, we will need to update our tests to build the state and pass it to tested behaviours instead of events.

```kotlin {caption="Building the state in tests"}
@Test
fun `it makes a guess`() {
  val command = MakeGuess(gameId, Code("Purple", "Purple", "Purple", "Purple"))
  val game = gameOf(GameStarted(gameId, secret, totalAttempts, availablePegs))

  execute(command, game) shouldSucceedWith listOf(
    GuessMade(
      gameId,
      Guess(Code("Purple", "Purple", "Purple", "Purple"), Feedback(IN_PROGRESS))
    )
  )
}

private fun gameOf(vararg events: GameEvent): Game = 
  events.toList().fold(notStartedGame(), ::applyEvent)
```

## Initial state

The initial state is passed as the initial value to the fold function. In previous examples, we used `null` for the initial state.
In many cases like ours, it's perfectly fine. In other cases though, there might be a valid initial representation of a state that's not null.
Let's now consider how our game implementation would look like with a non-nullable initial state.

Instead of having `null` for the initial state, we will now have it explicitly modelled.

```kotlin {caption="Explicitly modelled initial state"}
sealed interface Game

data object NotStartedGame : Game

data class StartedGame(
  val secret: Code,
  val attempts: Int,
  val totalAttempts: Int,
  val availablePegs: Set<Code.Peg>,
  val outcome: Feedback.Outcome
) : Game {
  val secretLength: Int = secret.length

  val secretPegs: List<Code.Peg> = secret.pegs

  fun isWon(): Boolean = outcome == WON

  fun isLost(): Boolean = outcome == LOST

  fun isGuessTooShort(guess: Code): Boolean = guess.length < secretLength

  fun isGuessTooLong(guess: Code): Boolean = guess.length > secretLength

  fun isGuessValid(guess: Code): Boolean = availablePegs.containsAll(guess.pegs)
}

fun notStartedGame(): Game = NotStartedGame
```

We now have a sealed interface for the `Game` with two implementations - `NotStartedGame` and `StartedGame`.

The advantage of this approach is its clarity. Furthermore, if there's a natural initial state for the thing we're modelling,
it could have some properties initialised. That's not the case in our example. We could possibly initialise `attempts` or `outcome`,
but all the other properties are provided when the game is started.

While applying events, we can now make a clear distinction between the two cases of not-started and started games.
It becomes a bit more verbose, but also more explicit. We can easily see the scenarios when the game is not updated in response to an event.
Also, safe calls are gone since now the game cannot be null.

```kotlin {caption="Applying events with non-nullable initial state"}
fun applyEvent(game: Game, event: GameEvent): Game = when (game) {
  is NotStartedGame -> when (event) {
    is GameStarted -> StartedGame(event.secret, 0, event.totalAttempts, event.availablePegs, IN_PROGRESS)
    else -> game
  }
  is StartedGame -> when (event) {
    is GameStarted -> game
    is GuessMade -> game.copy(attempts = game.attempts + 1)
    is GameWon -> game.copy(outcome = WON)
    is GameLost -> game.copy(outcome = LOST)
  }
}
```

Checks for the state become more explicit too.

```kotlin {caption="An example check for a started game"}
private fun startedNotFinishedGame(command: MakeGuess, game: Game): Either<GameError, StartedGame> {
  if (game !is StartedGame) {
    return GameNotStarted(command.gameId).left()
  }
  // ...
  return game.right()
}
```

Notice that in the above example, we take a *Game* but we return a *StartedGame*. Courtesy of Kotlin smart casts.

Once we checked if the game was started we can rely on this fact and pass it down to other functions.

```kotlin {caption="Smart casts in action"}
startedNotFinishedGame(command, game)
  .flatMap { startedGame: StartedGame ->
    // ...
  }
```

At the end of the day, it's very similar to using a nullable state. Except that our initial state has a name.

The question we should ask ourselves is whether having a non-nullable initial state is so much different to using `null`
that it warrants introducing additional types. Probably not, if we consider our game example.
However, it might be a useful technique for complex models.

## Finite state machine

Once we realise that our previous example actually models a [state machine](https://en.wikipedia.org/wiki/Finite-state_machine) with two states,
we can expand it to model all possible states. Let's continue with our game example to explore how it changes the model.

{{< figure src="mastermind-game-states.svg" caption="States of the Mastermind game" >}}

As we can see on the above diagram, the game can be in one of four states: *NotStartedGame*, *StartedGame*, *WonGame*, and *LostGame*.
*NotStartedGame* is our initial state, while *WonGame* and *LostGame* are terminal.

Here's how Mastermind game states can be implemented in Kotlin.

```kotlin {caption="States of the Mastermind game (implementation)"}
sealed interface Game

data object NotStartedGame : Game

data class StartedGame(
  val secret: Code,
  val attempts: Int,
  val totalAttempts: Int,
  val availablePegs: Set<Code.Peg>
) : Game {
  val secretLength: Int = secret.length

  val secretPegs: List<Code.Peg> = secret.pegs

  fun isGuessTooShort(guess: Code): Boolean = guess.length < secretLength

  fun isGuessTooLong(guess: Code): Boolean = guess.length > secretLength

  fun isGuessValid(guess: Code): Boolean = availablePegs.containsAll(guess.pegs)
}

data class WonGame(
  val secret: Code,
  val attempts: Int,
  val totalAttempts: Int,
) : Game

data class LostGame(
  val secret: Code,
  val totalAttempts: Int,
) : Game
```

While applying events, we now need to handle the two new states - *WonGame* and *LostGame* in response to *GameWon* and *GameLost* events respectively.

```kotlin {caption="Finite state machine implementation"}
fun applyEvent(game: Game, event: GameEvent): Game = when (game) {
  is NotStartedGame -> when (event) {
    is GameStarted -> StartedGame(event.secret, 0, event.totalAttempts, event.availablePegs)
    else -> game
  }

  is StartedGame -> when (event) {
    is GameStarted -> game
    is GuessMade -> game.copy(attempts = game.attempts + 1)
    is GameWon -> WonGame(secret = game.secret, attempts = game.attempts, totalAttempts = game.totalAttempts)
    is GameLost -> LostGame(secret = game.secret, totalAttempts = game.totalAttempts)
  }

  is WonGame -> game
  is LostGame -> game
}
```

*WonGame* and *LostGame* states are terminal so we won't be applying any events once the game reaches one of these two states.

A nice side-benefit of all this is that we could remove some functions from the `StartedGame`, like `isWon()` or `isLost()`.
Instead, we can now use types to check the state of the game.
The `outcome` property could also be removed from `StartedGame` for the same reason.

```kotlin {caption="Checking the state the game is in"}
private fun startedNotFinishedGame(
  command: MakeGuess,
  game: Game
): Either<GameError, StartedGame> = when (game) {
  is NotStartedGame -> GameNotStarted(command.gameId).left()
  is WonGame -> GameAlreadyWon(command.gameId).left()
  is LostGame -> GameAlreadyLost(command.gameId).left()
  is StartedGame -> game.right()
}
```

This is even more explicit than the previous model.

## Command handlers

What’s left to consider is how to build the state to be used during command execution so it could participate in decision-making.

What we'll get from an event store is a stream (or a list) of events.
If the command handler expects an instance of state, we will need to build it first.

{{< figure src="execute-type-change.svg" caption="Adapting the type of command handler" >}}

Here's a generic creational function that builds an event list-based handler from a state-based handler.

```kotlin {caption="Function for adapting the type of command handler"}
fun <COMMAND : Any, EVENT : Any, ERROR : Any, STATE> handlerFor(
  execute: (COMMAND, STATE) -> Either<ERROR, NonEmptyList<EVENT>>,
  applyEvent: (STATE, EVENT) -> STATE,
  initialState: () -> STATE,
): (COMMAND, List<EVENT>) -> Either<ERROR, NonEmptyList<EVENT>> = { command, events -> 
  execute(command, events.fold(initialState(), applyEvent)) 
}
```

To create the new handler we will need to pass the one we want to adapt (`execute`), a function for applying an event to the state (`applyEvent`) and the initial state factory.

```kotlin {caption="Adapting the type of command handler (nullable state)"}
val handler = handlerFor(::execute, ::applyEvent) { null }
```

To create a handler for a non-nullable initial state we will need to change the initial state factory.

```kotlin {caption="Adapting the type of command handler (non-nullable state)"}
val handler = handlerFor(::execute, ::applyEvent) { NotStartedGame }
```

Such an adapted handler can be invoked with events directly.
Events will then be used to rebuild the aggregated state that is in turn passed to the model's command handler (our `execute` function).

```kotlin {caption="Invoking a handler"}
handler(command, events)
```

## Summary

We considered several ways to implement state to be used in decision-making in an event-sourced domain model.
We're equipped with a varied range of tools suitable for different sizes and maturity of problems,
from deriving the state with stream extension functions to employing finite state machines.

Next time, we'll take a small detour to experiment with [converting our solution to be more object-oriented](/object-oriented-event-sourcing/).

## Resources

* [A Beginner’s Guide to Event Sourcing](https://www.eventstore.com/event-sourcing)
* [Finite state machine](https://en.wikipedia.org/wiki/Finite-state_machine)
* [Examples gist](https://gist.github.com/jakzal/83a3d282214c704a649fdc2781a06f54)

<!-- https://excalidraw.com/#json=Zj0nAE-GM5t2HbSZvUXUw,Uo9_JZCoQBFXPrzv0AjGFw -->