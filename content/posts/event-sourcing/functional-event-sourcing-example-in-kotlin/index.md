---
title: "Functional event sourcing example in Kotlin"
date: "2023-11-03T14:07:56Z"
draft: false
series: ["Event Sourcing"]
series_weight: 3
tags: ["kotlin", "event sourcing", "ddd", "functional programming", "event modeling"]
keywords: ["kotlin", "event sourcing", "functional event sourcing", "ddd", "functional programming", "domain-driven design", "dddesign", "decider", "event modeling"]
cover:
  image: "mastermind-game.png"
  alt: "Mastermind game implemented with event sourcing"
summary: Let's implement the Mastermind game with event sourcing. For now, we're only focusing on the domain model.
---

Last time we discussed a [functional modeling approach to event sourcing](/functional-event-sourcing/).
Let's now consider an implementation example in Kotlin.

> [!SERIES] This article is part of the [event sourcing](/series/event-sourcing/) series:
>
> * [Functional domain model](/functional-domain-model/)
> * [Functional event sourcing](/functional-event-sourcing/)
> * Functional event sourcing example in Kotlin
> * [Deriving state from events](/deriving-state-from-events/)
> * [Object-Oriented event sourcing](/object-oriented-event-sourcing/)

The problem we'll be working with is the [Mastermind game](https://github.com/jakzal/mastermind).
If you're unfamiliar with the game, you can learn about it from Wikipedia or this [GitHub repository](https://github.com/jakzal/mastermind).

As before, we're still only focusing on the domain model.

{{< figure src="domain-command-handler.svg" caption="Domain command handler" >}}

We're interested in the behaviour and types of the `execute()` function that we discussed in the [previous post](/functional-event-sourcing/).
Here's how the function signature will look like for our game:

```kotlin {caption="Domain command handler"}
fun execute(command: GameCommand, game: Game): Either<GameError, NonEmptyList<GameEvent>>
  = TODO()
```

> [!NOTE]
> The solution presented here has been developed with TDD. However, our goal now is to show the final solution rather than how we have arrived at it with refactoring.
> This is an important note, as I wouldn't like to introduce confusion that what we do here is TDD. TDD is better shown in videos than in the written word.
>
> Furthermore, since we've started the series with the model, it might appear as if we're working inside-out.
> In practice, it's usually the other way around. We work outside-in, starting at the boundaries of the system.

## Event model

Let's start with the output of an event modeling workshop to visualise what needs to be done.

> Event Modeling is a visual analysis technique that focuses heavily on identifying meaningful events happening in a business process.
{cite="https://www.goeleven.com/blog/event-modeling", caption="What is Event Modeling?"}

Diagrams below reveal the commands (blue), events (orange), and error cases (red) the Mastermind game might need.
We can also see the views (green), but we're not concerned with them on this occasion.

Playing the game means we join a new game and make guesses.

{{< figure src="mastermind-event-model-playing-game.svg" caption="Playing the game" alt="Mastermind game event model (playing the game)" >}}

Eventually, we might make a guess that matches the secret and win the game.

{{< figure src="mastermind-event-model-winning-game.svg" caption="Winning the game" alt="Mastermind game event model (winning the game)" >}}

Or, we might run out of available attempts and lose the game.

{{< figure src="mastermind-event-model-losing-game.svg" caption="Losing the game" alt="Mastermind game event model (losing the game)" >}}

There are also several scenarios where our guess might be rejected:

* Guess too long
* Guess too short
* Invalid peg in the guess
* Game already won
* Game already lost
* Game was not started

{{< figure src="mastermind-event-model-error-scenarios.svg" caption="Error scenarios" alt="Mastermind game event model (error scenarios)" >}}

### Commands

In the event modeling workshop, we have identified two commands: `JoinGame` and `MakeGuess`.

{{< figure src="mastermind-game-commands.svg" caption="Mastermind game commands" >}}

Commands are implemented as [data classes](https://kotlinlang.org/docs/data-classes.html) with immutable properties.
What's common between the two commands is a game identifier.

```kotlin {caption="Mastermind game commands implementation"}
sealed interface GameCommand {
    val gameId: GameId

    data class JoinGame(
        override val gameId: GameId,
        val secret: Code,
        val totalAttempts: Int,
        val availablePegs: Set<Code.Peg>
    ) : GameCommand

    data class MakeGuess(
      override val gameId: GameId,
      val guess: Code
    ) : GameCommand
}
```

All the commands that are handled by the same aggregate implement the same sealed interface.
Later we'll use the same pattern with events and errors.

> [!NOTE]
> Isn't it curious how I continue to use the term "aggregate" while there's no single entity that represents the aggregate?
> I like to think that, conceptually, the aggregate is still there.
> It's represented by commands, events, and the behaviour of the `execute()` function.

The key benefit of [sealed types](https://kotlinlang.org/docs/sealed-classes.html#sealed-classes-and-when-expression)
comes into play with the [`when`](https://kotlinlang.org/docs/control-flow.html#when-expression) expression and exhaustive matching:

```kotlin {caption="Exhaustive matching example"}
fun execute(command: GameCommand, game: Game) = when(command) {
  is JoinGame -> TODO()
  is MakeGuess -> TODO()
}
```

Notice there's no *else* branch in the above example. Since our type is sealed we can be sure we covered all the possible cases.
The compiler will tell us otherwise.

If we ever add a new command implementation, the compiler will point out all the places we matched on the command that need to be updated with the new branch.

### Events

In the workshop, we have also identified four events: `GameStarted`, `GuessMade`, `GameWon`, and `GameLost`.
*GameStarted* will only be published in the beginning, while *GameWon* and *GameLost* are our terminal events.

{{< figure src="mastermind-game-events.svg" caption="Mastermind game events" >}}

Similarly to commands, we use a sealed interface to implement all the events.

```kotlin {caption="Mastermind game events implementation"}
sealed interface GameEvent {
    val gameId: GameId

    data class GameStarted(
        override val gameId: GameId,
        val secret: Code,
        val totalAttempts: Int,
        val availablePegs: Set<Code.Peg>
    ) : GameEvent

    data class GuessMade(
        override val gameId: GameId,
        val guess: Guess
    ) : GameEvent

    data class GameWon(override val gameId: GameId) : GameEvent

    data class GameLost(override val gameId: GameId) : GameEvent
}
```

### Errors

To be honest, not all of these error cases were identified in the modeling workshop.
Many were discovered in the implementation phase and added to the diagram later.

{{< figure src="mastermind-game-errors.svg" caption="Mastermind game errors" >}}

Yet again, sealed interfaces come in handy. This time the hierarchy is a bit more nested.
This way we'll be able to perform a more fine-grained matching later on
when it comes to handling errors and converting them to responses.

```kotlin {caption="Mastermind game errors implementation"}
sealed interface GameError {
  val gameId: GameId

  sealed interface GameFinishedError : GameError {
    data class GameAlreadyWon(
      override val gameId: GameId
    ) : GameFinishedError

    data class GameAlreadyLost(
      override val gameId: GameId
    ) : GameFinishedError
  }

  sealed interface GuessError : GameError {
    data class GameNotStarted(
      override val gameId: GameId
    ) : GuessError

    data class GuessTooShort(
      override val gameId: GameId,
      val guess: Code,
      val requiredLength: Int
    ) : GuessError

    data class GuessTooLong(
      override val gameId: GameId,
      val guess: Code,
      val requiredLength: Int
    ) : GuessError

    data class InvalidPegInGuess(
      override val gameId: GameId,
      val guess: Code,
      val availablePegs: Set<Code.Peg>
    ) : GuessError
  }
}
```

### Other domain types

Notice how we tend to avoid primitive types in our commands, events, and errors.

{{< figure src="mastermind-game-other-types.svg" caption="Other domain types supporting commands, events, and errors" >}}

Rich types help us to express our domain better and prevent us from making simple mistakes (i.e. is this string a game ID or a player ID?).

```kotlin {caption="Implementation of remaining domain types"}
@JvmInline
value class GameId(val value: String)

data class Code(val pegs: List<Peg>) {
  constructor(vararg pegs: String) : this(pegs.map(::Peg))

  data class Peg(val name: String)
 
  val length: Int get() = pegs.size
}

data class Guess(val code: Code, val feedback: Feedback)

data class Feedback(val outcome: Outcome, val pegs: List<Peg>) {
  constructor(outcome: Outcome, vararg pegs: Peg) :
    this(outcome, pegs.toList())

  enum class Peg { BLACK, WHITE }

  enum class Outcome { IN_PROGRESS, WON, LOST }
}
```

## Behaviours

With the right workshop, we can discover a lot of types and behaviours upfront.
It's nearly impossible to think of everything upfront though.
We fear not, as when it comes to the implementation, the tests we write tend to guide us and fill in the gaps.

### Joining the game

Joining the game should result in the *GameStarted* event.

{{< figure src="mastermind-join-game.svg" caption="Joining the game" >}}

Test cases for domain model behaviours could not be simpler.
We need to arrange fixtures, execute the tested behaviour, and verify the outcome.
The good old Arrange/Act/Assert, a.k.a Given/When/Then.
Meszaros calls it a [four-phase test](http://xunitpatterns.com/Four%20Phase%20Test.html), but in our case,
the fourth phase will be implicitly done by the test framework and there's nothing left to tear down.

{{< figure src="four-phase-test.svg" caption="Four-phase test" >}}

Since we planned for our domain model to be purely functional, it's easy to stick to this structure to keep the tests short and readable.

In the test case below, the [test fixture](http://xunitpatterns.com/test%20fixture%20-%20xUnit.html) (test context)
is defined as properties of the test class.
The test case creates the command, executes it, and verifies we got the expected events in response.
This is how all our tests for the domain model will look like.

```kotlin {caption="Test case for joining the game"}
class GameExamples {
  private val gameId = anyGameId()
  private val secret = Code("Red", "Green", "Blue", "Yellow")
  private val totalAttempts = 12
  private val availablePegs = setOfPegs("Red", "Green", "Blue", "Yellow", "Purple", "Pink")

  @Test
  fun `it starts the game`() {
    val command = JoinGame(gameId, secret, totalAttempts, availablePegs)

    execute(command) shouldSucceedWith listOf(
      GameStarted(gameId, secret, totalAttempts, availablePegs)
    )
  }
}
```

The actual result of *execute()* is of type `Either<GameError, NonEmptyList<GameEvent>>`,
so when verifying the outcome we need to confirm whether we received the left or the right side of it.
*Left* is by convention used for the error case, while *Right* is for success.

{{< figure src="arrow-either-type.svg" caption="Either a GameError or a list of GameEvents" >}}

I also created the `shouldSucceedWith()` and `shouldFailWith()` extension functions in the hope of removing some noise from the tests.


```kotlin {caption="Custom assertions"}
infix fun <A, B> Either<A, B>.shouldSucceedWith(expected: B) =
  assertEquals(expected.right(), this, "${expected.right()} is $this")

infix fun <A, B> Either<A, B>.shouldFailWith(expected: A) =
  assertEquals(expected.left(), this, "${expected.left()} is $this")
```

> [!NOTE]
> Read more about [Either](https://arrow-kt.io/learn/typed-errors/either-and-ior/) and [typed errors](https://arrow-kt.io/learn/typed-errors/) in Arrow's documentation.

Since for this first case, there are no error scenarios or any complex calculations, we only need to return a list with the *GameStarted* event inside.
Matching the command with `when()` gives us access to command properties for the matched type thanks to smart casts.

```kotlin {caption="Starting the game"}
typealias Game = List<GameEvent>

fun notStartedGame(): Game = emptyList()

fun execute(
  command: GameCommand,
  game: Game = notStartedGame()
): Either<GameError, NonEmptyList<GameEvent>> = when (command) {
  is JoinGame -> joinGame(command)
  is MakeGuess -> TODO()
}

private fun joinGame(command: JoinGame) = either<Nothing, NonEmptyList<GameStarted>> { 
  nonEmptyListOf(
    GameStarted(
      command.gameId, command.secret, command.totalAttempts, command.availablePegs
    )
  )
}
```

Notice the `either {}` [builder](https://arrow-kt.io/learn/typed-errors/either-and-ior/#using-builders) above.
It makes sure the value we return from its block is wrapped in an instance of `Either`, in this case, the `Right` instance.
`either { nonEmptyListOf(GameStarted())) }` is an equivalent of  `nonEmptyListOf(GameStarted())).right()`.

### Making a guess

Making a valid guess should result in the *GuessMade* event.

{{< figure src="mastermind-make-guess.svg" caption="Making a guess" >}}

This time, we additionally need to prepare the state of the game, since *MakeGuess* is never executed as the first command.
The game must've been started first.

```kotlin {caption="Test case for making a guess"}
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
```

The state is created based on past events. We delegated this task to the `gameOf()` function.
Since for now, we treat the list of events as the state, we only need to return the list.
Later on, we'll see how to convert it to an actual state object.

```kotlin {caption="Creating the game state"}
fun gameOf(vararg events: GameEvent): Game = listOf(*events)
```

Now we need to return the *GuessMade* event for the second `when()` branch.

```kotlin {caption="Making a guess"}
fun execute(
  command: GameCommand,
  game: Game = notStartedGame()
): Either<GameError, NonEmptyList<GameEvent>> = when (command) {
  is JoinGame -> joinGame(command)
  is MakeGuess -> makeGuess(command, game)
}

private fun makeGuess(command: MakeGuess, game: Game) =
  either<GameError, NotEmptyList<GuessMade>> {
    nonEmptyListOf(
      GuessMade(command.gameId, Guess(command.guess, game.feedbackOn(command.guess)))
    )
  }

private fun Game.feedbackOn(guess: Code) = Feedback(IN_PROGRESS)
```

### Receiving feedback

Feedback should be given on each valid guess with the *GuessMade* event.

{{< figure src="mastermind-make-guess.svg" caption="Receiving feedback on the guess" >}}

Here's one of the test cases for receiving feedback.

```kotlin {caption="Test case for receiving feedback"}
fun `it gives feedback on the guess`() { 
  val secret = Code("Red", "Green", "Blue", "Yellow")
  val guess = Code("Red", "Purple", "Blue", "Purple")
  val game = gameOf(GameStarted(gameId, secret, totalAttempts, availablePegs))

  execute(MakeGuess(gameId, guess), game) shouldSucceedWith listOf(
    GuessMade(gameId, Guess(guess, Feedback(IN_PROGRESS, BLACK, BLACK)))
  )
}
```

We'll need a few more similar test cases to develop the logic for giving feedback. They're hidden below if you're interested.

<details>
<summary>Receiving feedback test cases</summary>

```kotlin {caption="All test cases for receiving feedback"}
@TestFactory
fun `it gives feedback on the guess`() = guessExamples { (secret: Code, guess: Code, feedback: Feedback) ->
  val game = gameOf(GameStarted(gameId, secret, totalAttempts, availablePegs))

  execute(MakeGuess(gameId, guess), game) shouldSucceedWith listOf(
    GuessMade(gameId, Guess(guess, feedback))
  )
}

private fun guessExamples(block: (Triple<Code, Code, Feedback>) -> Unit) = mapOf(
  "it gives a black peg for each code peg on the correct position" to Triple(
    Code("Red", "Green", "Blue", "Yellow"),
    Code("Red", "Purple", "Blue", "Purple"),
    Feedback(IN_PROGRESS, BLACK, BLACK)
  ),
  "it gives no black peg for code peg duplicated on a wrong position" to Triple(
    Code("Red", "Green", "Blue", "Yellow"),
    Code("Red", "Red", "Purple", "Purple"),
    Feedback(IN_PROGRESS, BLACK)
  ),
  "it gives a white peg for code peg that is part of the code but is placed on a wrong position" to Triple(
    Code("Red", "Green", "Blue", "Yellow"),
    Code("Purple", "Red", "Purple", "Purple"),
    Feedback(IN_PROGRESS, WHITE)
  ),
  "it gives no white peg for code peg duplicated on a wrong position" to Triple(
    Code("Red", "Green", "Blue", "Yellow"),
    Code("Purple", "Red", "Red", "Purple"),
    Feedback(IN_PROGRESS, WHITE)
  ),
  "it gives a white peg for each code peg on a wrong position" to Triple(
    Code("Red", "Green", "Blue", "Red"),
    Code("Purple", "Red", "Red", "Purple"),
    Feedback(IN_PROGRESS, WHITE, WHITE)
  )
).dynamicTestsFor(block)

fun <T : Any> Map<String, T>.dynamicTestsFor(block: (T) -> Unit) =
  map { (message, example: T) -> DynamicTest.dynamicTest(message) { block(example) } }
```
</details>

Eventually, I arrived at the solution below.

```kotlin {caption="Calculating feedback on the guess"}
private fun Game.feedbackOn(guess: Code): Feedback =
  feedbackPegsOn(guess).let { (exactHits, colourHits) -> 
    Feedback(IN_PROGRESS, exactHits + colourHits)
  }

private fun Game.feedbackPegsOn(guess: Code) =
  exactHits(guess).map { BLACK } to colourHits(guess).map { WHITE }
```

I've hidden `Game.exactHits()` and `Game.colourHits()` below as they're not necessarily relevant.
The point is we identify pegs on the correct and incorrect positions and convert them to BLACK and WHITE pegs respectively.

<details>
<summary>Exact hits and colour hits</summary>

```kotlin {caption="Detailed calculations of exact and colour hits"}
private fun Game.exactHits(guess: Code): List<Code.Peg> = 
  this.secretPegs
    .zip(guess.pegs)
    .filter { (secretColour, guessColour) -> secretColour == guessColour }
    .unzip()
    .second

private fun Game.colourHits(guess: Code): List<Code.Peg> =
  this.secretPegs
    .zip(guess.pegs)
    .filter { (secretColour, guessColour) -> secretColour != guessColour }
    .unzip()
    .let { (secret, guess) ->
        guess.fold(secret to emptyList<Code.Peg>()) { (secretPegs, colourHits), guessPeg ->
            secretPegs.remove(guessPeg)?.let { it to colourHits + guessPeg } ?: (secretPegs to colourHits)
        }.second
    }

/**
 * Removes an element from the list and returns the new list, or null if the element wasn't found.
 */
private fun <T> List<T>.remove(item: T): List<T>? = indexOf(item).let { index ->
    if (index != -1) filterIndexed { i, _ -> i != index }
    else null
}
```
</details>

What's more interesting is how we accessed the state of the game - namely the secret code and its pegs.
The secret is available with the first *GameStarted* event.
Since we have access to the whole event history for the given game, we could filter it for the information we need.
We achieved it with extension functions on the `Game` type (which is actually a `List<GameEvent>` for now).

```kotlin {caption="Deriving state properties"}
private val Game.secret: Code?
    get() = filterIsInstance<GameStarted>().firstOrNull()?.secret

private val Game.secretPegs: List<Code.Peg>
    get() = secret?.pegs ?: emptyList()
```

### Enforcing invariants

> invariants: rules that have to be protected at all times
{cite="https://learning.oreilly.com/library/view/learning-domain-driven-design/9781098100124/" caption="\"Learning Domain-Driven Design\" by Vladik Khononov."}

{{< figure src="mastermind-make-guess-failure.svg" caption="Rejecting a command" >}}

Commands that might put our game in an inconsistent state should be rejected.
For example, we can't make a guess for a game that hasn't started or has finished.
Also, guesses with a code that's of a different length to the secret are incomplete.
Finally, we can't make guesses with pegs that are not part of the game.

> An invariant is a state that must stay transactionally consistent throughout the Entity life cycle.
{cite="https://learning.oreilly.com/library/view/implementing-domain-driven-design/9780133039900/" caption="\"Implementing Domain-Driven Design\" by Vaughn Vernon"}

#### Game not started

The game should not be played if it has not been started.

```kotlin {caption="Test case for game not started"}
@Test
fun `the game cannot be played if it was not started`() {
  val code = Code("Red", "Purple", "Red", "Purple")
  val game = notStartedGame()

  execute(MakeGuess(gameId, code), game) shouldFailWith GameNotStarted(gameId)
}
```

Our approach to validate an argument is to pass it to a validation function that returns the validated value or an error.
That's the job for `startedNotFinishedGame()` below. Once the game is returned from the validation function,
we can be sure that it was started. We can then pass it to the next function with `map()`.
In case of an error, *map* will short-circuit by returning the error, and the next function won't be called.

```kotlin {caption="Validating if the game is started"}
private fun makeGuess(command: MakeGuess, game: Game) =
  startedNotFinishedGame(command, game).map { startedGame ->
    nonEmptyListOf(
      GuessMade(
        command.gameId,
        Guess(command.guess, startedGame.feedbackOn(command.guess))
      )
    )
  }

private fun startedNotFinishedGame(command: MakeGuess, game: Game): Either<GameError, Game> {
  if (!game.isStarted()) {
    return GameNotStarted(command.gameId).left()
  }
  return game.right()
}
```

```kotlin {caption="Deriving state properties for validation"}
private fun Game.isStarted(): Boolean = filterIsInstance<GameStarted>().isNotEmpty()
```

#### Guess is invalid

The guess code needs to be of the same length as the secret. Furthermore, it should only contain pegs that the game has been started with.

```kotlin {caption="Guess validation test cases"}
@Test
fun `the guess length cannot be shorter than the secret`() {
  val secret = Code("Red", "Green", "Blue", "Yellow")
  val code = Code("Purple", "Purple", "Purple")
  val game = gameOf(GameStarted(gameId, secret, 12, availablePegs))

  execute(MakeGuess(gameId, code), game) shouldFailWith 
    GuessTooShort(gameId, code, secret.length)
}

@Test
fun `the guess length cannot be longer than the secret`() {
  val secret = Code("Red", "Green", "Blue", "Yellow")
  val code = Code("Purple", "Purple", "Purple", "Purple", "Purple")
  val game = gameOf(GameStarted(gameId, secret, 12, availablePegs))

  execute(MakeGuess(gameId, code), game) shouldFailWith 
    GuessTooLong(gameId, code, secret.length)
}

@Test
fun `it rejects pegs that the game was not started with`() {
  val secret = Code("Red", "Green", "Blue", "Blue")
  val availablePegs = setOfPegs("Red", "Green", "Blue")
  val game = gameOf(GameStarted(gameId, secret, 12, availablePegs))
  val guess = Code("Red", "Green", "Blue", "Yellow")

  execute(MakeGuess(gameId, guess), game) shouldFailWith
    InvalidPegInGuess(gameId, guess, availablePegs)
}
```

Here, we use the same trick with a validation function to validate the guess.
Notice we have to use `flatMap()` instead of `map()` in the outer call.
Otherwise an *Either* result would be placed inside another *Either*.

```kotlin {caption="Guess validation"}
private fun makeGuess(command: MakeGuess, game: Game) =
  startedNotFinishedGame(command, game).flatMap { startedGame ->
    validGuess(command, startedGame).map { guess ->
      nonEmptyListOf(
        GuessMade(
          command.gameId,
          Guess(command.guess, startedGame.feedbackOn(guess))
        )
      )
    }
  }

private fun validGuess(command: MakeGuess, game: Game): Either<GameError, Code> {
  if (game.isGuessTooShort(command.guess)) {
    return GuessTooShort(command.gameId, command.guess, game.secretLength).left()
  }
  if (game.isGuessTooLong(command.guess)) {
    return GuessTooLong(command.gameId, command.guess, game.secretLength).left()
  }
  if (!game.isGuessValid(command.guess)) {
    return InvalidPegInGuess(command.gameId, command.guess, game.availablePegs).left()
  }
  return command.guess.right()
}
```

```kotlin {caption="Deriving state properties for guess validation"}
private fun Game.isGuessTooShort(guess: Code): Boolean = guess.length < this.secretLength

private fun Game.isGuessTooLong(guess: Code): Boolean = guess.length > this.secretLength

private fun Game.isGuessValid(guess: Code): Boolean = availablePegs.containsAll(guess.pegs)
```

### Winning the game

Winning the game means publishing the *GameWon* event in addition to the usual *GuessMade*.

{{< figure src="mastermind-make-winning-guess.svg" caption="Winning the game" >}}

```kotlin {caption="Winning the game test case"}
@Test
fun `the game is won if the secret is guessed`() {
  val game = gameOf(GameStarted(gameId, secret, totalAttempts, availablePegs))

  execute(MakeGuess(gameId, secret), game) shouldSucceedWith listOf(
    GuessMade(gameId, Guess(secret, Feedback(WON, BLACK, BLACK, BLACK, BLACK))),
    GameWon(gameId)
  )
}
```

We now need to decide if the game is won based on whether the number of guessed pegs is equal to the secret length.

```kotlin {caption="Winning the game implementation"}
private fun Game.outcomeFor(exactHits: List<Feedback.Peg>) = when {
  exactHits.size == this.secretLength -> WON
  else -> IN_PROGRESS
}
```

Again, that requires a bit of state.

```kotlin {caption="Deriving state properties"}
private val Game.secretLength: Int
  get() = secret?.length ?: 0
```

We've taken care of deciding whether the game is won. We also need to publish an additional event.
To do this, we make `makeGuess()` return a single event.
Next, we create the `withOutcome()` function that converts the result of `makeGuess()` to a list and optionally appends the `GameWon` event.

```kotlin {caption="Determining the game-terminating events"}
fun execute(
    command: GameCommand,
    game: Game = notStartedGame()
): Either<GameError, NonEmptyList<GameEvent>> = when (command) {
  is JoinGame -> joinGame(command)
  is MakeGuess -> makeGuess(command, game).withOutcome()
}

private fun makeGuess(command: MakeGuess, game: Game) =
  startedNotFinishedGame(command, game).flatMap { startedGame ->
    validGuess(command, startedGame).map { guess ->
      GuessMade(command.gameId, Guess(command.guess, startedGame.feedbackOn(guess)))
    }
  }

private fun Either<GameError, GuessMade>.withOutcome(): Either<GameError, NonEmptyList<GameEvent>> =
  map { event ->
    nonEmptyListOf<GameEvent>(event) + when (event.guess.feedback.outcome) {
      WON -> listOf(GameWon(event.gameId))
      LOST -> listOf(GameLost(event.gameId))
      else -> emptyList()
    }
  }
```

Once the game is won it shouldn't be played anymore.

```kotlin {caption="Test case for playing a won game"}
@Test
fun `the game can no longer be played once it's won`() {
  val game = gameOf(GameStarted(gameId, secret, totalAttempts, availablePegs))

  val update = execute(MakeGuess(gameId, secret), game)
  val updatedGame = game.updated(update)

  execute(MakeGuess(gameId, secret), updatedGame) shouldFailWith GameAlreadyWon(gameId)
}

private fun Game.updated(update: Either<GameError, Game>): Game = this + update.getOrElse { emptyList() }
```

This requires an additional validation rule.

```kotlin {caption="Validation for a won game"}
private fun startedNotFinishedGame(command: MakeGuess, game: Game): Either<GameError, Game> {
  if (!game.isStarted()) {
    return GameNotStarted(command.gameId).left()
  }
  if (game.isWon()) {
    return GameAlreadyWon(command.gameId).left()
  }
  return game.right()
}
```

The game is won if there has been a *GameWon* event published.

```kotlin {caption="Deriving state properties"}
private fun Game.isWon(): Boolean = filterIsInstance<GameWon>().isNotEmpty()
```

### Losing the game

Losing the game means publishing the *GameLost* event in addition to the usual *GuessMade*.

{{< figure src="mastermind-make-losing-guess.svg" caption="Losing the game" >}}

```kotlin {caption="Test case for losing the game"}
@Test
fun `the game is lost if the secret is not guessed within the number of attempts`() {
  val secret = Code("Red", "Green", "Blue", "Yellow")
  val wrongCode = Code("Purple", "Purple", "Purple", "Purple")
  val game = gameOf(
    GameStarted(gameId, secret, 3, availablePegs),
    GuessMade(gameId, Guess(wrongCode, Feedback(IN_PROGRESS))),
    GuessMade(gameId, Guess(wrongCode, Feedback(IN_PROGRESS))),
  )

  execute(MakeGuess(gameId, wrongCode), game) shouldSucceedWith listOf(
    GuessMade(gameId, Guess(wrongCode, Feedback(LOST))),
    GameLost(gameId)
  )
}
```

We now need to decide if the game is lost based on whether we have run out of attempts.

```kotlin {caption="Outcome calculation for a lost game"}
private fun Game.outcomeFor(exactHits: List<Feedback.Peg>) = when {
  exactHits.size == this.secretLength -> WON
  this.attempts + 1 == this.totalAttempts -> LOST
  else -> IN_PROGRESS
}
```

The following state-accessing functions turned out to be handy for this task.

```kotlin {caption="Deriving state properties"}
private val Game.attempts: Int
  get() = filterIsInstance<GuessMade>().size

private val Game.totalAttempts: Int
  get() = filterIsInstance<GameStarted>().firstOrNull()?.totalAttempts ?: 0
```

One last rule is that we cannot continue playing a lost game.

```kotlin {caption="Test case for playing a lost game"}
@Test
fun `the game can no longer be played once it's lost`() {
  val secret = Code("Red", "Green", "Blue", "Yellow")
  val wrongCode = Code("Purple", "Purple", "Purple", "Purple")
  val game = gameOf(GameStarted(gameId, secret, 1, availablePegs))

  val update = execute(MakeGuess(gameId, wrongCode), game)
  val updatedGame = game.updated(update)

  execute(MakeGuess(gameId, secret), updatedGame) shouldFailWith GameAlreadyLost(gameId)
}
```

One more condition in the validation function will do the job.

```kotlin {caption="Validation for a lost game"}
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

The game is lost if there has been a *GameLost* event published.

```kotlin {caption="Deriving state properties"}
private fun Game.isLost(): Boolean = filterIsInstance<GameLost>().isNotEmpty()
```

## Summary

I explained the implementation details of an event-sourced functional domain model in Kotlin.
In the process, I attempted to show how straightforward testing of such a model can be and how it doesn't require any dedicated testing techniques or tools.
The model itself, on the other hand, remains a rich core of business logic.

Hopefully, dear reader, you found it useful.

If you prefer to see a full example in one place, here's the gist: https://gist.github.com/jakzal/3f0ee968fe8073ee81e328ecbd59fe8b

Next time, we'll [continue the example](/deriving-state-from-events/) by replacing extension functions that derive state with an actual state data class.

## References

* [Mastermind game rules](https://github.com/jakzal/mastermind)
* [What is Event Modeling? (with example)](https://www.goeleven.com/blog/event-modeling/) by Yves Goeleven
* [CQRS](https://martinfowler.com/bliki/CQRS.html) by Martin Fowler
* [Learning Domain-Driven Design](https://www.goodreads.com/book/show/59383590-learning-domain-driven-design) by Vladik Khononov.
* [Implementing Domain-Driven Design](https://www.goodreads.com/book/show/15756865-implementing-domain-driven-design) by Vaughn Vernon
* [Functional Programming Ideas for the Curious Kotliner](https://leanpub.com/fp-ideas-kotlin) by Alejandro Serrano Mena
* [Typed errors](https://arrow-kt.io/learn/typed-errors/) in Arrow documentation
* [Mastermind game example gist](https://gist.github.com/jakzal/3f0ee968fe8073ee81e328ecbd59fe8b)

<!-- https://excalidraw.com/#json=rju9Iu6gMyvJ4oEkdx-dZ,aX6qsRZIVZMfZGlsQ8zhJw -->
<!-- https://excalidraw.com/#json=upjDmsImu808Epsf0248J,1ktAfWg4rkNbKQeOf-r5mA -->
