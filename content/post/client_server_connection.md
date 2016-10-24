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

But why is it in 2016 that discussions of UDP vs. TCP are so controversial, when virtually all first person shooters are networked with UDP?

* Counterstrike
* Call of Duty
* Titanfall
* Halo
* Battlefront
* Overwatch

Clearly this is a solved problem. **The game industry uses UDP.**

So what's going on? Why do so many games go through all the effort of building their own custom network protocol on top of UDP instead of just using TCP? What is it about the specific use case of multiplayer gaming that makes a custom protocol built on top of UDP such a slam dunk?

## Why First Person Shooters Use UDP

First person shooters are different to web servers[*](#quic_footnote).

First person shooters send **time critical data**. 

Time critical data is timestamped and must be received before that time to be useful. If time critical data arrives late, it is useless and is thrown away.

So, why can't we use TCP for time critical data?

The core problem with TCP is **head of line blocking**. 

TCP delivers all data reliably and in-order. To do this on top of IP which is unreliable and unordered, TCP holds more recent packets *(that we want)* hostage in a queue while older packets *(that we don't!)* are resent over the network.

To see why this is a problem for time critical data, consider a game server sending 10 packets per-second to a client, where the client advances forward in time and wants to display the most recent state of the world to the player. You know, like pretty much every FPS out there:

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

If the packet containing state for time t = 10.0 is lost, under TCP we must wait for that packet to be resent before we can access packets t = 10.1 and 10.2, even though they've already arrived over the network and this is the time the client wants to display to the player. Worse still, by the time the resent packet arrives it's far too late to do anything useful with it. The client has already advanced past that time and wants to display something around t = 10.3 or 10.4!

So why resend lost packets at all? **BINGO**. What we'd really like is an option to tell TCP: "hey, I don't care about old packets being resent, just let me skip over them and access more recent data". But TCP simply does not give us this option. All data must be delivered reliably and in-order. It's not possible to skip over dropped data with TCP.

This creates terrible problems for time critical data where packet loss *and* latency exist. Situations like, you know, The Internet, where people play FPS games. Large hitches are added to the stream of packets as TCP waits for dropped packets to be resent, which means additional buffering to smooth out these hitches, or long pauses where the game freezes and is non-responsive.

Neither option is acceptable for a first person shooter. This is why virtually all first person shooters are networked using UDP. UDP does not provide any reliability or ordering, so a game network protocol built on top of UDP can access the most recent data without head of line blocking.

But using UDP comes at a cost: 

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. Exactly how is the subject of this article :)

## The Goal

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