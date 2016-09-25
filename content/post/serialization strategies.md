+++
categories = ["Building a Game Network Protocol"]
tags = ["networking","game development"]
date = "2015-05-24"
title = "Serialization Strategies"
description = "Tips and tricks for serializing packet data in C++"
+++

## TCP vs. UDP Servers

When developing a TCP-based server you listen on a socket and accept incoming connections. The TCP networking stack does most of the work for you: negotiating initial connect with SYN, SYN/ACK, creating a new socket for each connected client, routing packets to and from each client to the correct socket, plus handling timeouts and disconnection.

In contrast, real-time action games like first person shooters use UDP instead of TCP because the bulk of their network traffic is time critical, time-series data. Resending this data when a packet is lost doesn’t make any sense because the state of the world at time t is no good if it arrives after time t. When networking these sort of games it is necessary to build your own concept of client connection on top of UDP.

This sounds like a lot of work, and it is! But this is the established best practice in the industry, and chances are that your favorite first person shooter is networked over a custom client/server protocol built on UDP. For example: Counterstrike, Halo, Overwatch, Call of Duty and Titanfall all create their own client/server connection on top of UDP.

## One UDP Socket To Rule Them All

The main difference between a TCP server and a UDP-based game server is that a UDP-based game servers sends and receives packets for all clients over the same socket, demultiplexing received packets based on their source address and port manually instead of creating one socket per-client like TCP servers do.

Another difference is that the number of connected clients per-server is smaller. In the web world C10K is old hat, but in 2016 it’s still common to see first person shooters with a maximum of just 16, 24, 32 or even 64 connected clients per-server instance. Of course, multiple game server instances can (and should) exist on each physical server, but each game server instance has it’s own UDP socket, to which only a small number of clients are allowed to connect to.

It follows that UDP-based game servers are not usually IO bound. This is true even though they send and receive packets more rapidly than a typical TCP-based web server: 60 packets per-second incoming and outgoing per-client with sustained bandwidth of 512 kbps per-client being typical for dedicated server games in 2016. Simple networking strategies based around non-blocking UDP sockets using sendto and recvfrom are often sufficient.
