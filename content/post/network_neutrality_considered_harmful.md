---
title: "Network Neutrality Considered Harmful"
summary: "Why I created Network Next"
categories: ["Game Networking"]
tags: ["networking"]
date: "2020-08-24"
featured: true
draft: false
image:
  focal_point: "Center"
  preview_only: true
---

Hi, I'm [Glenn Fiedler](https://www.linkedin.com/in/glennfiedler/) and I'm the founder and CEO of [Network Next](https://networknext.com).

Before starting Network Next, I worked in the game industry for 20 years as a software engineer. I was fortunate enough to have a good career and got to work on some games you've might have played: **Freedom Force**, **Mercenaries 2**, **God of War**, **Journey** and **Titanfall 1 and 2**. Some of my netcode is still active in **Apex Legends** even though I left Respawn Entertainment before it started development.

Ever since [QTest](https://quake.fandom.com/wiki/Qtest) I've found the idea that people in different physical locations could inhabit the same virtual space utterly fascinating. I wanted to understand how that worked and be part of it. So, after a few false starts in graphics programming and physics, I specialized in UDP protocol design for latency sensitive games.

I'm writing this article to tell you something that you might find shocking. 

Network Neutrality, the thing that we hold so dear, the foundation of the internet as we know it, may in fact be harmful for latency sensitive applications like games.

Why? Please watch this video for an explanation (sound on):

{{< youtube jo1qffymv3E >}}

Now of course, saying **the internet doesn't care about your game** is a pretty strong accusation, so I'm going to back it up with some evidence.

First, anecdotal. Every multiplayer game I worked on, I spent years of my life working on the netcode, using every trick possible to hide packet loss and latency. Client side prediction to hide latency in player actions, lag compensation to avoid players needing to lead shots, bandwidth optimization to reduce the load on the network, redundancy to mitigate packet loss, custom UDP protocols to avoid head of line blocking...

And despite all this effort, a significant portion of players would play my game and get bad network performance and there was _literally nothing I could do about it_.

Just how bad does it get? Let's take a look at the data...

Here's a screenshot from Thursday August 20th, 2020:

![Screenshot of https://portal.networknext.com](/img/network-neutrality-considered-harmful/portal-001.png)

1000+ players with 100ms or greater added latency courtesy of best effort delivery, one player with a whooping 730ms extra. _Clearly, this is not a speed of light problem..._

Later the same day we saw a packet loss event:

![Graph showing AB test result for packet loss](/img/network-neutrality-considered-harmful/portal-002.png)

Now you may look at this and think, oh, it's just 0.8% packet loss at peak, it's not that bad... but this is an average across all players, and only some portion of players were affected. For these players, the effect was much more severe:

![Graph showing absolute point reduction in packet loss percent for players on network next](/img/network-neutrality-considered-harmful/portal-003.png)

During the mitigation the average packet loss reduction was an absolute reduction of 12 points of packet loss. No, not a reduction of 12%, **a reduction of 12 points**. In other words, a conversion from totally unplayable to playable.

This is not an isolated incident. These things literally happen all the time. Take a look for yourself, our portal is live and updated in real-time: https://portal.networknext.com

From this point on it should be clear: **the internet really doesn't care about your game.**

So... what's going on?

It's this. The internet makes no guarantee of performance, but instead offers best effort delivery. By the orthodoxy of Network Neutrality it is hand-wavingly assumed that overall, the quality level is maintained via over provisioning. But while this may be true for browsing the web and reading email, looking at the results above we can clearly see it isn't working for latency sensitive applications like games!

As a game developer what I want for my traffic is the lowest latency (within speed of light limits), with as little packet loss and jitter as possible. In other words, if I send 60 packets per-second, I want all of them to arrive as quickly as possible exactly 1/60th of a second apart. The internet as it exists today, is just not capable of this.

So now let's take direct aim at one of the core tenets of Network Neutrality. That all traffic is the same. Clearly this is false. Latency sensitive traffic like game traffic is not the same as checking your email or browsing the web. It's not even the same as watching YouTube or Netflix, which can be solved by simply buffering the stream. It's something completely different.

Now that we acknowledge that different classes of traffic exist, how can we reconcile this with a neutral network and avoid classically described dystopias where network providers throttle the performance of competing applications, and ISPs bill you for "acceleration plans" for your internet connection on a monthly basis.

This is why I created Network Next. 

Network Next is not just another network. We're not building network infrastructure. We're not lighting up dark fiber. We're not creating yet another shadow internet with private interconnects. We don't even have an ASN.

Instead, we're creating a **neutral marketplace** where networks compete to carry latency sensitive traffic. In this marketplace, networks cannot identify the application or even set a different price for different applications. They can only compete on performance and price.

The buyer on our marketplace is not the player, it's the application developer who uses Network Next to communicate the quality of service they want to the network. Network Next then runs a bid on our marketplace every 10 seconds per-player and the result of this bid is the route players take across our supplier networks.

This creates a truly neutral network of networks - a new internet - with different classes of transit. An ethical, and technologically enforced alternative to the Network Neutrality Orthodoxy that covers its ears and yells "All traffic is the same!" in 2020 even though clearly it is not.

I hope you agree with me, but if even if you don't, we've created this marketplace over the past three years and it's now live. Chances are pretty good over the next 3 months when you play a game, you're playing it over Network Next and I look forward to improving the quality of your connection.

Best wishes,

Glenn Fiedler, CEO, Network Next [networknext.com](https://networknext.com)
