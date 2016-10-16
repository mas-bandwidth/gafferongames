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

So what's going on? Why do so many games build their own custom network protocol over UDP instead of using TCP? What is it about the specific use case of multiplayer gaming that makes a custom protocol built on top of UDP such a slam dunk?

## Justification for UDP

Multiplayer games are different to web servers[*](#quic_footnote).

Multiplayer games send **time critical, time series data**.

This is data that is both a function of time *and* must get across as quickly as possible. Data like (todo: examples...) Games in this regard are more like real-time video chat than streaming video. Here you cannot solve delivery problems by simply buffering a few seconds more, additional buffering adds latency and players demand the *lowest* possible latency, especially for competitive games.

So we have this time series data and due to player latency requirements the amount of time this data can be buffered is very short (<150ms). The client can only make use of time series data that arrives within this window. Data arriving later is useless and is thrown away. Naturally, it follows that the best method for sending network data is the one with the least time variance.

So why can't we use TCP for time critical, time series data?

The short answer is that delivering all packets reliably and in-order creates a large time variance in packet delivery under both packet loss and latency, this increases the amount of latency or hitches visible in the game. In time critical games like first person shooters, this additional latency or hitching caused by TCP significantly degrades the player experience in the game.

To explain exactly why this is, it is necessary to understand the nature of TCP. In order to create the illusion that a stream of data is reliable-ordered on top of an unreliable, best effort delivery network (IP), TCP holds more recent packets in a queue while waiting for dropped packets to be resent. Otherwise, packets would not arrive in the same order they were sent. This is known as **head of line blocking**.

This makes perfect sense for the streams of reliable-ordered data that TCP was designed for, but creates serious problems for time critical, time-series data. We don't care about all packets being delivered reliably and in order. All we care about is the most recent state hitting that small (<150ms) window before it becomes useless.

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

If the packet containing state for time t = 10.0 is lost, under TCP we must wait for that packet to be resent before we can access packets t = 10.1 and 10.2, even after they've already arrived over the network.

Worse still, by the time the resent packet arrives, it's far too late to actually do anything with it, since the client now intends to display something around t = 10.3 or 10.4. TCP blocked data we can use, waiting on data we can't. What a waste!

What we'd really like is for an option to tell TCP: "hey, we really don't care about old packets being resent, just let me skip over them and access more recent data instead". But TCP does not give us this option. All data must be delivered reliably and in-order. It's simply not possible to skip over dropped data with TCP.

This creates terrible problems for time critical data where packet loss *and* latency exist. Large hitches are added to the stream of packets as TCP waits for dropped packets to be resent, which for time critical, time-series data means that the client sees either a) additional buffering added to smooth out this jitter (unacceptable for fast paced action games), or b) long pauses where the game freezes and is non-responsive.

Clearly neither option is acceptable for a first person shooter. This is the reason why virtually all first person shooters are networked over UDP. UDP does not provide any reliability or ordering, so first person shooters are free to access the most recent data they want.

If, like first person shooters, we need the best performance when sending time critical data over the internet, we can obtain this by building our own custom protocol over UDP.

But using UDP comes at a cost: 

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. And that, my friend, is the subject of this article :)

# The Goal

What we wish to create is an abstraction on top of UDP where a server provides n slots for clients to connect to:

*(todo: diagram showing slots. keep it generic with ... n-1 at the bottom)*

It is common for n to be in the range [2,64]. This covers most cooperative and competitive client/server action games, with the higher player counts being for competitive first person shooters. Going above 64 starts to move into MMO territory, where the best practice may be different than what is presented here.

*(todo: diagram showing 4 client slots, with 3 connected clients)*

Each time a client requests a connection, it is assigned one of these slots. 

*(todo: diagram showing connection request on the 3rd slot, assign to 3rd slot, granted... you are slot #3)*

If no slot is available, the connection request is denied. 

*(todo: diagram showing all 4 slots taken up, connection request, denied)*

The slot number which a client is assigned is quite important. Once a client is connected, packets from its IP:port combination are routed to the correct receive queue for that client index. When packets are sent 

Packets arriving on the server are directed to the correct per-client queue according to which IP:port combination is assigned to each slot.

*(todo: diagram showing connection request)*

queue they should be assigned to, and when sending packets the destination is specified typically as "send a packet to client 2", rather than the IP address and port.

directly in the game, usually by assigning player 1, player 2 and so on, as the client index plus one.

Such an abstraction looks something like this:

(todo: diagram showing server with a number of slots, with clients connecting and filling slots)

...

<a name="quic_footnote"></a> _\* These days even web servers are transitioning to UDP via [Google's QUIC](https://ma.ttias.be/googles-quic-protocol-moving-web-tcp-udp/). If you still think TCP is good enough for time critical data in 2016, I encourage you to put that in your pipe and smoke it._