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

But why is it in 2016 that discussions about UDP vs. TCP are still so controversial, when virtually all first person shooters are networked with UDP?

* Counterstrike
* Call of Duty
* Titanfall
* Halo
* Battlefront
* Overwatch

Clearly this is a solved problem. **The game industry uses UDP.**

So what's going on? Why do so many games go through all the effort of building their own custom network protocol on top of UDP instead of just using TCP? What is it about the specific use case of first person shooters that makes a protocol built on top of UDP such a slam dunk?

## Why First Person Shooters Use UDP

First person shooters are different to web servers[*](#quic_footnote).

First person shooters send **time critical data**. 

Time critical data is timestamped and must be received before that time in order to be useful. If time critical data arrives late, it is useless and is thrown away.

So... why can't we use TCP for time critical data?

The core problem with TCP is **head of line blocking**. 

TCP delivers all data reliably and in-order. To do this on top of IP, which is unreliable and unordered, TCP holds more recent packets *(that we want)* hostage in a queue while older packets *(that we don't!)* are resent over the network.

To see why this is such a huge problem for time critical data, consider a game server sending 10 packets per-second to a client, where the client advances forward in time and wants to display the most recent state of the world to the player. You know, like pretty much every FPS out there:

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

If the packet containing state for time t = 10.0 is lost, under TCP we must wait for that packet to be resent before we can access packets t = 10.1 and 10.2, even though they've already arrived over the network and are the most recent state the client wants to display to the player. Worse still, by the time the resent packet arrives it's far too late to do anything useful with it; the client has already advanced past 10.0 and wants to display something around 10.3 or 10.4!

So why resend lost packets at all? **BINGO**. What we'd really like is an option to tell TCP: "Hey, I don't care about old packets being resent, just let me skip over them and access the most recent data". But TCP does not give us this option. All data must be delivered reliably and in-order. It's simply not possible to skip over dropped data with TCP.

This creates terrible problems for time critical data where packet loss *and* latency exist. Situations like, you know, The Internet, where people play FPS games. Large hitches are added to the stream as TCP waits for dropped packets to be resent, which means additional buffering to smooth out these hitches, or long pauses where the game freezes and is non-responsive.

Neither option is acceptable for first person shooters, and this is why virtually all first person shooters are networked using UDP. UDP does not provide any reliability or ordering, so a protocol built on top of it can access the most recent data without head of line blocking.

But, using UDP comes at a cost: 

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. This is a lot of work! So strap in, get ready, because we're going to build it all up from scratch using same basic techniques first person shooters use when creating their custom protocols over UDP. I know, I've worked on them. You can use this protocol for either games or non-gaming applications and provided that the data you send is time critical, I promise you, it's well worth the effort.

## What We're Building

The goal is to create an abstraction on top of a UDP socket where our server presents a number of _virtual slots_ for clients to connect to:

<img src="/img/network-protocol/connection-request.png" width="100%"/>

When a client requests a connection, it gets assigned to one of these slots:

<img src="/img/network-protocol/connection-accepted.png" width="100%"/>

If a client requests connection, but no slots are available, the server is full and the connection request is denied:

<img src="/img/network-protocol/server-is-full.png" width="100%"/>

Once a client is connected, packets are exchanged in both directions. These packets form the basis for whatever custom protocol between the client and server which is game specific.

<img src="/img/network-protocol/client-packets.png" width="100%"/>

In a first person shooter, packets are sent continuously in both directions. The clients sents player input to the server rapidly (typically 60HZ), while receiving the most recent state of the world from the server at 10, 20 or even 60 times per-second.

Under such a situation there is no need for keep-alive packets. If at any point packets stop being received from the other side then the connection should time out. No packets for 5 seconds is a good timeout value in my opinion, but you can be more aggressive if you want. When a client slot times out on the server, it becomes available for another client to connect. When the client times out, it transitions to an error state.

## How Many Clients Per-Server?

How many client slots should we open? This depends entirely on the game. I recommend the approach in this article for games with [2,64] clients per-server. Any more than 64 and you start creeping in to MMO territory where the best practice may differ from what is presented here. You'll notice that most first person shooters in 2016 are in this range. For example, [Battlefield 1](https://en.wikipedia.org/wiki/Battlefield_1) has a maximum of 64 players.

One key thing to remember is that each server instance represents a shared instance of the world where players can directly interact with each other. For this reason it's good for clients to know which client slot they are assigned to, so they know if they are player 1, player 2 or player n. By convention, player numbers are considered to be client index + 1. 

So this client index lets players identify themselves and other players in the game, both when sending and receiving packets and in game code. For example, the server sends a packet to client 4, and receives a packet from client 10, while in a first person shooter you are killed by player 5 so the camera zooms in on that player and maybe shows a kill replay from their point of view. This is how we want everything to appear in our abstraction, not IP addresses, but client indices in [0,MaxClients-1].

Finally, why are client indices so important? The answer is security. The last thing we want in a competitive game is to expose player's IP addresses to each other, because some people try to DDoS people off the Internet. High profile streamers deal with this all the time. For these reasons, and many others, virtual client slots make a lot of sense.

## Implementation

_(todo: draft below here...)_

Let's get down to implementation.

First, the client and server both have their own UDP socket. Let's say the client binds to an ephemiral port, and the server binds to port 50000. 

Unlike a TCP-server where each accepted connection gets its own socket, the UDP server processes packets for all clients on the same socket. Also, since UDP is unreliabile, we need a strategy for packets being lost. We do this not by implementing a complicated reliability system at this early stage, but by implementing parallel state machines on the client and on the server:

At this early stage we have this state machine on the client:

* Disconnected
* Connecting
* Connected

And on the server, let's start with a bool "connected" for each slot, and the client address that is assigned to that slot:

    const int MaxClients = 64;

    class Server
    {
        int m_numConnectedClients;
        bool m_clientConnected[MaxClients];
        Address m_clientAddress[MaxClients];
    };

While the client is in the connection request state, it sends "connection request" packets to the server 10 times per-second. This continues until the client receives a response from the server, or the connection request times out. This simple approach works well and leaves the complexity of implementing reliability over UDP until _after_ a connection has been established.

For example “connection accepted” response packet could be lost. This is handled by making the server respond to each request (or at least, setting a dirty flag to trigger a response) each time a request is received. That way if the first “connect accepted” packet doesn’t get through, the next “connection request” from the client triggers another response. This way, by some sort of strange induction, the client and server are able to advance forward through an arbitrarily complicated state machine until they are both connected.

On the server there have a similar state machine, but this time it is per-client. For the moment, lets keep it simple with a basic data structure which simply keeps track of whether a client slot is assigned to a particular client IP+port:

Which lets the server lookup a free slot for a client to join (if any are free):

        int Server::FindFreeClientIndex() const
        {
            for ( int i = 0; i < m_maxClients; ++i )
            {
                if ( !m_clientConnected[i] )
                    return i;
            }
            return -1;
        }

Find the client index corresponding to an IP address and port:

        int Server::FindExistingClientIndex( const Address & address ) const
        {
            for ( int i = 0; i < m_maxClients; ++i )
            {
                if ( m_clientConnected[i] && m_clientAddress[i] == address )
                    return i;
            }
            return -1;
        }

Check if a client is connected to a given slot:

    const Address & Server::GetClientAddress( int clientIndex ) const
    {
        assert( clientIndex >= 0 );
        assert( clientIndex < m_maxClients );
        return m_clientAddress[clientIndex];
    }

and retrieve a client’s IP address and port by client index:

    const Address & Server::GetClientAddress( int clientIndex ) const
    {
        assert( clientIndex >= 0 );
        assert( clientIndex < m_maxClients );
        return m_clientAddress[clientIndex];
    }

For example "connection accepted" response packet could be lost. This is handled by making the server respond to each request (or at least, setting a dirty flag to trigger a response) each time a request is received. That way if the first "connect accepted" packet doesn't get through, the next "connection request" from the client triggers another response. This way, by some sort of strange induction, the client and server are able to advance forward through an arbitrarily complicated state machine until they are both connected.

On the server, we add the following data structure:






With these simple queries, the server is ready to start processing connection requests from clients.

<a name="quic_footnote"></a> _\* These days even web servers are transitioning to UDP via [Google's QUIC](https://ma.ttias.be/googles-quic-protocol-moving-web-tcp-udp/). If you still think TCP is good enough for time critical data in 2016, I encourage you to put that in your pipe and smoke it._