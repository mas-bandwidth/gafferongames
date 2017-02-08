+++
categories = ["White papers"]
tags = ["networking"]
date = "2017-02-05"
title = "Why can't I send UDP packets from a browser?"
description = "A solution for enabling UDP in the web"
draft = false
+++

# Premise

In 2017 the most popular web games like [agar.io](http://agar.io) are effectively limited to networking via WebSockets over TCP. If a UDP equivalent of  WebSockets could be standardized and incorporated into browsers, it would greatly improve the networking of these games.

# Background

Web browsers are built on top of HTTP, which is a stateless request/response protocol initially designed for serving static web pages. HTTP is built on top of TCP, a low-level protocol which guarantees data sent over the internet arrives reliably, and in the same order it was sent. 

This has worked well for many years, but recently websites have become more interactive and poorly suited to the HTTP request/response paradigm. Rising to this challenge are modern web protocols like WebSockets, WebRTC, HTTP 2.0 and QUIC, which hold the potential to greatly improve the interactivity of the web. 

Unfortunately, this new set of standards for web development don't provide what multiplayer games need, or, provide it in a form that is too complicated for game developers to use.

This leads to frustration from game developers, who just want to be able to send UDP packets from the browser.

# The Problem

The web is built on top of TCP, which is a reliable-ordered protocol.

To deliver data reliably and in order under packet loss, it is necessary for TCP to hold more recent data in a queue while waiting for dropped packets to be resent. Otherwise, data would be delivered out of order.

This is called **head of line blocking** and it causes problems for multiplayer games, because games are networked not by request/response or by exchanging events, but by rapidly sending time series data like player input and the state of objects in the world.

This creates a frustrating and almost comedically tragic problem for game developers. The most recent data they want is delayed while waiting for old data to be resent, but by the time the resent data arrives, it's too old to be used!

Unfortunately, there is no way to fix this behavior under TCP. All data must be received reliably and in order. Therefore, the standard solution in the game industry for the past 20 years has been to send game data over UDP instead. 

How this works in practice is that each game develops their own custom protocol on top of UDP, implementing basic reliability as required, while sending the majority of data as unreliable-unordered. This ensures that time series data arrives as quickly as possible without waiting for dropped packets to be resent.

So, what does this have to do with web games?

The main problem for web games today is that game developers have no way to follow this industry best practice in the browser. Instead, web games are forced to send their game data over TCP, causing hitches and non-responsiveness due to head of line blocking.

This is completely unnecessary and could be fixed overnight if web games had some way to send and receive UDP packets.

# What about WebSockets?

WebSockets are an extension to the HTTP protocol which upgrade a HTTP connection so that data can be exchanged bidirectionally, rather than in the traditional request/response pattern.

This elegantly solves the problem of websites that need to display dynamically changing content, because once a web socket connection is established, the server can push data to the browser without a corresponding request.

Unfortunately, since WebSockets are implemented on top of TCP, data is still subject to head of line blocking.

# What about QUIC?

QUIC is an experimental protocol built on top of UDP that is designed as replacement transport layer for HTTP. It's currently supported in Google Chrome only.

A key feature of QUIC is support for multiple data streams. New data streams can be created implicitly by the client or server by increasing the channel id.

The channel concept provide two key benefits: 

1. Avoids a connection handshake each time a new request is made. 

2. Eliminates head of line blocking between unrelated streams of data.

Unfortunately, while head of line blocking is eliminated across unrelated data streams, it still exists _within_ each stream.

# What about WebRTC?

WebRTC is a collection of protocols that enable peer-to-peer communication between browsers for applications like audio and video streaming. 

Almost as a footnote, WebRTC supports a data channel which can be configured in unreliable mode, providing a way to send and receive unreliable-unordered data from the browser.

So why are games still stuck using WebSockets in 2017? 

The first reason is that WebRTC is extremely complex. This understandable, being designed primarily to support peer-to-peer communication between browsers, it is necessary for WebRTC to include STUN, ICE and TURN support for NAT traversal and packet forwarding in the worst case.

The second reason is that there is a trend away from peer-to-peer towards client/server for multiplayer games and, in short, while WebRTC make it easy to send unreliable-unordered data from one browser to another, it falls down when data needs to be sent between a browser and a dedicated server.

# Why not just let people send UDP?

The final option to consider is to just let users send and receive UDP packets directly from the browser. Of course, this is an _absolutely terrible idea_ and there are good reasons why it should never be allowed.

1. Websites would be able to launch DDoS attacks by coordinating UDP packet floods from browsers.

2. New security holes would be created as JavaScript running in web pages could craft malicious UDP packets to probe the internals of corporate networks and report back over HTTPS.

3. UDP packets are not encrypted, so any data sent over these packets could be sniffed and read by an attacker, or even modified in transmit. It would be a massive step back for web security to create a new way for browsers to send unencrypted packets.

4. There is no authentication, so a dedicated server reading packets sent from a browser would have to implement its own method to ensure that only valid clients are allowed to connect to it, which is well outside the amount of effort most game developers would be willing to apply to this problem.

So clearly, just letting JavaScript create UDP sockets in the browser is a no go.

# What could a solution look like?

But what if we approach it from the other side. What if, instead of trying to bridge from the web world to games, if we started with what games need and worked back to something that could work well in the web?

I'm [Glenn Fiedler](https://www.linkedin.com/in/glennfiedler) and I've been a game developer for the last 15 years. For most of this time I've specialized as a network programmer. I've got a lot of experience working on fast-paced action games. The last game I worked on was [Titanfall 2](https://www.titanfall.com/)

About a month ago, I read this thread on Hacker News: 

[WebRTC: the future of web games](https://news.ycombinator.com/item?id=13264952)

Where the creator of [agar.io](http://agar.io), Matheus Valadares, explained that WebRTC was too complex for him to use, and that he's still using WebSockets for his games.

I got to thinking, surely a solution must exist that's simpler than WebRTC? 

I wondered what exactly this solution would look like?

My conclusion was that any solution must have these properties:

1. **Connection based** so it could not be used in DDoS attacks or to probe security holes.

2. **Encrypted** because no game or web application would want to send unencrypted packets in 2017.

3. **Authenticated** because dedicated servers only want to accept connections from clients who are authenticated on the web backend.

I would now like to present the solution. I'm not holding my breath that this would be accepted as a standard in browsers as-is, I'm a game guy, not a web guy. But I do hope at least it will help browser creators and web developers see what client/server games actually need, and in some small way, do its part to help bridge the gap.

Hopefully the result will be multiplayer games playing better in a browser in the near future.

# netcode.io

The solution I came up with is [netcode.io](http://netcode.io)

netcode.io is a simple network protocol that lets clients securely connect to dedicated servers and communicate over UDP. It's connection oriented and encrypts and signs packets, and provides authentication support so only authenticated clients can connect to dedicated servers.

It's designed for games like [agar.io](http://agar.io) that need to shunt players off from the main website to a number of dedicated server instances, each with some maximum number of players (up to 256 players per-instance in the reference implementation). 

The basic idea is that the web backend performs authentication and when a client wants to play, some REST call provides a connect token to the client over HTTPS, which is passed to the dedicated server as part of the connection handshake over UDP. 

Connect tokens are short lived and rely on a shared private key between the web backend and the dedicated server instances. The benefit of this approach is that only authenticated clients are able to connect to the dedicated servers.

Where netcode.io wins out over WebRTC is simplicity. By focusing only on the dedicated server case, it removes the need for ICE, STUN and TURN. By implementing its encryption, signing and authentication with [libsodium](http://libsodium.org) it avoids the complexity of a full implementation of DTLS, while still providing the same level of security.

Over the past month I've created a [reference implementation](http://netcode.io) of netcode.io in C. It's licenced under the BSD 3-Clause open source licence. Over the next few months, I hope to continue refining this implementation, spend time writing a spec, and work with people to port netcode.io to different languages. 

Your feedback on the reference implementation is appreciated.

# How it works

A client authenticates with the web backend using standard authentication techniques (eg. OAuth). Once a client is authenticated they request to play a game by making a REST call. This REST call returns a _connect token_ to that client encoded as base64 over HTTPS.

A connect token has two parts:

1. A private portion, encrypted and signed by the shared private key using an AEAD primitive from libsodium. This cannot be read, modified or forged by the client.

2. A public portion, which provides information the client needs to connect, like encryption keys for UDP packets and the list of server addresses to connect to, along with some other information corresponding to the 'associated data' portion of the AEAD.

The client reads the connect token and in the public portion has a list of n IP addresses to connect to in order. While n can be 1, it's best to give the client multiple servers in case the first server is filled by the time the client attempts to connect to it.

When connecting to a dedicated server the client sends a _connection request packet_ repeatedly over UDP. This packet contains the private connect token data, plus some additional data for the AEAD such as the netcode.io version info, protocol id (a 64bit number unique to this particular game), expiry timestamp for the connnect token and the sequence number for the AEAD primitive.

When the dedicated server receives a connection request over UDP it first checks that the contents of the packet are valid with the AEAD primitive. If any of the public data in the connection request packet is modified, the signature check will fail. This stops clients from modifying the expiry timestamp for a connect token, while also making rejection of expired tokens very fast.

Provided the connect token is valid it is decrypted. Internally it it contains a list of dedicated server addresses that the connect token is valid to be used for. This stops malicious clients from going wide with one connect token to connect to every available dedicated server.

Next, 

When the server receives a connection request it first checks via the AEAD primitive whether the private connect token data is valid.

It checks the following:

2. 

1. Does the connect token decrypt properly with the AEAD primitive using the shared private key?


13. Recap the problem / real solution argument (50 words)

14. About the author section (70 words)

a) Bob Smith in ____ (current title) at _____ (name of company) where here _____ (does something)

b) Prior to that he ___ (did something)

c) Bob is also _____ (another current thing you're doing).

d) (Name of company) provides ____ (whatever your company does)

e) Phone and email contact.
