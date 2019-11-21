+++
categories = ["Virtual Go"]
tags = ["physics","go/baduk/weiqi"]
date = "2013-02-18"
title = "Introduction to Virtual Go"
description = "My project to simulate a go board and stones"
draft = false
+++

## Introduction

Hi, I'm [Glenn Fiedler](https://gafferongames.com). Welcome to [**Virtual Go**](/categories/virtual-go/), my project to create a physically accurate computer simulation of a Go board and stones.

I'm a professional game programmer with 15 years experience in the game industry. Over the years I've worked for Irrational Games, Team Bondi, Pandemic Studios, Sony Santa Monica and most recently Respawn Entertainment. During my career I'm extremely proud to have worked on such games as 'Freedom Force', 'L.A. Noire', 'Journey', 'God of War: Ascension' and 'Titanfall'.

In my spare time I'm also an avid player of the board game [Go](https://en.wikipedia.org/wiki/Go_(game)).

<img src="/img/virtualgo/go-board-outside-cafe.jpg" width="100%"/></a>

A personal project I've always dreamed of combines the things I love: the game of Go, graphics programming, physics simulation and network programming.

The end result I hope to achieve is a beautiful real-time computer rendering of a go board and stones with photorealistic visuals and the laws of physics defining all interactions between the go stones and the board. To Go players reading this, yes, I do aim to reproduce that unique 'wobble' and feel you are familiar with when placing a stone on the board.

During the course of this article series I'm going to build this project entirely from scratch and include <u>you</u> in on all the details of building it as a tutorial. I believe in sharing knowledge and my hope is you can follow this project and understand the passion I bring to it and perhaps learn a few things along the way.

If you already play Go and want to get right in to the details of building the simulation, I would recommend skipping ahead to the next article in the series: [Shape Of The Go Stone](/post/shape_of_the_go_stone/).

Otherwise, if you would like a quick introduction to Go, please read on!

## The Game of Go

Go is a board game that originated in ancient China.

Today it is played worldwide but has a particularly strong following in China, Japan and Korea. It is not particularly well known in the West, although it has featured in popular culture in the movie "A Beautiful Mind".

<img src="/img/virtualgo/old-men-playing-go.jpg" width="100%"/></a>

Go is played on a grid with black and white stones. It is played by two people, each taking turns to place a stone of their color at one of the intersection points on the grid. Once placed on the board, stones do not move.

Each stone on the board has a number of liberties equal to the number of lines radiating out from it on the grid. A stone in the middle of the board has four liberties, a stone on the side has three, a stone in the corner has just two.

<img src="/img/virtualgo/go-board-liberties-9x9.jpg" width="100%"/></a>

If the opponent is able to surround all the liberties with stones of the opposite color, the stone is removed from the board.

<img src="/img/virtualgo/capture-stones-9x9.jpg" width="100%"/></a>

When stones of the same color are placed horizontally or vertically next to each other they become logically connected and form a "group" with its own set of liberties. For example, a group of two stones in the center has 6 liberties, while the same group on the side has only 4.

<img src="/img/virtualgo/go-board-group-of-two-liberties-9x9.jpg" width="100%"/></a>

A group may be captured if all of its liberties are blocked with stones of the opposite color. When a group is captured it is removed from the board as a unit.

<img src="/img/virtualgo/capture-groups-of-two-9x9.jpg" width="100%"/></a>

Of course it is not so easy to surround your opponents stones because they get to place stones too :)

For example, a single black stone in the center with just one liberty remaining is in a situation known as "Atari", but black can escape by extending to form a group of two stones. Now the black group has three liberties and can extend to create more liberties faster than they can be taken away.

<img src="/img/virtualgo/atari-run-away-9x9.jpg" width="100%"/></a>

It follows that it's not really possible to capture all of your opponents stones or for them to capture all of yours. Instead, you must coexist on the board with stones of the other color and find a way to surround more points of territory than your opponent.

It sounds simple but as you play Go you'll notice beautiful complexity emerging like a fractal: life and death - stones living even though surrounded, liberty races, seki or "dual life", the ladder, ko, the snapback, playing under the stones, the monkey jump, the bamboo joint, the tiger mouth.

So many beautiful properties from such simple rules. Truly an amazing game!

Please visit [The Interactive Way To Go](http://playgo.to/iwtg/en/) if you would like to learn more.

__NEXT ARTICLE:__ [Shape of The Go Stone](/post/shape_of_the_go_stone/)

----- 

**Glenn Fiedler** is the founder and CEO of **[Network Next](https://networknext.com)**.<br><i>Network Next is fixing the internet for games by creating a marketplace for premium network transit.</i>
