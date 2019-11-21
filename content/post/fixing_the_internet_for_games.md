---
title: "Fixing the Internet for Games"
summary: "What we're doing at my new startup [Network Next](https://networknext.com) :rocket:"
categories: ["Game Networking"]
tags: ["networking"]
date: "2019-03-24"
featured: true
draft: false
image:
  focal_point: "Center"
  preview_only: true
---

Hi, I'm [Glenn Fiedler](https://gafferongames.com) and this is my GDC 2019 talk called “Fixing the Internet for Games”.

<img src="/img/fixing-the-internet/001.png" width="100%" class="image_border"/>

It's about what we are doing at my new startup [Network Next](https://networknext.com).

<img src="/img/fixing-the-internet/002.png" width="100%" class="image_border"/>

When you launch a multiplayer game, some percentage of your player base will complain they are getting a bad experience.

You only need to check your forums to see this is true.

And as a player you’ve probably experienced it too.

What’s going on?

<img src="/img/fixing-the-internet/003.png" width="100%" class="image_border"/>

Is it your netcode, or maybe your matchmaker or hosting provider?

Can you fix it by running more servers in additional locations, or by switching to another hosting company?

Or maybe you’ve done all this already and now you have too many data centers, causing fragmentation in your player base?

<img src="/img/fixing-the-internet/004.png" width="100%" class="image_border"/>

It turns out that you can do all these things perfectly yet some % of your player base will still complain.

The real problem is that you don’t control the route from your player to your game server, and sometimes this route is bad.

<img src="/img/fixing-the-internet/005.png" width="100%" class="image_border"/>

This happens because the internet is not optimized for what we want (lowest latency, jitter and packet loss)

No amount of good netcode that you write can compensate for this.

The problem is the internet itself.

The internet doesn’t care about your game.

<img src="/img/fixing-the-internet/006.png" width="100%" class="image_border"/>

The internet thinks game traffic is the same as checking emails, visiting a website or watching netflix.

But game traffic is real-time and latency sensitive. It’s not the same.

It’s interactive so it can’t be cached at the edge and buffered like streamed video.

Networks that participate in the internet do hot potato routing, they just try to get your packets off their network as fast as possible so they don’t have to deal with it anymore. Nobody is coordinating centrally to ensure that packets are delivered with the lowest overall latency, jitter and packet loss.

Sometimes ISPs or transit providers make mistakes and packets are sent on ridiculous routes that can go to the other side of the country and back on their way to a game server just 5 miles away from the player… you can call up the ISP and ask them to fix this, but it can take days to resolve.

Even from day to day, performance is not consistent. You can get a good route one day, and a terrible one the next.

For all of these problems, players tend to blame you, the developer. But it’s not actually your fault.

<img src="/img/fixing-the-internet/007.png" width="100%" class="image_border"/>

What can you, the game developer, do about this?

<img src="/img/fixing-the-internet/008.png" width="100%" class="image_border"/>

One common approach is to try running as many servers in as many locations as possible, with as many different providers as you can.

This seems like a good idea at first, but there is no one data center or hosting company that is perfectly peered with every player of your game, so ultimately, it does not solve the problem.

Flaws:

1. Player fragmentation
2. Logistics of so many suppliers
3. Really difficult to find one data center suitable for party or team that wants to play together

<img src="/img/fixing-the-internet/009.png" width="100%" class="image_border"/>

Another option is to host in public clouds. Google’s private network is pretty good, right?

Game developers tend to assume that AWS, Azure and Google peering is perfect. But this is not true.

Flaws:

1. Egress bandwidth is expensive
2. Locked into one provider
3. Transit is not as good as you think

<img src="/img/fixing-the-internet/010.png" width="100%" class="image_border"/>

You could also build your own internet for your game.

This is not a joke. It actually happened!

Riot built their own private internet for League of Legends. When you play league of legends, your game traffic goes directly from your ISP onto this private network.

Case study: Riot Direct

* [Fixing the internet for real-time applications (part 1)](https://technology.riotgames.com/news/fixing-internet-real-time-applications-part-i)
* [Fixing the internet for real-time applications (part 2)](https://technology.riotgames.com/news/fixing-internet-real-time-applications-part-ii)
* [Fixing the internet for real-time applications (part 3)](https://technology.riotgames.com/news/fixing-internet-real-time-applications-part-iii)

Flaws:

1. Can you really afford this?
2. How many internets do we really need?! :)

<img src="/img/fixing-the-internet/011.png" width="100%" class="image_border"/>

Right now, if you are a game developer shipping a multiplayer game, you are competing against companies that have built their own private internet for their game.

<img src="/img/fixing-the-internet/012.png" width="100%" class="image_border"/>

What’s the solution? Build your own too?

Does it really make sense to build an internet for each game? This is crazy...

There has to be a way to do this without building your own infrastructure.

<img src="/img/fixing-the-internet/013.png" width="100%" class="image_border"/>

Network Next was created to solve this problem.

<img src="/img/fixing-the-internet/014.png" width="100%" class="image_border"/>

Network Next steers your game’s traffic across private networks that have already been built, so you don’t have to build your own private internet for your game.

<img src="/img/fixing-the-internet/015.png" width="100%" class="image_border"/>

But hold on. Aren't all the problems at the edge?

People seem to think that all the bad stuff on the internet occurs at the edge of the network, eg. shitty DSL connections, oversubscribed cable networks…

But this is not true.

<img src="/img/fixing-the-internet/016.png" width="100%" class="image_border"/>

The backbone itself is not as good as you think it is.

<img src="/img/fixing-the-internet/017.png" width="100%" class="image_border"/>

And I’m going to prove it.

<img src="/img/fixing-the-internet/018.png" width="100%" class="image_border"/>

Just two regular computers sitting in different data centers... let’s send UDP ping and pong packets between them, so we can measure the quality of the network.

<img src="/img/fixing-the-internet/019.png" width="100%" class="image_border"/>

We need some way to measure this quality as a scalar value.

Define cost as the sum of round trip time (rtt) in milliseconds, jitter (3rd standard deviation), and packet loss %.

Lower cost is good. Higher cost is bad.

<img src="/img/fixing-the-internet/020.png" width="100%" class="image_border"/>

Now let’s generalize to 4 nodes.

We measure cost between all nodes via pings, O(n^2).

<img src="/img/fixing-the-internet/021.png" width="100%" class="image_border"/>

Now let’s go up to 10 nodes.

<img src="/img/fixing-the-internet/022.png" width="100%" class="image_border"/>

Store the cost between all nodes in a triangular matrix. 

Each entry in the matrix is the cost between the node with index corresponding to the column, and node with index corresponding to the row.

The diagonal is -1, because nodes don’t ping themselves.

<img src="/img/fixing-the-internet/023.png" width="100%" class="image_border"/>

Now spin up instances in all the providers you can think of and all locations they support in North America.

For example: Google, AWS, Azure, Bluemix, vultr.com, multiplay, i3d, gameservers.com, servers.com and so on.

<img src="/img/fixing-the-internet/024.png" width="100%" class="image_border"/>

If the internet backbone was perfectly efficient, A-B would be the lowest cost 100% of the time. 

Instead, for the worst provider it is only 5-10% of the time.

And the best performing provider only 30% of the time...

Of course, we are not outperforming each provider on their own internal network, those are efficient.

Instead we reveal that each node on the internet is not perfectly peered with every other node. There is some slack, and going through an intermediary node in the majority cases can fix this.

<img src="/img/fixing-the-internet/025.png" width="100%" class="image_border"/>

Machines on the backbone are not talking to each other as efficiently as they can.

Talking through an intermediary is often better, in terms of our cost function.

Why? Many reasons... but overall, the public internet is optimized for throughput at lowest cost, not lowest latency and jitter.

<img src="/img/fixing-the-internet/026.png" width="100%" class="image_border"/>

What other option is there, aside from the public internet?

<img src="/img/fixing-the-internet/027.png" width="100%" class="image_border"/>

Many private networks have been built.

These include CDNs and any corporate entity that has realized the public internet is broken, and have built their own private networks (backhaul) and interconnections to compensate.

(Not many people know this, but this “shadow” private internet is actually growing at a faster rate than the public internet...)

<img src="/img/fixing-the-internet/028.png" width="100%" class="image_border"/>

This private internet is currently closed. Your game packets do not traverse it.

How can we open it up?

<img src="/img/fixing-the-internet/029.png" width="100%" class="image_border"/>

With a marketplace. Network Next is a marketplace where private networks resell excess capacity to applications that want better transit than the public internet.

<img src="/img/fixing-the-internet/030.png" width="100%" class="image_border"/>

Every 10 seconds, per-player we run a "route shader" as a bid on our marketplace, and find the best route across multiple suppliers that satisfies this request.

Suppliers cannot identify buyers, and can only compete on performance and price.

Thus, Network Next discovers the market price for premium transit, while remaining neutral.

<img src="/img/fixing-the-internet/031.png" width="100%" class="image_border"/>

Now let’s see how it works in practice, with real players.

<img src="/img/fixing-the-internet/032.png" width="100%" class="image_border"/>

Here is a small sample of connections active at a specific time one night last week...

Each dot is a player. Green dots are taking Network Next, blue dots are taking the public internet, because Network Next does not provide any improvement for them (yet).

Around 60% of player sessions are improved, fluctuating between 50% and 60% depending on the time of day. We believe that as we ramp up more suppliers, we can get the percentage of players improved up to 90%.

<img src="/img/fixing-the-internet/033.png" width="100%" class="image_border"/>

Of the 60% that are currently improved, the improvement breaks down into the following buckets:

49% of sessions had 0-5 cost unit improvement (cost being latency+jitter+packet loss).
25% had 5-10cu improvement.
12% had 10-15cu improvement.
6% had 15-20cu improvement.
7% had greater than 20cu improvement...

<img src="/img/fixing-the-internet/034.png" width="100%" class="image_border"/>

Here is a look at live sessions at a random time that night. Look at the rightmost column. Some players are getting an incredible improvement... there are always some players getting improvements like this at all times of the day...

(My apologies for the black censoring, it is necessary for GDPR compliance).

<img src="/img/fixing-the-internet/035.png" width="100%" class="image_border"/>

Drilling into the session getting the most improvement, we can see that they are not in the middle of nowhere, they are in Monterey, California...

<img src="/img/fixing-the-internet/036.png" width="100%" class="image_border"/>

Here we can see that the improvement is in both latency and jitter. Notice how flat the blue latency line is (Network Next), vs. the red line (public internet) that is going all over the place. 

Network Next not only has lower latency, it is also more consistent.

<img src="/img/fixing-the-internet/037.png" width="100%" class="image_border"/>

Here is a look at different data centers where our customers run game servers.

On the right is the % of players taking Network Next (getting improvement) to servers in that data center (green), and those not getting improvement and going direct over the public internet (blue).

On the left is the distribution of cost unit improvements for players that are getting improvement on Network Next to servers in that data center. The improvement depends on the peering arrangements of that data center, and on internet weather. It fluctuates somewhat from day to day.

We are able to fix this fluctuation due to internet weather and get the best result at all times.

<img src="/img/fixing-the-internet/040.png" width="100%" class="image_border"/>

If you'd like to learn more, please visit us at [networknext.com](https://networknext.com)

----- 

**Glenn Fiedler** is the founder and CEO of **[Network Next](https://networknext.com)**.<br><i>Network Next is fixing the internet for games by creating a marketplace for premium network transit.</i>
