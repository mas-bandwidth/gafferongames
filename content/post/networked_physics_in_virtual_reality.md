+++
categories = ["Networked Physics"]
tags = ["physics", "networking", "vr"]
date = "2018-02-12"
title = "Networked Physics in Virtual Reality"
description = "Networking a stack of cubes with Unity and PhysX"
draft = true
+++

# Introduction

Way back in 2015, I presented a tutorial at GDC about how to network a physics simulation. It was fairly popular and was rated well, and if you [watch the video](https://www.gdcvault.com/play/1022195/Physics-for-Game-Programmers-Networking), I hope you'll be happy to hear that I've lost around 50 pounds since this video was recorded. I watch it today and think, _who the f*** is this person?_

So anyway, in this tutorial, a _much heavier me from the past_ covered three different techniques for networking a physics simulation:

1. Deterministic Lockstep
2. Snapshots and Interpolation
3. State Synchronization

After the talk, I published an [article series](https://gafferongames.com/post/introduction_to_networked_physics/) to go into more depth, covering topics like bandwidth optimization and delta-encoding. I even got into a friendly [network compression rivalry](https://gafferongames.com/post/snapshot_compression/) with some programmer friends, who in the end, totally kicked my ass. For example, see Fabian Giesen's [entry](https://github.com/rygorous/gaffer_net), which I think beat my best effort by around 25%, and I don't even think he worked that hard.

While my talk and articles were well received, afterwards I was slightly unsatisfied. Due to length available for my talk (just one hour), and how deep I went into detail in the article series, I was only able to focus on one small aspect of the problem: how to synchronize a simulation running on one machine, so that it could be _viewed_ it on another.

Crucially, what I felt was missing was a discussion of _latency hiding_. How to make it so that multiple players can interact with a physics simulation, while feeling that their interactions with the simulation were lag free. Of course many other things were also missing such as a discussion of network topology: client/server vs. peer-to-peer, dedicated vs. integrated servers. Also missing was discussion of _network models_. For example, client/server with client-side prediction, vs. distributed simulation (authority scheme), vs. GGPO style deterministic lockstep.

Since giving this talk, I've had many people ask me questions along these lines, and I've always wished I could write another article series or give another talk on the subject...

# A New Hope

And then one day after leaving my job at Respawn, Oculus approached me and offered to sponsor my research. They asked me, effectively: "Hey Glenn, there's a lot of interest in networked physics in VR. You did a cool talk at GDC. Do you think could come up with a networked physics sample in VR that we could share with devs? Maybe you could use the touch controllers?". 

I thought ~~"Fuck yes!"~~ **cough** "Sure. This could be a lot of fun!". But to keep it real, I insisted on two conditions. One: the source code I developed would be published under a permissive open source licence (for example, BSD) so it would create the most good, and two: when I was finished, I would be able to write an article describing the steps I took to develop the sample.

Oculus agreed. Welcome to that article! Also, you can find the full source for the networked physics sample [here](https://github.com/OculusVR/oculus-networked-physics-sample), wherein the code I wrote is released under a BSD licence. I hope the next generation of programmers can learn from my research into networked physics and create some really cool things. Good luck!

# What are we building?

When I first had discussions with Oculus, we imagined building something like a table where four players could sit around and interact with physically simulated cubes on a table. For example, throwing, catching and stacking cubes, maybe knocking over each other's stacks with a swipe of their hand. Maybe we could make a little toy or game out of it?

But after a few day spent learning Unity and C#, I found myself actually _inside_ the Rift. In VR, scale is _so important_. When the cubes were small, everything felt much less interesting, but when the cubes were scaled up to around a meter squared, everything had this really cool sense of scale. You could make _huge_ stacks of cubes, up to 20 or 30 meters high. This felt really cool!

It's impossible to communicate visually what this feels like outside of VR (so please [download](https://github.com/OculusVR/oculus-networked-physics-sample), build and run the sample in VR to see for yourself!), but it looks something like this...

<img src="/img/networked-physics-in-vr/stack-of-cubes.jpg" width="100%"/>

... where you can select, grab and throw cubes using the touch controller, and any cubes you release from your hand interact with the other cubes. You can throw a cube in your hand at a stack of cubes and knock them over. You can pick up two cubes and juggle them. You can build a stack of cubes and see how high you can make it go.

Now we had the vision. Moving forward, I suggested three criteria we would use to define success:

1. Players should be able to pick up and throw and catch cubes without latency.

2. Players should be able to stack cubes, and these stacks should be stable (eg. come to rest) and be without visible jitter.

3. When thrown cubes interact with the simulation, wherever possible (for example, collision with other cubes, and when cubes hit by the thrown cube in turn interact with the rest of the simulation) it should be without latency.

Now that you know what we are building, lets get started with how I built it.

First up, we have to pick a network model!

# Network Models

...

# Authority Scheme

...

# State Synchronization

Trusting I could implement the rules described above, my first task was to prove that synchronizing physics in one direction of flow could actually work with Unity and PhysX.

To do this, I setup a loopback scene in Unity where cubes fall into a pile in front of the player. There are two sets of cubes. The cubes on the left represent the authority side. The cubes on the right are the non-authority side, which we want to be in sync with the cubes on the left.

<img src="/img/networked-physics-in-vr/authority-and-non-authority-cubes.png" width="100%"/>

At the start, without anything in place to keep them in sync, even though both sets of cubes start from the same initial state, they give different end results. Here you can see the configuration of the stack on the right is quite different to the left, once all cubes have come to rest:

<img src="/img/networked-physics-in-vr/out-of-sync.png" width="100%"/>

This happens because PhysX is non-deterministic. To fight this non-determinism, we grab state from the authority side (left) and apply it to the non-authority side (right) 10 times per-second:

<img src="/img/networked-physics-in-vr/left-to-right.png" width="100%"/>

The state we grab from each cube looks like this:

    struct CubeState
    {
        Vector3 position;
        Quaternion rotation;
        Vector3 linear_velocity;
        Vector3 angular_velocity;
    };

We apply this state to the simulation on the right side, we simply _snap_ the position, rotation, linear and angular velocity of each object to the state we captured from the left side.

This simple change is enough to keep the left and right simulations in sync. Interestingly enough, PhysX doesn't diverge enough in the 1/10th of a second between updates to show any noticeable pops.

<img src="/img/networked-physics-in-vr/in-sync.png" width="100%"/>

This __proves__ that a state synchronization based approach for networking can work with PhysX. The only problem is that sending uncompressed physics state like this uses way too much bandwidth...

# Bandwidth Optimization

The easiest way to reduce bandwidth is to recognize when cubes are at rest. In this case, instead of repeatedly sending (0,0,0) for linear velocity, and (0,0,0) for and angular velocity as float values, we just send one bit: __at rest__.

Now when we transmit state over the network, it is encoded like this:

    [position] (vector3)
    [rotation] (quaternion)
    [at rest] (bool)
    <if not at rest>
    {
        [linear_velocity] (vector3)
        [angular_velocity] (vector3)
    }

This saves a lot of bandwidth because at any time _most_ cubes are at rest. It's also a _lossless_ technique because it doesn't change the state sent over the network in any way.

To optimize bandwidth further we need to use _lossy techniques_. 

This means we reduce the precision of the physics state when it's sent over the network. For example, we could bound position in some min/max range and quantize it to a precision of 1/1000th of a centimeter. We can use the same approach for linear and angular velocity, and for rotation we can use the _smallest three representation_ of a quaternion.

While this saves bandwidth, it also adds risk. My concern is that if we are networking a stack of objects (for example, 10 cubes placed on top of each other), maybe the quantization will create errors that add jitter to that stack? Maybe the stack would become _unstable_.

The best solution to this problem that I found was to quantize the state on _both sides_. What this means is that before each physics simulation step, the physics state is sampled and quantized _exactly the same way_ as when it's sent over the network, then applied back to the local simulation. 

I do this on both the authority and non-authority sides, and now the extrapolation from quantized state on the non-authority side matches the authority side as closely as possible, because the simulation and network packets are quantized exactly the same way.

# Coming To Rest

But quantizing the physics state like this has some _very interesting_ side-effects...

1. PhysX doesn't really like you forcing the state of each rigid body at the start of every frame and makes sure you know by taking up a bunch of CPU.

2. Quantization adds error to position which PhysX tries very hard to correct, snapping objects immediately out of penetration.

3. Rotations can't be represented exactly either, again causing penetration. Interestingly in this case, objects can get stuck in a feedback loop where they slowly slide across the floor.

4. Although objects in large stacks _seem_ to be at rest, close inspection in the editor reveals that they are actually jittering by tiny amounts, as objects are quantized just above a resting surface and fall towards it.

While we can't do much about PhysX CPU usage, the solution I found for the depenetration is to set _maxDepenetrationVelocity_ on each rigid body, limiting the velocity that objects are pushed apart with. I found that setting it to one meter per-second works very well.

To get objects to come to rest, I disabled the PhysX at rest calculation and replaced it with a ring-buffer of positions and rotations for each object. If an object has not moved or rotated significantly in the last 16 frames, I forced it to rest. Boom. Perfectly stable stacks with quantization.

This might seem like a hack, but short of actually getting in there with source code and rewritig the PhysX solver and at rest calculations, I didn't see any other option. I'm happy to be proven wrong though, so if you find a better way to do this, please let me know :)

# Priority Accumulator

The next big optimization is to add the ability to send only a subset of objects per-packet. This gives us fine control over the amount of bandwidth we send, by setting a maximum packet size and sending only the set of updates that fit in each packet.

Here's how it works in practice:

1. Each object has a _priority factor_ which is calculated each frame. Higher values are more likely to be sent. Negative values mean _"don't send this object"_.

2. If the priority factor is positive, it's added to the _priority accumulator_ value for that object. This value persists between simulation updates such that the priority accumulator increases each frame, so objects with higher priority rise faster than objects with low priority.

3. Negative priority factors clear the priority accumulator to -1.0.

4. When a packet is sent, objects are sorted in order of highest priority accumulator to lowest. The first n objects are and become the set of objects to potentially include in the packet. Objects with negative priority accumulator values are excluded.

5. The packet is written and objects are serialized to the packet in order of importance. Not all state updates may fit in the packet, since object updates have a variable encoding depending on their current state (at rest vs. not at rest). Therefore, packet serialization returns a flag per-object indicating whether it was included.

6. Priority accumulator values for objects sent in the packet are cleared to 0.0, giving other objects a fair chance to be included in the next packet.

For this demo I found some value in boosting priority for cubes recently involved in high energy collisions, since high energy collision was the largest source of divergence due to non-deterministic results. I also boosting priority for cubes recently thrown by players.

Somewhat counter-intuitively, reducing priority for at rest objects gave bad results. My theory is that since the simulation runs on both sides, at rest objects would get nudged slightly out of sync and not be corrected quickly enough, causing divergence when other cubes collide with them.

# Delta Compression

And now, the king of bandwidth optimization: _delta compression_.

First person shooters often implement this by compressing the entire state of the world relative to a previous state. In this technique, a previous world state or 'snapshot' acts as the _baseline_, and a set of differences, or _delta_, between the _baseline_ and _current_ snapshots is generated and sent down to the client.

This technique is relatively easy to implement because all the server needs to do is track the most recent snapshot received by each client, and generate deltas from that snapshot to the current. Similarly, all the client needs to do is keep a buffer of the last n snapshots received, so it can reconstruct snapshots by applying deltas on top of its copy of the baseline.

When a priority accumulator is used delta encoding becomes more complicated.

Now the server (or authority-side) can't simply encode objects relative to a previous snapshot number, because not all objects are included in each packet. Instead, the baseline must be specified _per-object_, so the receiver knows which state each object is encoded relative to.

The supporting systems and data structures are also much more complicated:

1. A reliability system is required that can report back to the sender which packets were received, not just the most recently received snapshot #.

2. The sender needs to track the states included in each packet sent, so it can map packet level acks to sent states and update the most recently acked state per-object.

3. The receiver needs to store a ring-buffer of received states per-object, so it can reconstruct the current object state from the delta.

But ultimately it's worth the extra complexity, because this system combines the flexibility of being able to dynamically adjust bandwidth usage, with the orders of magnitude bandwidth improvements you get from delta encoding.

# Delta Encoding

But how do we actually encode the delta between object states?

The simplest way is to encode objects that haven't changed from the baseline value as just one bit: _not changed_. This is also the easiest gain you'll ever see, because at any time most objects are at rest.

A more advanced strategy is to encode the _difference_ between the current and baseline values, aiming to encode small differences with fewer bits. For example, delta position could be (-1,+23,+4) from baseline. This works well for linear values, but breaks down somewhat for deltas of the smallest three quaternion representation, as the largest component of a quaternion is often different between the baseline and current rotation.

So while encoding the difference gives some gains, it's not an order of magnitude improvement like _not changed_. This is because in many cases objects move quickly, so the difference in their values becomes large enough to negate most gains. This is especially true in the case where objects are falling from the sky, which is arguably where bandwidth reductions are needed the most.

The most advanced strategy is to use prediction. In this approach, the current state is predicted from the baseline state assuming the object is moving ballistically under acceleration due to gravity. This is complicated somewhat by the fact that the predictor must be written in fixed point, because floating point calculations are not necessarily guaranteed to be deterministic, but it's definitely achievable.

In a few days of tweaking and experimentation, I was able to write a ballistic predictor for position, linear and angular velocity that matched the PhysX integrator within quantize resolution about 90% of the time. These lucky objects are encoded with another bit: _perfect prediction_. Another order of magnitude improvement. For cases where the prediction doesn't match exactly, a small error offset is sent.

In the time I had to spend, I not able to get a good predictor for rotation. I blame this on the smallest three representation, which is numerically unstable, especially in fixed point. In the future, I would not use the smallest three representation for quantized rotations.

It was also painfully obvious while encoding differences and error offsets that a bitpacker was not the best way to read and write these quantities. Something like a range coder or arithmetic compressor that can represent fractional bits, and dynamically adjust to the average size of differences in the scene would give much better results.

# Synchronizing Avatars

Now that bandwidth is under control, how can we synchronize avatars?

Avatars are represented by a head and two hands driven by the tracked headset and touch controllers. We capture the position and rotations of the avatar components in _FixedUpdate_ along the rest of the physics state, but avatar state is actually sampled from the hardware at render framerate in _Update_.

This causes jitter when the avatar state is applied on the other side, because the sample time doesn't line up with _FixedUpdate_ on that machine. To fix this, we store the difference between physics and render time when we sample avatar state, so we can reconstruct the time of the avatar sample on the other side. 

Next, a jitter buffer with 100ms delay is applied to received packets, solving network jitter from time variance in packet delivery and enabling interpolation between avatar states. Physics state is applied to the simulation in _FixedUpdate_, while avatar state is applied at render time in _Update_ by interpolating between the two nearest samples in the jitter buffer.

While a cube is parented to an avatar hand, its _priority factor_ is set to -1, stopping it from being sent with regular physics state updates. Instead, its cube id and relative position and rotation are sent as part of the avatar state. Cubes are attached to the avatar hands in the remote view when the first avatar state arrives with that cube parented to a hand, and detached when regular physics state updates resume, corresponding to the cube being thrown or released.

# Bidirectional Flow

Now lets add another player on the right:

_(diagram showing loopback scene with player on right)_

We'll call the this player the _guest_, and the original player the _host_.

The guest takes authority and ownership of objects without waiting for acknowledgement from the host, which allows the guest to interact with the simulation with no latency. 

Of course the host needs to see what the guest does, so the guest sends state for cubes it interacts with (has authority over) back to the host, plus the state for its avatar, which implicitly includes state for cubes held by the guest.

_(diagram showing flow from guest -> host)_

The host and guest both check the local state of cubes before taking authority and ownership. For example, the host won't take authority over an object already under authority of the guest and vice-versa, and players can't grab cubes already held by another player.

Despite this, it's possible for two players to predictively take authority or ownership over the same object under latency, when each player acquires the object before seeing the other player's action. Because of this, we need a way to resolve conflicts after the fact.

# Resolving Conflicts

Now consider the case of a host and three guests:

_(diagram showing host and three guests in client/server topology)_

As you can see, this is a client/server topology rather than peer-to-peer. In this topology, all packets flow through the host, making the host the _arbiter_. In other words, the host decides which state updates to accept, and which to ignore and subsequently correct.

To apply these corrections we need some way for the host to override guests and say, no, you don't have authority or ownership over this object, and you should accept this update. We also need some way for the host to determine _ordering_ for guest interactions with the world, so if one client experiences a burst of lag and delivers a bunch of packets late, these packets won't take precedence over more recent actions from other guests.

This is achieved with two sequence numbers:

1. Authority sequence

2. Ownership sequence

These sequence numbers are sent along with each state update and included in avatar state when cubes are held by players. They are used by the host to determine if it should accept an update from guests, and by guests to determine if the state update from the server is more recent and should be accepted, even when that guest thinks it has authority or ownership over an object.

Authority sequence increments each time a player takes authority over an object and when an object under authority of a player comes to rest. When an object has authority on a guest machine, it holds authority on that machine until it receives _confirmation_ from the host before returning to default authority. This ensures that the final at rest state for objects under guest authority are committed back to the host, even under significant packet loss.

Ownership sequence increments each time a player grabs an object. Ownership is stronger that authority, such that an increase in ownership sequence wins over an increase in authority sequence number. For example, if a player interacts with an object just before another player grabs it, the player who grabbed it wins.

These rules are sufficient to resolve conflicts, while letting host and guest players can interact with the world lag free. Corrections are rare in practice, and when they do occur, the simulation quickly converges to a consistent state.

# Conclusion

High quality networked physics with stable stacks of objects is possible with Unity and PhysX using an authority-based network model. This approach is best used for _cooperative experiences only_, as it does not provide the security of a server-authoritative network model.

----- 

<i>
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he worked at Respawn Entertainment on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](https://gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
