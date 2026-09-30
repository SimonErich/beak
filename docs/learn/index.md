---
title: Learn
description: Choose between the tutorial, the example tours and the concept pages, and the order to read them in.
type: index
audience: [beginner]
status: stable
---

# Learn

Beak has three ways in, and they answer different questions. The tutorial is for doing, the examples are for reading finished code, and the concepts are for understanding why the code is shaped the way it is. You do not need all three, and the order below is a suggestion.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Build a project and see each step run | [Tutorial](../tutorial/index.md) | Six chapters that grow a shop admin from an empty folder to a signed-in panel with tests and builds |
| Read finished, tested code for a feature | [Examples](../examples/index.md) | Five runnable projects and a feature map, compared by domain, ports, auth and run command |
| Understand the reason behind a design | [Concepts](../concepts/index.md) | Eight pages on the one-definition promise, the four layers, where authority lives and how data flows |

## A suggested order

Start with the [quickstart](../start-here/quickstart.md) if you have not seen Beak run. It takes about ten minutes and gives you the smallest project.

Then do the tutorial, which is the only path that has you write a schema, a resource, a policy and a test yourself. It assumes nothing about Beak and a little about Dart and Flutter. Each chapter ends at a checkpoint where the project runs, so a break between chapters costs nothing.

Read a concept page when a step made you ask why. [Declarative resources](../concepts/declarative-resources.md) and [The one-definition promise](../concepts/the-one-definition-promise.md) explain the bet the framework is built on, and [Where authority lives](../concepts/where-authority-lives.md) explains why the server, and not the panel, has the last word.

Open an example when you want to see a feature in a whole project. The [Clean shop](../examples/clean-shop.md) is the one the tutorial was cut from, and the [Feature map](../examples/feature-map.md) says which file demonstrates what.

## When to skip this section

If you already know what you want to build, the guides answer how. [Defining models](../models/defining-models.md) is where a schema starts, and the [Choose your path](../start-here/paths/index.md) pages route you by what you already have: a database, a Flutter app, a Serverpod project or a backend.

## Continue reading

- [Tutorial](../tutorial/index.md): the six chapters, with what each one builds.
- [Examples](../examples/index.md): five projects to run and read.
- [Concepts](../concepts/index.md): the reasons behind the shape of Beak.
