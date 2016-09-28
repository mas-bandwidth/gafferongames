+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-28"
title = "Client Server Connection"
description = "How to create a client/server connection over UDP"
draft = true
+++

## Introduction

Hi, I'm [Glenn Fiedler](https://www.linkedin.com/in/glennfiedler) and welcome to **Building a Game Network Protocol**.

In this article we're going to build a client/server connection on top of UDP.

I can guarantee you already at this point that some people have decided not to read this article because I'm obviously a fool. Who could possibly justify all the effort required to build a completely custom client/server network protocol over UDP when for so many people, TCP is simply good enough?

But why is it in 2016 that discussions of UDP vs. TCP are still so controversial, when virtually all first person shooters are networked with UDP? 

* Counterstrike
* Call of Duty
* Titanfall
* Halo
* Battlefront
* Overwatch

This is a solved problem. **The game industry uses UDP.**

So what's going on? Why do so many games build their own custom network protocol over UDP instead of TCP? What is it about the specific use case of multiplayer gaming that makes a custom protocol built on top of UDP such a slam dunk?

## Justification for using UDP instead of TCP

Action games are different to web servers[*](#quic_footnote). 

Action games send **time critical data**. 

Time critical data is timestamped and must be received before that time to be useful. If time critical data arrives late, it is useless and is thrown away.

So why can't we use TCP for time critical data?

The core problem with TCP is **head of line blocking**. 

This means that TCP delivers all packets reliably and in-order, so it holds more recent packets *(that we want)* hostage in a queue while older packets *(that we don't)* are resent over the network.

For example, if the server sends updates 10 times per-second, the following packets are sent to a client:

        t = 10.0
        t = 10.1
        t = 10.2
        t = 10.3
        t = 10.4

But if the packet containing state for time t = 10.0 is lost, under TCP we must wait for it to be resent before we can access packets t = 10.1 and 10.2, even though they've already arrived. By the time the resent packet arrives, we'd much rather have just skipped over t = 10.0 and be displaying something around 10.3 or 10.4, but TCP simply does not give us this option. All data must be delivered reliably and in-order. It's not possible to skip over dropped data with TCP.

This creates terrible problems for time critical data, leading to poor performance in situations where both packet loss and latency exist.

If we want the best performance when sending time critical data over the internet, it is necessary to build our own custom protocol over UDP. UDP doesn't provide any ordering or reliability, so we are free to drop old packets and access the most recent state that we want.

But using UDP comes at a cost.

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. And that, my friend, is the subject of this article.

<a name="quic_footnote"></a> _\* These days even web servers are transitioning to UDP via [Google's QUIC](https://ma.ttias.be/googles-quic-protocol-moving-web-tcp-udp/). If you still think TCP is good enough for time critical data in 2016, I encourage you to put that in your pipe and smoke it._
