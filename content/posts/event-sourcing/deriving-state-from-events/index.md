---
title: "Deriving state from events"
date: "2023-11-10T14:27:31Z"
draft: true
series: ["Event Sourcing"]
tags: ["kotlin", "event sourcing", "ddd", "functional programming"]
keywords: ["kotlin", "event sourcing", "functional event sourcing", "ddd", "functional programming", "domain-driven design", "dddesign", "decider"]
cover:
  image: "deriving-state-cover.svg"
  alt: "Deriving state from events"
summary: In event sourcing, the state is derived from events that have happened in the past. In a classic approach, state is persisted while events are lost. In an event-sourced system, it's the events that are persisted while state is derived.
---

> [!SERIES] This article is part of the [event sourcing](/series/event-sourcing/) series:
>
> * [Functional domain model](/functional-domain-model/)
> * [Functional event sourcing](/functional-event-sourcing/)
> * [Functional event sourcing example in Kotlin](/functional-event-sourcing-example-in-kotlin/)
> * Deriving state from events
> * [Object-Oriented event sourcing](/object-oriented-event-sourcing/)

<!-- https://excalidraw.com/#json=Zj0nAE-GM5t2HbSZvUXUw,Uo9_JZCoQBFXPrzv0AjGFw -->