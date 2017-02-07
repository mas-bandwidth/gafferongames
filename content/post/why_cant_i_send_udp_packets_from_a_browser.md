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

Web browsers are built on top of HTTP, which is a stateless request/response protocol initially designed for serving static web pages. HTTP is built on top of TCP, which is a low-level protocol that guarantees that all data arrives reliably, and in the same order it was sent. 

This has worked well for many years, but recently websites have become more interactive and poorly suited to the HTTP request/response paradigm. Rising to this challenge are modern web protocols like WebSockets, WebRTC, HTTP 2.0 and QUIC, which hold the potential to greatly improve the interactivity of the web. 

Unfortunately, this new set of standards for web development don't provide what multiplayer games need, or, provide it in a form that is too complicated for game developers to use.

This leads to frustration from game developers, who just want to be able to send UDP packets from the browser.

# The Problem

TCP is a reliable-ordered protocol.

To deliver data reliably and in order under packet loss, it is necessary to hold more recent packet data in a queue while waiting for dropped packets to be resent. Otherwise, data would be delivered out of order.

This is called **head of line blocking** and it causes problems for multiplayer games, because games are networked not by request/response or by exchanging events, but by rapidly sending time series data like player input and the state of objects in the world.

This creates a frustrating and almost comedically tragic problem for game developers. The most recent data they want is delayed while waiting for old data to be resent. By the time the resent data finally arrives, it is too old to be used!

Unfortunately, there is no way to fix this behavior under TCP. All data must be received reliably and in-order. Therefore, the standard solution in the game industry for the past 20 years has been to send game data over UDP instead. 

How this works in practice is that each game develops their own custom protocol on top of UDP, implementing basic reliability as required, while sending the majority of data as unreliable-unordered. This ensures that time series data arrives as quickly as possible without waiting for dropped packets to be resent.

So, what does this have to do with web games?

The key problem for web games today is that game developers have no way to follow this best practice in the browser. Instead, web games are forced to send their game data over TCP, causing hitches and non-responsiveness due to head of line blocking.

This is completely unnecessary and could be fixed overnight if web games had some way to send and receive UDP packets.

# What about WebSockets?

WebSockets are an extension to the HTTP protocol which upgrade a HTTP connection so that data can be exchanged bidirectionally, rather than in the traditional request/response pattern. As of 2017, it's well supported across multiple browsers.

This elegantly solves the problem of websites that need to display dynamically changing content, because once a web socket connection is established, the server can push data to the browser without a corresponding request.

Unfortunately, since WebSockets are implemented on top of TCP, data is still subject to head of line blocking, making it less than ideal for multiplayer games.

# What about QUIC?

QUIC is an experimental protocol built on top of UDP that is designed as replacement transport layer for HTTP. It's currently supported in Google Chrome only.

A key feature provided by QUIC is support for multiple data streams. New data streams can be created implicitly by the client or server by increasing the channel id. Server channels ids are even, client channel ids are odd.

This channel concept provide two key benefits: 

1) It avoids a new connection handshake each time a new request is made. 

2) It eliminates head of line blocking between unrelated streams of data.

Unfortunately, while head of line blocking is eliminated across unrelated data streams, head of line blocking still exists within each stream.

# What about WebRTC?

WebRTC is a collection of protocols that enable peer-to-peer communication between browsers for applications like audio and video streaming. 

Almost as a footnote, WebRTC supports a data channel which can be configured in unreliable mode, providing a way to send unreliable-unordered data from the browser.

So why are games still stuck using WebSockets in 2017?

There are two key factors:

The first is that WebRTC is extremely complex. This of course makes sense, being designed primarily to support peer-to-peer communication between browsers, it is necessary for WebRTC to include STUN, ICE and TURN support for NAT traversal and packet forwarding in the worst case.

The second is that while WebRTC is designed primarily for peer-to-peer communication, there is a trend away from peer-to-peer and towards client/server for games. This can be seen in the move by modern first person shooter games moving away from player hosted servers to dedicated servers in the past 5 years for titles like Call of Duty and Titanfall, and in modern web games like [agar.io](http://agar.io) which is built and a client/server architecture. Given this trend, support for peer-to-peer is seen as unwanted baggage, since dedicated servers have public IPs by design.

So while WebRTC on paper provides a way to send unreliable-unordered data from the browser, in practice it falls down in complexity when data needs to be sent between a browser and a dedicated server in C++.

In the words of the author of [agar.io](http://agar.io), Matheus Valadares:

> I really hope it becomes easier to integrate, as right now that's the biggest barrier into putting it into my custom written C++ server that I use for all my games. They already support UDP-only communication for desktop and mobile builds and bringing it to web would make the experience a lot better.

Perhaps this can be solved in the future, but for the moment, the sheer complexity of WebRTC makes it a hard sell for game developers.

# Why not just let people send UDP?

(insert headline here)







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





