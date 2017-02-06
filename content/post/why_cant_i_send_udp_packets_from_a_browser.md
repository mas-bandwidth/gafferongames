+++
categories = ["White papers"]
tags = ["networking"]
date = "2017-02-05"
title = "Why can't I send UDP packets from a browser?"
description = "A solution for enabling UDP in the web"
draft = false
+++

# Premise

In 2017 the most popular web games like [agar.io](http://agar.io) are effectively limited to networking via WebSockets over TCP. If a UDP equivalent of WebSockets could be standardized and incorporated into browsers, it would greatly improve the networking of these games.

# Background

Web browsers are built on top of HTTP, which is a stateless request/response protocol initially designed for serving static web pages. HTTP is built on top of TCP, which is a low-level protocol that guarantees all data arrives reliably, and in the same order it was sent. 

This has worked well for many years, but recently websites have become more interactive and poorly suited to the HTTP request/response paradigm. Rising to this challenge are modern web protocols like WebSockets, WebRTC, HTTP 2.0 and SPDY, which hold the potential greatly improve the interactivity of the web. 

Unfortunately, this new set of standards for web development don't provide what games need, or, provide it in a form that is too complicated for game developers to use.

This leads to frustration from game developers, who just want to be able to send UDP packets from the browser.

# The Problem

TCP is a reliable ordered protocol. 

To deliver packets reliably and in order under packet loss, it is necessary to hold more recent packet in a queue, while waiting for dropped packets to be resent. Otherwise, data would be delivered out of order.

This is called head of line blocking and it causes problems for multiplayer games, because games are networked not by request/response or by exchanging events, but by sending time series data like player input and the state of objects in the world.

This creates a frustrating and almost comedically tragic problem for game developers. The most recent data they want is delayed while waiting for old data to be resent, data that by the time it arrives, is too old to be used.

Unfortunately, there is no way to fix this behavior under TCP. All data must be received reliably and in-order. Therefore, the standard solution in the game industry for the past 20 years has been to send game data over UDP instead. 

How this works in practice is that each game develops their own custom protocol on top of UDP, implementing basic reliability as required, while sending the majority of data as unreliable unordered. This ensures that time series data arrives as quickly as possible without waiting for dropped packets to be resent.

So what does this have to do with web games?

The key problem for web games today is that game developers have no way to do this best practice in the browser. Web games are forced to send their game data over TCP. Therefore, when packet loss and latency exist, web games have hitches and non-responsiveness because their game data is subject to head of line blocking.

This is completely unnecessary and could be fixed overnight if web games had some way to send and receive UDP packets.

# What about WebSockets?

...

# What about SPDY?

...

# What about WebRTC?

...

(insert headline here)

5. Straw Solution 1

a) Describe solution briefly (60 words)

b) Expert quote on why it doesn't work (70 words)

6. Straw Solution 2

a) Describe solution briefly (60 words)

b) Expert quote on why it doesn't work (70 words)

(insert headline here)

(here I would like to outline what the real solutino would look like? eg. connection based, ddos proof, authenticated, encrypted).

7. Introduce real solution

a) Explain what it is (70 words)

b) Explain why it is better than straw solution 1 and straw solution 2 (90 words)

c) Expert quote on why it's better.

(insert headline here)

8. Real solution addresses first major concern

a) introduce concern 1 (30 words)

b) how the real solution addresses it (90 words)

c) citation to support this (not possible...). replace with "how it works" section.

9. Real solution addresses second major concern 

a) introduce concern 2 (30 words)

b) how the real solution addresses it (90 words)

c) citation to support this (not possible!). replace with "how it works" section?

10. Real solution addresss third major concern 

a) introduce concern 3 (30 words)

b) how the real solution addresses it (90 words)

(insert headline here)

11. One example of a company or individual succeeding with the real solution (125 words). (not possible, this is a new thing. what to replace this with?)

(insert headline here)

12. 3 more advantages of real solution

a) advantage 1 (125 words)

b) advantage 2 (125 words)

c) advantage 3 (175 words) <--- make this the best advantage

Include a citation for the last advantage (25 words). (will this be possible? probably not)

13. Recap the problem / real solution argument (50 words)

14. About the author section (70 words)

a) Bob Smith in ____ (current title) at _____ (name of company) where here _____ (does something)

b) Prior to that he ___ (did something)

c) Bob is also _____ (another current thing you're doing).

d) (Name of company) provides ____ (whatever your company does)

e) Phone and email contact.





