+++
categories = ["Building a Game Network Protocol"]
tags = ["networking","game development"]
date = "2015-05-24"
title = "Client Server Connection"
description = "How to create a client/server connection over UDP"
+++

## Introduction

Hi, I'm [Glenn Fiedler](https://www.linkedin.com/in/glennfiedler) and welcome to **Building a Game Network Protocol**. 

In this article series I’m building a professional-grade client/server network protocol for action games like first person shooters. The best practice in the game industry is to network these games with a custom protocol built on top of UDP. I’m going to show you why this is, what this protocol looks like, and how you can build one yourself!

## Justification for using UDP instead of TCP

Action games are different to web servers[*](#quic_footnote). Action games send **time critical data**. 

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

But if the packet containing state for time t = 10.0 is lost, under TCP we have to wait for it to be resent before we can access t = 10.1 and 10.2, even though they've already arrived. By the time the resent packet t = 10.0 arrives, we'd much rather have just skipped over t = 10.0 and be displaying something around 10.3 or 10.4, but TCP does not give us this option. All data must be delivered reliably and in-order. It's not possible to skip over dropped data with TCP.

This creates terrible problems for time critical data, leading to poor performance in situations where both packet loss and latency exist. 

If we want the best performance when sending time critical data over **The Internet**, it is necessary to build our own custom protocol over UDP. This is why virtually all action games and first person shooters are networked using UDP. UDP doesn't provide any ordering or reliability, so we are free to drop old packets and access the most recent state that we want.

But using UDP comes at a cost.

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. And that, my friend, is the subject of this article.

<a name="quic_footnote"></a> _\* These days even web servers are transitioning to UDP via [Google's QUIC](https://ma.ttias.be/googles-quic-protocol-moving-web-tcp-udp/). If you still think TCP is good enough for time critical data in 2016, I encourage you to put that in your pipe and smoke it._
