+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-28"
title = "Client Server Connection"
description = "How to create a client/server connection over UDP"
draft = false
+++

## Introduction

Hi, I'm [Glenn Fiedler](/about) and welcome to **[Building a Game Network Protocol](/categories/building-a-game-network-protocol/)**.

In this article we're going to build a client/server connection on top of UDP.

I can guarantee you already at this point that some people have decided not to read this article because I'm obviously a fool. Who could possibly justify all the effort required to build a completely custom client/server network protocol over UDP when for so many people, TCP is simply good enough?

But why is it in 2016 that discussions of UDP vs. TCP are still so controversial, when virtually all first person shooters are networked with UDP?

* Counterstrike
* Call of Duty
* Titanfall
* Halo
* Battlefront
* Overwatch

Clearly this is a solved problem. **The game industry uses UDP.**

So what's going on? Why do so many games build their own custom network protocol over UDP instead of TCP? What is it about the specific use case of multiplayer games that makes a custom protocol on top of UDP such a slam dunk?

## Justification for using UDP instead of TCP

Multiplayer games are different to web servers[*](#quic_footnote).

Multiplayer games send **time critical, time series data**. 

This is data that is both a function of time *and* must get across as quickly as possible. Games are more like video and voice chat than streaming video. You cannot solve delivery problems by simply buffering a few seconds longer. Players demand the *minimum* possible latency, especially when playing competitive games.

So we have this time series data and due to latency requirements the amount of time this data can be buffered is short (<100ms). Any time series data that arrives after this small buffering window is useless and is thrown away. Naturally, the best method of delivery would be the one with the least time variance in packet delivery.

So why can't we use TCP for time critical, time series data?

The core problem with TCP is **head of line blocking**. 

TCP delivers all packets reliably and in-order. To implement this it is necessary to hold more recent packets in a queue while waiting for dropped packets to be resent. Otherwise, packets would not arrive in the same order they were sent. 

This makes perfect sense for the streams of reliable-ordered data that TCP was designed for, but it creates serious problems for time critical, time-series data. We don't care about old data being resent so packets are delivered reliably and in order. All we care about is the most recent state hitting that small (<100ms) window before it becomes useless.

To illustrate this, consider a game server sending 10 packets per-second to a client:

        t = 10.0
        t = 10.1
        t = 10.2
        t = 10.3
        t = 10.4
        t = 10.5
        t = 10.6
        t = 10.7
        t = 10.8
        t = 10.9

If the packet containing state for time t = 10.0 was lost, under TCP we must wait for that packet to be resent before we can access packets t = 10.1 and 10.2 even though they've already arrived. 

Worse still, by the time the resent packet arrives, it's far too late to actually do anything with it, since the client now intends to display something around t = 10.3 or 10.4. Time series data that arrives after the buffering window is useless. The client doesn't stop and wait!

What we'd really like is for an option to tell TCP: "hey, we really don't care about old packets being resent, just let me skip over them and let me access the more recent data instead". But TCP does not give us this option. All data must be delivered reliably and in-order. It's simply not possible to skip over dropped data with TCP.

This creates terrible problems for time critical data where packet loss *and* latency exist. Large hitches are added to the stream of packets as TCP waits for dropped packets to be resent, which for time critical, time-series data means that the client sees either a) additional buffering added to smooth out this jitter (unacceptable for fast paced action games), or b) long pauses where the action in the game freezes and is non-responsive.

Clearly neither option is acceptable for a first person shooter.

If we want the best performance when sending time critical data over the internet, it is necessary to build our own custom protocol over UDP. UDP doesn't provide any ordering or reliability, so we are free to drop old packets and access the most recent state that we want.

But using UDP comes at a cost.

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. And that, my friend, is the subject of this article.

# The Goal

What we wish to create is an abstraction on top of UDP where a server provides n slots for clients to connect to:

*(todo: diagram showing slots. keep it generic with ... n-1 at the bottom)*

It is common for n to be in the range [2,64]. This covers most cooperative and competitive client/server action games, with the higher player counts being for competitive first person shooters. Going higher than 64 starts to move into MMO territory, where the best practice may be different than what is presented here.

*(todo: diagram showing 4 client slots, with 3 connected clients)*

Each time a client requests a connection, it is assigned one of these slots. If no slot is available, the connection request is denied. 

*(todo: diagram showing connection request on the 3rd slot, assign to 3rd slot, granted... you are slot #3)

The slot number which a client is assigned is quite important. Once a client is connected, packets from its IP:port combination are routed to the correct receive queue for that client index. When packets are sent 

From that point of view, packets that arrive on the server are directed to the correct per-client queue according to which IP:port combination is assigned to each slot.

*(todo: diagram showing connection request)*

queue they should be assigned to, and when sending packets the destination is specified typically as "send a packet to client 2", rather than the IP address and port.

directly in the game, usually by assigning player 1, player 2 and so on, as the client index plus one.


Such an abstraction looks something like this:

(todo: diagram showing server with a number of slots, with clients connecting and filling slots)

...

<a name="quic_footnote"></a> _\* These days even web servers are transitioning to UDP via [Google's QUIC](https://ma.ttias.be/googles-quic-protocol-moving-web-tcp-udp/). If you still think TCP is good enough for time critical data in 2016, I encourage you to put that in your pipe and smoke it._