---
title: "Object-oriented event sourcing"
date: "2023-11-16T14:34:22Z"
draft: true
series: ["Event Sourcing"]
series_weight: 5
tags: ["kotlin", "event sourcing", "ddd"]
keywords: ["kotlin", "event sourcing", "ddd", "domain-driven design", "dddesign", "object-oriented"]
cover:
  image: "object-oriented-event-sourcing-cover.svg"
  alt: "Object-oriented event sourcing"
summary: This time, we're going to refactor our solution towards an object-oriented (OOP) style. The finite state machine we implemented previously enables us to take advantage of polymorphic behaviour while sticking to immutability.
---

In the last post, we’ve shown how to [represent state in a domain model](/deriving-state-from-events/).
We mostly kept behaviours separate from data in a true functional programming fashion.

This time, we’re going to take a little detour and refactor our solution towards an object-oriented (OOP) style.
As it turns out, the finite state machine we implemented previously enables us to take advantage of polymorphic behaviour
via [dynamic dispatch](https://en.wikipedia.org/wiki/Dynamic_dispatch).

Don't worry though, we're not going to go full-stateful but we'll stick to immutability.

> [!SERIES] This article is part of the [event sourcing](/series/event-sourcing/) series:
>
> * [Functional domain model](/functional-domain-model/)
> * [Functional event sourcing](/functional-event-sourcing/)
> * [Functional event sourcing example in Kotlin](/functional-event-sourcing-example-in-kotlin/)
> * [Deriving state from events](/deriving-state-from-events/)
> * Object-Oriented event sourcing

There are two behaviours we're going to move in this exercise:

* `applyEvent()` - used for transitioning state.
* `execute()` - used for command execution.

## Transitioning state

{{< figure src="mastermind-game-states.svg" caption="State transitions" >}}

Last time, we implemented state transitions in a regular function called `applyEvent()`.
It takes advantage of a sealed type hierarchy and transitions the current state to a new state based on an event.

```kotlin {caption="State transitions (implementation)"}
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

The advantage is we have all the transition logic in one place. Each state is a data class or object that implements a sealed interface.
Thanks to the sealed interface, the compiler will remind us to update missing branches in case we add a new state.

```kotlin {caption="State objects and classes"}
sealed interface Game

data object NotStartedGame : Game

data class StartedGame(
  val secret: Code,
  val attempts: Int,
  val totalAttempts: Int,
  val availablePegs: Set<Code.Peg>
) : Game

data object WonGame : Game

data object LostGame : Game
```

Let's group the behaviour with data.

First, we'll need to define an `applyEvent()` method on the `Game` interface.
The signature will be similar to our function's signature, except the game will no longer be a parameter.

```kotlin {caption="Moving state transitions to the Game"}
sealed interface Game {
  fun applyEvent(event: GameEvent): Game   
}
```

Now, the compiler will ask us to implement the method on each state data class/object.
Our IDE will help us here. We will also need to update the tests to use the new method instead of the old function.

Next, we will need to dissect the `applyEvent()` function and move logic to an appropriate class/object.

Refactoring steps involve calling the original function and inlining it to finally simplify and remove dead branches.

{{< figure src="dissecting-state-transitions.svg" caption="Dissecting state transitions" >}}

Starting with *NotStartedGame*, it responds to the *GameStarted* event. Any other event is ignored.

```kotlin {caption="Moving state transitions to NotStartedGame"}
data object NotStartedGame : Game {
  override fun applyEvent(event: GameEvent): Game = when (event) {
    is GameStarted -> StartedGame(event.secret, 0, event.totalAttempts, event.availablePegs)
    else -> this
  }
}
```

*StartedGame* ignores *GameStarted*, increments attempts on *GuessMade*, and transitions to *WonGame* or *LostGame* in response to *GameWon* and *GameLost* respectively.

```kotlin {caption="Moving state transitions to StartedGame"}
data class StartedGame(
  val secret: Code,
  val attempts: Int,
  val totalAttempts: Int,
  val availablePegs: Set<Code.Peg>
) : Game {

  override fun applyEvent(event: GameEvent): Game = when (event) {
    is GameStarted -> this
    is GuessMade -> this.copy(attempts = this.attempts + 1)
    is GameWon -> WonGame
    is GameLost -> LostGame
  }
}
```

*WonGame* and *LostGame* are terminal states so they're free to ignore any events sent their way.

```kotlin {caption="Moving state transitions to WonGame and LostGame"}
data object WonGame : Game {
  override fun applyEvent(event: GameEvent): Game = this
}

data object LostGame : Game {
  override fun applyEvent(event: GameEvent): Game = this
}
```

What we end up with is behaviour for each state that's close to its type definition and data.

## Executing commands

Moving on to command execution, the steps involved are quite similar.

First, we need to define a new method on the *Game* interface. Similarly to the previous case, the game argument goes away.

```kotlin {caption="Moving command execution to the Game"}
sealed interface Game {
    fun applyEvent(event: GameEvent): Game
    fun execute(command: GameCommand): Either<GameError, NonEmptyList<GameEvent>>
}
```

Again, the compiler will ask us to implement missing methods, and we will be able to use similar refactoring steps to move logic as before.

*NotStartedGame* only responds to the *JoinGame* command.

```kotlin {caption="Moving command execution to NotStartedGame"}
data object NotStartedGame : Game {
  // …

  override fun execute(command: GameCommand): Either<GameError, NonEmptyList<GameEvent>> =
    when (command) {
      is JoinGame -> nonEmptyListOf(
        GameStarted(command.gameId, command.secret, command.totalAttempts, command.availablePegs)
      ).right()
            
      else -> GameNotStarted(command.gameId).left()
    }
}
```

*StartedGame* enables us to make guesses. In the previous solution, we were not handling the case of someone trying to start an already-started game.
We'd simply start a new game again.

This is indicated by `TODO()` in the code below. Our solution here would be to either return an error or allow this to happen silently by returning no new events.
The latter would require us to change the signature to allow for returning an empty list of events.

```kotlin {caption="Moving command execution to StartedGame"}
data class StartedGame(
  private val secret: Code,
  private val attempts: Int,
  private val totalAttempts: Int,
  private val availablePegs: Set<Code.Peg>
) : Game {
  // …

  override fun execute(command: GameCommand): Either<GameError, NonEmptyList<GameEvent>> = when (command) {
    is MakeGuess -> validGuess(command).map { guess ->
      GuessMade(command.gameId, Guess(command.guess, feedbackOn(guess)))
    }.withOutcome()

    else -> TODO()
  }

  // …
}
```

Notice we no longer need to validate if the game is started since we're already in the *StartedGame* state.

Furthermore, we can lower the visibility of all the properties to be private. Nothing outside depends on them.
In fact, nothing outside depends on any specific implementation of *Game*.

Many of our extension functions can be now promoted to private instance methods. The full class is hidden below.

<details>
<summary>Full StartedGame example</summary>

```kotlin {caption="Moving command execution to StartedGame (full example)"}

data class StartedGame(
  private val secret: Code,
  private val attempts: Int,
  private val totalAttempts: Int,
  private val availablePegs: Set<Code.Peg>
) : Game {
  private val secretLength: Int = secret.length

  private val secretPegs: List<Code.Peg> = secret.pegs

  override fun applyEvent(event: GameEvent): Game = when (event) {
    is GameStarted -> this
    is GuessMade -> this.copy(attempts = this.attempts + 1)
    is GameWon -> WonGame
    is GameLost -> LostGame
  }

  override fun execute(command: GameCommand): Either<GameError, NonEmptyList<GameEvent>> = when (command) {
    is MakeGuess -> validGuess(command).map { guess ->
      GuessMade(command.gameId, Guess(command.guess, feedbackOn(guess)))
    }.withOutcome()

    else -> TODO()
  }

  private fun validGuess(command: MakeGuess): Either<GameError, Code> {
    if (isGuessTooShort(command.guess)) {
      return GuessTooShort(command.gameId, command.guess, secretLength).left()
    }
    if (isGuessTooLong(command.guess)) {
      return GuessTooLong(command.gameId, command.guess, secretLength).left()
    }
    if (!isGuessValid(command.guess)) {
      return InvalidPegInGuess(command.gameId, command.guess, availablePegs).left()
    }
    return command.guess.right()
  }

  private fun isGuessTooShort(guess: Code): Boolean = guess.length < secretLength

  private fun isGuessTooLong(guess: Code): Boolean = guess.length > secretLength

  private fun isGuessValid(guess: Code): Boolean = availablePegs.containsAll(guess.pegs)

  private fun feedbackOn(guess: Code): Feedback =
    feedbackPegsOn(guess)
      .let { (exactHits, colourHits) ->
        Feedback(outcomeFor(exactHits), exactHits + colourHits)
      }

  private fun feedbackPegsOn(guess: Code) =
    exactHits(guess).map { BLACK } to colourHits(guess).map { WHITE }

  private fun outcomeFor(exactHits: List<Feedback.Peg>) = when {
    exactHits.size == this.secretLength -> WON
    this.attempts + 1 == this.totalAttempts -> LOST
    else -> IN_PROGRESS
  }

  private fun exactHits(guess: Code): List<Code.Peg> = this.secretPegs
    .zip(guess.pegs)
    .filter { (secretColour, guessColour) -> secretColour == guessColour }
    .unzip()
    .second

  private fun colourHits(guess: Code): List<Code.Peg> = this.secretPegs
    .zip(guess.pegs)
    .filter { (secretColour, guessColour) -> secretColour != guessColour }
    .unzip()
    .let { (secret, guess) ->
      guess.fold(secret to emptyList<Code.Peg>()) { (secretPegs, colourHits), guessPeg ->
        secretPegs.remove(guessPeg)?.let { it to colourHits + guessPeg } ?: (secretPegs to colourHits)
      }.second
    }

    private fun Either<GameError, GuessMade>.withOutcome(): Either<GameError, NonEmptyList<GameEvent>> =
      map { event ->
        nonEmptyListOf<GameEvent>(event) +
          when (event.guess.feedback.outcome) {
            WON -> listOf(GameWon(event.gameId))
            LOST -> listOf(GameLost(event.gameId))
            else -> emptyList()
          }
        }
      }
```
</details>

Finally, our terminal states do not expect any further commands and respond with errors.

```kotlin {caption="Moving command execution to WonGame and LostGame"}
data object WonGame : Game {
  // …

  override fun execute(command: GameCommand): Either<GameError, NonEmptyList<GameEvent>> =
    GameAlreadyWon(command.gameId).left()
}

data object LostGame : Game {
  // …

  override fun execute(command: GameCommand): Either<GameError, NonEmptyList<GameEvent>> =
    GameAlreadyLost(command.gameId).left()
  }
}
```

As before, we end up with behaviour for each state close to its type definition and data.
We could make all the properties **private** since nothing outside of our public methods needs to access them.
It wouldn't be terrible to keep them open though, since they're immutable.

## Usage

Let's consider how usage has changed since we've moved behaviours to state classes.

Previously, we were building the state by folding past events and applying them over and over to the state transitioned by each iteration.

```kotlin {caption="Building the state (before)"}
val game = events.fold(notStartedGame(), ::applyEvent)
```

That hasn't changed, except the function we now need to call is defined on the state object itself.
The dynamic dispatch mechanism will take care of delegating the call to the right implementation of *Game*.

```kotlin {caption="Building the state (after)"}
val game = events.fold(notStartedGame(), Game::applyEvent)
```

We now execute a command by sending the message to the game instance.

```kotlin {caption="Executing commands"}
game.execute(command)
```

To perform the refactoring we had to update tests shortly after adding a new method to the *Game* interface.
Here's one of the test cases that was updated to use the OOP way that demonstrates the new usage.

```kotlin {caption="An example test case"}
@Test
fun `it makes a guess`() {
  val command = MakeGuess(gameId, Code("Purple", "Purple", "Purple", "Purple"))
  val game = gameOf(GameStarted(gameId, secret, totalAttempts, availablePegs))

  game.execute(command) shouldSucceedWith listOf(
    GuessMade(
      gameId,
      Guess(Code("Purple", "Purple", "Purple", "Purple"), Feedback(IN_PROGRESS))
    )
  )
}

private fun gameOf(vararg events: GameEvent): Game = 
  events.toList().fold(notStartedGame(), Game::applyEvent)
```

## Summary

We experimented with refactoring our functional solution to be more object-oriented.
We ended up with a domain model that's closer to what we're used to when practising OOP,
since all the data is now private and behaviours are implemented as instance methods.
In some way, it's still functional, but it does take advantage of some object-oriented properties like encapsulation or polymorphism.

The **functional** solution makes it easier to add **new behaviours** without modifying **existing types**.

The **object-oriented** solution makes it easier to add **new types** without modifying **existing behaviours**.

Next time, we'll be leaving the realm of functional purity to take a look at how to feed events into the domain model and persist events that the model generates.

## Resources

* [Examples gist](https://gist.github.com/jakzal/1856418f8269c3d45948e681873b42df)

<!-- https://excalidraw.com/#json=cKVgrv9mYLKdLEWWg2h9i,0VHkqXpTBsfTyHzGOduhJg -->
